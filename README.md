# About this Repo
----

This repository contains **Dockerfile** of [Haraka](http://haraka.github.io) for [Docker](https://www.docker.com/)'s automated build.


### Base Docker Image

* [dockerfile/alpine](http://dockerfile.github.io/#/alpine)


### Installation

1. Install [Docker](https://www.docker.com/).

2. Download [automated build](https://hub.docker.com/r/renothing/haraka/) from public [Docker Hub Registry](https://registry.hub.docker.com/): `docker pull renothing/haraka:tag`

   (alternatively, you can build an image from Dockerfile: `docker build -t="haraka:latest" github.com/renothing/docker-haraka.git`)

3. default environments supported,you can change them before building or running.   
   the container start with port 587 with ssl enabled
```
    TIMEZONE="Asia/Shanghai"
    DATADIR=/data 
    PORT="port to listen on "
    DOMAIN="yourdomain.com" #your mx record domain here
    HEADER="Haraka Server" 
    TLS_KEY="your domain ssl key file" 
    TLS_CERT="your domain ssl cert file"
    AUTOTLS=0
    EMAIL="youremail@email.com"
    TLSDOMAIN="tlsdomain.com tls2domain.com" #your connection hostdomain,split by black, support wildcard
```
   note: please make sure your tlsdomain record correct before running when you enable autotls.
### Usage

use volume to save your data
```
docker run -dit --name haraka --network host --env-file /data/haraka/env -v /data/haraka:/data renothing/harak
```

#### users and auth
first user generated at `/data/config/auth_flat_file.ini`, you can add more users append it. 
for example: 
```
[users]
tester@yourdomain.com=FXasad17salasl
user1@yourdomain.com=81assad.a822
user2@yourdomain.com=9sa1asda.F.s
...
```

#### TLS and DKIM signatures
the server DKIM signatures saved at `/data/config/dkim/yourdomain.com`, please add its records in your own dns. 
ref: 
* http://haraka.github.io/manual/plugins/dkim_sign.html
* http://haraka.github.io/manual/plugins/tls.html
* https://github.com/xenolf/lego
