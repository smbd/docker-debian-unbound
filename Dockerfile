# syntax=docker/dockerfile:1
# original version: https://github.com/MatthewVance/unbound-docker

ARG DEBIAN_REL=bookworm

FROM debian:${DEBIAN_REL} AS builder

ARG DEBIAN_REL
ARG OPENSSL_VER=3.4.0
ARG UNBOUND_VER=1.22.0

ARG OPENSSL_DOWNLOAD_URL=https://www.openssl.org/source/openssl-${OPENSSL_VER}.tar.gz

WORKDIR /tmp/src

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get -qq update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential ca-certificates curl libevent-dev libexpat1-dev libnghttp2-dev

RUN curl -L ${OPENSSL_DOWNLOAD_URL} -o openssl.tar.gz && \
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

ARG UNBOUND_DOWNLOAD_URL=https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VER}.tar.gz

WORKDIR /tmp/src

RUN curl -sSL ${UNBOUND_DOWNLOAD_URL} -o unbound.tar.gz && \
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

COPY --from=builder /opt /opt
COPY data/ /

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get -qq update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates \
      ldnsutils \
      libevent-2.1 \
      libnghttp2-14 \
      libexpat1 && \
    groupadd _unbound && \
    useradd -g _unbound -s /etc -d /dev/null _unbound && \
    chmod +x /unbound.sh

WORKDIR /opt/unbound/

ENV PATH=/opt/unbound/sbin:"$PATH"

EXPOSE 53/tcp
EXPOSE 53/udp

HEALTHCHECK --interval=10s --timeout=5s --start-period=10s --retries=3 CMD drill @127.0.0.1 -t ns . || exit 1

CMD ["/unbound.sh"]
