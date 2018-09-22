#! /bin/sh
#
# run.sh
# Copyright (C) 2017-10-07 23:53 renothing <frankdot@qq.com>
#
# Distributed under terms of the Apache license.
#
echo "${TIMEZONE}" > /etc/TZ 
cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime 
stat -c "%U" ${DATADIR}|grep -q smtp || chown -R smtp:smtp ${DATADIR}
if [[ ! -d  "${DATADIR}/config" ]];then
  haraka -i ${DATADIR}
  openssl dhparam -out ${DATADIR}/config/dhparam.pem 2048
  echo "$DOMAIN" > ${DATADIR}/config/host_list
  echo "$DOMAIN" > ${DATADIR}/config/me
  echo 1 > ${DATADIR}/config/strict_rfc1869
  sed 's/^#toobusy/toobusy/g' -i ${DATADIR}/config/plugins
  echo "record_envelope_addresses" >> ${DATADIR}/config/plugins
  sed 's/^queue\/smtp_forward/#queue\/smtp_forward/g' -i ${DATADIR}/config/plugins
  echo "listen=[::0]:${PORT}" >> ${DATADIR}/config/smtp.ini
  echo "user=smtp" >> ${DATADIR}/config/smtp.ini
  echo "group=smtp" >> ${DATADIR}/config/smtp.ini
  echo "nodes=cpus" >> ${DATADIR}/config/smtp.ini
  echo "true" > ${DATADIR}/config/header_hide_version
  echo "$HEADER" > ${DATADIR}/config/ehlo_hello_message
  #enable tls,spf,dkim and auth_flat_file
  sed 's/^#spf/spf/g' -i ${DATADIR}/config/plugins
  sed 's/^#dkim_sign/dkim_sign/g' -i ${DATADIR}/config/plugins
  #add tls.ini
  if [ ! -z "$TLS_KEY" ];then
  echo "tls" >> ${DATADIR}/config/plugins
  cat << EOF >> ${DATADIR}/config/tls.ini
key=${TLS_KEY}
cert=${TLS_CERT}
dhparam=${DATADIR}/config/dhparam.pem
EOF
fi
  #enable dkim sign
  cd ${DATADIR}/config/dkim/
  sh dkim_key_gen.sh $DOMAIN
  cd -
  selector=`cat ${DATADIR}/config/dkim/${DOMAIN}/selector`
  cat << EOF >> ${DATADIR}/config/dkim_sign.ini
disabled = false
selector = $selector
domain=$DOMAIN
dkim.private.key=${DATADIR}/config/dkim/${DOMAIN}/private
EOF
  #enable outbound
  cat << EOF >> ${DATADIR}/config/outbound.ini
enable_tls = true
relaying = true
ipv6_enabled = true
received_header = ${HEADER}
received_header_disabled=true
EOF
#enable log
  cat << EOF >> ${DATADIR}/config/log.ini
loglevel=${LOGLEVEL}
timestamps=false
format=logfmt
EOF
#enable spf
  cat << EOF >> ${DATADIR}/config/spf.ini
[relay]
context=myself  
EOF
#enable data.header check
  cat << EOF >> ${DATADIR}/config/data.headers.ini
[check]
duplicate_singular=true
missing_required=true
invalid_return_path=true
invalid_date=true
user_agent=true
direct_to_mx=true
from_match=true
mailing_list=true
delivered_to=true
[reject]
missing_required=true
invalid_date=true
EOF

  #add auth_flat_file
  echo "auth/flat_file" >> ${DATADIR}/config/plugins
  tmppass=`openssl rand -base64 12`
  cat << EOF >> ${DATADIR}/config/auth_flat_file.ini
[core]
methods=PLAIN,LOGIN,CRAM-MD5
[users]
admin@${DOMAIN}=$tmppass
EOF
fi
exec haraka -c ${DATADIR}
