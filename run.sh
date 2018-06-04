#! /bin/sh
#
# run.sh
# Copyright (C) 2017-10-07 23:53 renothing <frankdot@qq.com>
#
# Distributed under terms of the Apache license.
#
echo "${TIMEZONE}" > /etc/TZ 
cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime 
if [[ ! -d  "${DATADIR}/config" ]];then
  haraka -i ${DATADIR}
  openssl dhparam -out ${DATADIR}/config/dhparam.pem 2048
  echo "$DOMAIN" > ${DATADIR}/config/host_list
  echo "$DOMAIN" > ${DATADIR}/config/me
  echo 0 > ${DATADIR}/config/strict_rfc1869
  sed 's/^#toobusy/toobusy/g' -i ${DATADIR}/config/plugins
 #sed 's/^dnsbl/#dnsbl/g' -i ${DATADIR}/config/plugins
  sed 's/^queue\/smtp_forward/#queue\/smtp_forward/g' -i ${DATADIR}/config/plugins
  #enable tls,spf,dkim and auth_flat_file
  sed 's/^#spf/spf/g' -i ${DATADIR}/config/plugins
  sed 's/^#dkim_sign/dkim_sign/g' -i ${DATADIR}/config/plugins
  echo "tls" >> ${DATADIR}/config/plugins
  echo "auth/flat_file" >> ${DATADIR}/config/plugins
  echo "listen=[::0]:587" >> ${DATADIR}/config/smtp.ini
  echo "nodes=cpus" >> ${DATADIR}/config/smtp.ini
  #add tls.ini
  cat << EOF >> ${DATADIR}/config/tls.ini
key=${TLS_KEY}
cert=${TLS_CERT}
dhparam=${DATADIR}/config/dhparam.pem
secureProtocol=TLSv1_2_method
EOF
  #enable dkim sign
  cd ${DATADIR}/config/dkim/
  sh dkim_key_gen.sh $DOMAIN
  cd -
  selector=`cat ${DATADIR}/config/dkim/${DOMAIN}/selector`
  cat << EOF >> ${DATADIR}/config/dkim_sign.ini
disabled = false
selector = $selector
domain=$DOMAIN
dkim.private.key=${DATADIR}/config/${DOMAIN}/private
EOF
  #enable outbound
  cat << EOF >> ${DATADIR}/config/outbound.ini
enable_tls = true
relaying = true
ipv6_enabled = true
received_header = ${HEADER}
EOF
#enable spf
  cat << EOF >> ${DATADIR}/config/spf.ini
[relay]
context=myself  
EOF
  #add auth_flat_file
tmppass=`openssl rand -base64 12`
  cat << EOF >> ${DATADIR}/config/auth_flat_file.ini
[core]
methods=PLAIN,LOGIN,CRAM-MD5
[users]
tester@${DOMAIN}=$tmppass
EOF
fi
haraka -c ${DATADIR}
