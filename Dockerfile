# original version: https://github.com/MatthewVance/unbound-docker

ARG DEBIAN_REL

FROM debian:${DEBIAN_REL} as builder

ARG OPENSSL_VER
ARG UNBOUND_VER

ENV OPENSSL_DOWNLOAD_URL=https://www.openssl.org/source/openssl-${OPENSSL_VER}.tar.gz

WORKDIR /tmp/src

RUN set -e -x && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      #build-essential ca-certificates curl libidn2-0-dev libevent-dev libexpat1-dev libnghttp2-dev \
      build-essential ca-certificates curl libevent-dev libexpat1-dev libnghttp2-dev \
      bsdmainutils ldnsutils && \
    curl -L ${OPENSSL_DOWNLOAD_URL} -o openssl.tar.gz && \
    tar xzf openssl.tar.gz && \
    cd openssl-${OPENSSL_VER} && \
    ./config \
      --prefix=/opt/openssl \
      --openssldir=/opt/openssl \
      no-weak-ssl-ciphers \
      no-ssl3 \
      no-shared \
      enable-ec_nistp_64_gcc_128 \
      -DOPENSSL_NO_HEARTBEATS \
      -fstack-protector-strong && \
    make depend && \
    make && \
    make install_sw

ENV UNBOUND_DOWNLOAD_URL=https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VER}.tar.gz

WORKDIR /tmp/src

RUN set -x && \
    curl -sSL ${UNBOUND_DOWNLOAD_URL} -o unbound.tar.gz && \
    tar xzf unbound.tar.gz && \
    cd unbound-${UNBOUND_VER} && \
    groupadd _unbound && \
    useradd -g _unbound -s /etc -d /dev/null _unbound && \
    ./configure \
        --prefix=/opt/unbound \
        --with-username=_unbound \
        --with-ssl=/opt/openssl \
        --with-libevent \
        --with-libnghttp2 && \
    make install && \
    mv /opt/unbound/etc/unbound/unbound.conf /opt/unbound/etc/unbound/unbound.conf.example && \
    rm -rf \
      /opt/openssl/include \
      /opt/unbound/share \
      /opt/unbound/include 

FROM debian:${DEBIAN_REL}-slim

ARG UNBOUND_VER

LABEL maintainer="Mitsuru Shimamura <smbd.jp@gmail.com>" \
      org.opencontainers.image.title="smbd/unbound" \
      org.opencontainers.image.version=${UNBOUND_VER} \
      org.opencontainers.image.authors="Mitsuru Shimamura" \
      org.opencontainers.image.vendor="Mitsuru Shimamura" \
      org.opencontainers.image.description="unbound" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.url="https://github.com/smbd/docker-debian-unbound" \
      org.opencontainers.image.source="https://github.com/smbd/docker-debian-unbound/blob/main/Dockerfile"

COPY --from=builder /opt /opt
COPY data/ /

RUN set -x && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      procps \
      bind9-dnsutils \
      bsdmainutils \
      ca-certificates \
      vim-tiny \
      less \
      ldnsutils \
      libevent-2.1 \
      libnghttp2-14 \
      libexpat1 && \
    groupadd _unbound && \
    useradd -g _unbound -s /etc -d /dev/null _unbound && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    chmod +x /unbound.sh

WORKDIR /opt/unbound/

ENV PATH /opt/unbound/sbin:"$PATH"

EXPOSE 53/tcp
EXPOSE 53/udp

HEALTHCHECK --interval=10s --timeout=5s --start-period=10s --retries=3 CMD drill @127.0.0.1 -t ns . || exit 1

CMD ["/unbound.sh"]
