FROM fscm/debian:stretch as build

ARG BUSYBOX_VERSION="1.27.1-i686"
ARG UNBOUND_VERSION="1.8.3"

ENV DEBIAN_FRONTEND=noninteractive

COPY files/* /usr/local/bin/

RUN \
  apt-get -qq update && \
  apt-get -qq -y -o=Dpkg::Use-Pty=0 --no-install-recommends install curl tar make gcc ca-certificates libevent-2.0 libexpat1 openssl ldnsutils libssl-dev libc-dev libevent-dev libexpat1-dev file bc && \
  apt-get -qq -y -o=Dpkg::Use-Pty=0 download bash bc ca-certificates ldnsutils openssl && \
  sed -i '/path-include/d' /etc/dpkg/dpkg.cfg.d/90docker-excludes && \
  mkdir -p /build/bin && \
  mkdir -p /build/etc/ssl/certs && \
  mkdir -p /build/data/unbound && \
  dpkg --unpack --force-all --no-triggers --instdir=/build --path-exclude="/usr/share*" bc_*.deb && \
  dpkg --unpack --force-all --no-triggers --instdir=/build --path-exclude="/usr/share*" ldnsutils_*.deb && \
  dpkg --unpack --force-all --no-triggers --instdir=/build --path-exclude="/etc*" --path-exclude="/usr/share*" bash_*.deb && \
  dpkg --unpack --force-all --no-triggers --instdir=/build --path-exclude="/etc*" --path-exclude="/usr/*" --path-include="/usr/bin*" openssl_*.deb && \
  dpkg --unpack --force-all --no-triggers --instdir=/build --path-exclude="/etc*" --path-exclude="/usr/sbin*" --path-exclude="/usr/share/*" --path-include="/usr/share/ca-certificates*" ca-certificates_*.deb && \
  ln -s /bin/bash /build/bin/sh && \
  update-ca-certificates --etccertsdir /build/etc/ssl/certs/ && \
  mkdir -p /src/unbound && \
  curl -sL --retry 3 --insecure "https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz" | tar xz --no-same-owner --strip-components=1 -C /src/unbound/ && \
  cd /src/unbound && \
  ./configure --quiet --prefix=/ --libdir=/lib/unbound --mandir=/tmp/unbound --includedir=/tmp/unbound --docdir=/tmp/unbound --sysconfdir=/tmp/unbound --with-pidfile=/tmp/unbound.pid --without-pyunbound --without-pythonmodule --with-pthreads --with-libevent --enable-event-api --enable-static=no && \
  make --silent && \
  make --silent install DESTDIR=/build/ && \
  cd / && \
  rm -rf /build/tmp && \
  mkdir -p /build/run/systemd && \
  echo 'docker' > /build/run/systemd/container && \
  curl -sL --retry 3 --insecure "https://raw.githubusercontent.com/fscm/tools/master/lddcp/lddcp" -o ./lddcp && \
  chmod +x ./lddcp && \
  ./lddcp $(for f in /build/bin/*; do echo "-p ${f} "; done) $(for f in /build/sbin/*; do echo "-p ${f} "; done) $(for f in /build/usr/bin/*; do echo "-p ${f} "; done) -d /build && \
  curl -sL --retry 3 --insecure "https://busybox.net/downloads/binaries/${BUSYBOX_VERSION}/busybox" -o /build/bin/busybox && \
  chmod +x /build/bin/busybox && \
  for p in [ [[ basename cat chroot cp date diff echo less ls mkdir nproc rm; do ln -s busybox /build/bin/${p}; done && \
  ln -s /bin/ip /build/sbin/ip && \
  chmod a+x /usr/local/bin/* && \
  cp /usr/local/bin/* /build/bin/



FROM scratch

LABEL \
  maintainer="Frederico Martins <https://hub.docker.com/u/fscm/>"

EXPOSE 53

COPY --from=build \
  /build .

VOLUME ["/data/unbound"]

ENTRYPOINT ["/bin/run"]

CMD ["help"]
