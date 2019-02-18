#! /bin/sh
#
# run.sh
# Copyright (C) 2017-10-07 23:53 renothing <frankdot@qq.com>
#
# Distributed under terms of the Apache license.
#
echo "${TIMEZONE}" > /etc/TZ 
cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime 
#init config when first running
if [[ ! -d  "${DATADIR}/config" ]];then
  haraka -i ${DATADIR}
  echo "$DOMAIN" > ${DATADIR}/config/host_list
  echo "$DOMAIN" > ${DATADIR}/config/me
  echo 1 > ${DATADIR}/config/strict_rfc1869
  sed -i 's/^#toobusy$\?/toobusy/g' ${DATADIR}/config/plugins
# echo "record_envelope_addresses" >> ${DATADIR}/config/plugins  #If you enable this plugin you may introduce a possible information leak, i.e. disclosure of BCC recipients
  sed -i 's/^queue\/smtp_forward/#queue\/smtp_forward/g' ${DATADIR}/config/plugins
  echo "listen=[::0]:${PORT}" >> ${DATADIR}/config/smtp.ini
  echo "user=smtp" >> ${DATADIR}/config/smtp.ini
  echo "group=smtp" >> ${DATADIR}/config/smtp.ini
  echo "nodes=cpus" >> ${DATADIR}/config/smtp.ini
  echo "true" > ${DATADIR}/config/header_hide_version
  echo "$HEADER" > ${DATADIR}/config/ehlo_hello_message
  #enable spf,dkim and auth_flat_file
  sed -i 's/^#spf$\?/spf/g' ${DATADIR}/config/plugins
  sed -i 's/^#dkim_sign$\?/dkim_sign/g' ${DATADIR}/config/plugins
  sed -i '/max_unrecognized_commands/d' ${DATADIR}/config/plugins
  #enable dkim sign
  cd ${DATADIR}/config/dkim/
  sh dkim_key_gen.sh $DOMAIN
  cd -
  selector=`cat ${DATADIR}/config/dkim/${DOMAIN}/selector`
  cat <<-EOF >> ${DATADIR}/config/dkim_sign.ini
	disabled = false
	selector = $selector
	domain=$DOMAIN
	dkim.private.key=${DATADIR}/config/dkim/${DOMAIN}/private
	EOF
  #enable outbound
  cat <<-EOF >> ${DATADIR}/config/outbound.ini
	relaying = true
	ipv6_enabled = true
	received_header = ${HEADER}
	received_header_disabled=true
	EOF
  #enable log
  cat <<-EOF >> ${DATADIR}/config/log.ini
	loglevel=${LOGLEVEL}
	timestamps=false
	format=logfmt
	EOF
  #enable spf
  cat <<-EOF >> ${DATADIR}/config/spf.ini
	[relay]
	context=sender
	context=myself
	EOF
#enable data.header check
  cat <<-EOF >> ${DATADIR}/config/data.headers.ini
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
  sed -i "s/^#\s*auth\/flat_file/auth\/flat_file/" >> ${DATADIR}/config/plugins
  tmppass=`openssl rand -base64 12`
  cat <<-EOF >> ${DATADIR}/config/auth_flat_file.ini
	[core]
	methods=PLAIN,LOGIN,CRAM-MD5
	[users]
	admin@${DOMAIN}=$tmppass
	EOF
  #enable limit
  sed -i '/^#limit$\?/d' ${DATADIR}/config/plugins
  echo "limit" >> ${DATADIR}/config/plugins
  cat <<-EOF >> ${DATADIR}/config/limit.ini
	[unrecognized_commands]
	enabled=true
	max=10
	EOF

fi
#request tls certificates from letsencrypt
if [ "${AUTOTLS}" -eq 1 ] && [ ! -z "$TLSDOMAIN" ];then
  args="-a -m ${EMAIL} -k rsa4096 --path ${DATADIR}/lego/ --tls --tls.port :${PORT} --dns.resolvers 8.8.8.8"
  for d in ${TLSDOMAIN};do
    args="$args -d ${d}"
  done
  pd=$(echo "$TLSDOMAIN"|awk '{print $1}')
  TLS_KEY=${DATADIR}/lego/certificates/${pd}.key
  TLS_CERT=${DATADIR}/lego/certificates/${pd}.crt
  #eable tls
  if [ -f $TLS_KEY ] && [ -f $TLS_CERT ];then
    lego $args run
    grep -q "^tls$\?" ${DATADIR}/config/plugins || sed -i "s/^#\s*tls/tls/" >> ${DATADIR}/config/plugins
    grep -q "^enable_tls" ${DATADIR}/config/outbound.ini || echo "enable_tls = true" > ${DATADIR}/config/outbound.ini
    test -f ${DATADIR}/config/dhparam.pem || openssl dhparam -out ${DATADIR}/config/dhparam.pem 2048
    test -f ${DATADIR}/config/tls.ini || cat <<-EOF > ${DATADIR}/config/tls.ini
	key=${TLS_KEY}
	cert=${TLS_CERT}
	dhparam=${DATADIR}/config/dhparam.pem
	EOF
  fi
  #generate letscrypt renew job
  jobcmd="lego "$args" renew --days 10 --reuse-key"
  echo "2 */2 * * * $jobcmd >> /dev/null"|crontab -
  crond -b -L ${DATADIR}/cron.log
fi
#start haraka
stat -c "%U" ${DATADIR}|grep -q smtp || chown -R smtp:smtp ${DATADIR}
exec haraka -c ${DATADIR}
