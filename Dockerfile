FROM node:10-alpine
LABEL author='renothing' role='smtp server' tags='haraka,smtp server' description='haraka based on alpine'
#set language enviroments
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    TIMEZONE="Asia/Shanghai" \
    PORT=587 \
    LOGLEVEL=warn \
    DATADIR=/data \
    DOMAIN="yourdomain.com" \
    HEADER="Haraka Server" \
    TLS_KEY="" \
    TLS_CERT="" \
    AUTOTLS=0 \
    EMAIL="youremail@email.com" \
    TLSDOMAIN="tlsdomain.com tls2domain.com"
#install software
COPY run.sh /
#RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g;s/http/https/g' /etc/apk/repositories && apk upgrade --update && \ 
# install dependence
RUN apk upgrade --update && \
    apk add --no-cache -t .fetch-deps \
    autoconf \
    g++ \
    gcc \
    make \
    python && \
    addgroup -g 88 -S smtp && \
    adduser -u 88 -D -S -G smtp -h /data smtp && \
#install haraka
    npm install -g --unsafe-perm Haraka toobusy-js && \
#  # Cleaning up
    apk del --purge -r .fetch-deps && \
    apk add --no-cache tzdata openssl execline ca-certificates && \
    rm -rf /var/cache/apk/* /tmp/* ~/.pearrc && chmod 755 /run.sh
#start scripts
COPY --from=xenolf/lego /usr/bin/lego /usr/bin/lego
# Set Workdir
# Expose volumes
#VOLUME ["/var/www"]
# Entry point
CMD ["/run.sh"]
