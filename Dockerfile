FROM alpine:3.19 AS builder
ARG UNBOUND_VERSION=1.22.0

WORKDIR /build
RUN apk add curl build-base openssl-dev openssl-libs-static expat-dev expat-static libevent-dev libevent-static protobuf-c-dev protobuf-c-compiler && \
    curl -sSL -o root.hints https://www.internic.net/domain/named.root && \
    curl -sSL https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz | tar xz --strip 1 && \
    ./configure \
      --disable-flto \
      --disable-rpath \
      --enable-dnstap \
      --enable-fully-static \
      --enable-subnet \
      --enable-tfo-client \
      --enable-tfo-server \
      --localstatedir=/var \
      --prefix=/usr \
      --runstatedir=/run \
      --sysconfdir=/etc \
      --with-chroot-dir="" \
      --with-libevent \
      --with-pidfile=/run/unbound.pid \
      --with-pthreads \
      --with-ssl && \
    make install


FROM alpine:3.19

WORKDIR /etc/unbound

COPY --from=builder /usr/sbin/unbound /usr/sbin/unbound
COPY --from=builder /usr/sbin/unbound-anchor /usr/sbin/unbound-anchor
COPY --from=builder /build/root.hints /etc/unbound/root.hints

RUN addgroup -S -g 1000 unbound && \
    adduser -S -D -H -u 1000 -h /etc/unbound -G unbound unbound && \
    install -o unbound -g unbound -m 0755 -d /var/lib/unbound && \
    ( unbound-anchor -a /var/lib/unbound/root.key -r /etc/unbound/root.hints || true ) && \
    chown unbound:unbound /var/lib/unbound/root.key

EXPOSE 53/udp
ENTRYPOINT ["/usr/sbin/unbound", "-d"]
