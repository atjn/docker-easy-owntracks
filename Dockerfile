 # https://hub.docker.com/_/alpine/tags
FROM docker.io/alpine:3.16 AS builder

# https://github.com/owntracks/recorder/tags
ARG RECORDER_VERSION=0.9.2
ARG RECORDER_VERSION=master

# https://github.com/owntracks/frontend/tags
ARG FRONTEND_VERSION=v2.12.0
# ARG FRONTEND_VERSION=main

# https://github.com/authelia/authelia/tags
ARG AUTHELIA_VERSION=v4.36.8

RUN apk add --no-cache \
	make \
	gcc \
	git \
	shadow \
	musl-dev \
	curl \
	curl-dev \
	libconfig-dev \
	lmdb-dev \
	util-linux-dev \
	nodejs \
	yarn
    
RUN git clone --branch=${RECORDER_VERSION} https://github.com/owntracks/recorder /src/recorder
WORKDIR /src/recorder
COPY config.mk .
RUN make -j CC="cc -O2"
RUN make install DESTDIR=/recorder
WORKDIR /

RUN git clone --branch=${FRONTEND_VERSION} https://github.com/owntracks/frontend /src/frontend
WORKDIR /src/frontend
RUN yarn install
RUN yarn build
WORKDIR /

RUN mkdir /src/authelia
RUN curl -Ls https://github.com/authelia/authelia/releases/download/${AUTHELIA_VERSION}/authelia-${AUTHELIA_VERSION}-linux-amd64-musl.tar.gz | tar xzC /src/authelia
WORKDIR /src/authelia
RUN mv authelia-linux-amd64-musl authelia
WORKDIR /


# https://hub.docker.com/_/alpine/tags
FROM docker.io/alpine:3.16

VOLUME "/owntracks-storage"

RUN apk add --no-cache \
	jq \
	curl \
	libcurl \
	libconfig \
	lmdb \
	util-linux \
	nss-tools \
	xkcdpass \
	caddy

COPY /configs /configs
RUN mv /configs/Caddyfile /configs/Caddyfile.template
COPY /dashboard /dashboard

COPY --from=builder /recorder/usr /usr
COPY --from=builder /recorder/recorder /recorder

COPY --from=builder /src/frontend/dist /frontend
RUN ln -s /configs/frontend.conf.js /frontend/config/config.js

COPY --from=builder /src/authelia/authelia /usr/sbin/authelia

COPY entrypoint.sh /usr/sbin/entrypoint.sh

RUN chmod +x /usr/sbin/*.sh

EXPOSE 80
EXPOSE 443

# ENV OTR_CAFILE=/etc/ssl/cert.pem

ENTRYPOINT ["/usr/sbin/entrypoint.sh"]