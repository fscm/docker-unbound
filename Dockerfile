FROM fscm/debian:stretch as build

ARG BUSYBOX_VERSION="1.30.0"
ARG UNBOUND_VERSION="1.9.0"

ENV DEBIAN_FRONTEND=noninteractive

COPY files/ /root/

RUN \
  apt-get -qq update && \
  apt-get -qq -y -o=Dpkg::Use-Pty=0 --no-install-recommends install ca-certificates curl dnsutils file gcc libc-dev libevent-2.0 libevent-dev libexpat1 libexpat1-dev libfstrm-dev libprotobuf-c-dev libssl-dev make nettle-dev openssl protobuf-c-compiler tar && \
  sed -i '/path-include/d' /etc/dpkg/dpkg.cfg.d/90docker-excludes && \
  mkdir -p /build/data/unbound && \
  mkdir -p /build/etc/ssl/certs && \
  mkdir -p /src/apt/dpkg && \
  chmod -R o+rw /src/apt && \
  cp -r /var/lib/dpkg/* /src/apt/dpkg/ && \
  cd /src/apt && \
  apt-get -qq -y -o=Dpkg::Use-Pty=0 download bash ca-certificates dnsutils openssl && \
  dpkg --unpack --force-all --no-triggers --instdir=/build --admindir=/src/apt/dpkg --path-exclude="/etc*" --path-exclude="/usr/share*" bash_*.deb && \
  dpkg --unpack --force-all --no-triggers --instdir=/build --admindir=/src/apt/dpkg --path-exclude="/etc*" --path-exclude="/usr/sbin*" --path-exclude="/usr/share/*" --path-include="/usr/share/ca-certificates*" ca-certificates_*.deb && \
  dpkg --unpack --force-all --no-triggers --instdir=/build --admindir=/src/apt/dpkg --path-exclude="/usr/share*" dnsutils_*.deb && \
  dpkg --unpack --force-all --no-triggers --instdir=/build --admindir=/src/apt/dpkg --path-exclude="/etc*" --path-exclude="/usr/*" --path-include="/usr/bin*" openssl_*.deb && \
  ln -s /bin/bash /build/bin/sh && \
  for f in `find /build -name '*.dpkg-new'`; do mv "${f}" "${f%.dpkg-new}"; done && \
  update-ca-certificates --etccertsdir /build/etc/ssl/certs/ && \
  cd - && \
  mkdir -p /src/unbound && \
  curl -sL --retry 3 --insecure "https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz" | tar xz --no-same-owner --strip-components=1 -C /src/unbound/ && \
  cd /src/unbound && \
  ./configure --quiet --prefix=/ --libdir=/usr/lib --sysconfdir=/data --mandir=/tmp/unbound --includedir=/tmp/unbound --docdir=/tmp/unbound --disable-rpath --with-pidfile=/tmp/unbound.pid --with-rootkey-file=/data/unbound/root.key --with-libevent --with-pthreads --with-chroot-dir="" --with-dnstap-socket-path=/tmp/dnstap.sock --without-pyunbound --without-pythonmodule --enable-subnet --enable-dnstap --enable-event-api --enable-static=no && \
  make --silent && \
  make --silent install DESTDIR=/build && \
  make --silent clean && \
  rm -rf /usr/lib/libunbound* /usr/lib/pkgconfig && \
  ./configure --quiet --prefix=/ --libdir=/usr/lib --sysconfdir=/data --mandir=/tmp/unbound --includedir=/tmp/unbound --docdir=/tmp/unbound --disable-rpath --with-libunbound-only --with-nettle --with-rootkey-file=/data/unbound/root.key --with-libevent --with-pthreads --without-pyunbound --without-pythonmodule --enable-subnet --enable-dnstap --enable-event-api --enable-static=no && \
  make --silent && \
  make --silent install DESTDIR=/build && \
  rm -rf /build/tmp /build/data/unbound/* && \
  cd - && \
  mkdir -p /build/run/systemd && \
  echo 'docker' > /build/run/systemd/container && \
  curl -sL --retry 3 --insecure "https://raw.githubusercontent.com/fscm/tools/master/lddcp/lddcp" -o ./lddcp && \
  chmod +x ./lddcp && \
  ./lddcp $(for f in `find /build/ -type f -executable`; do echo "-p $f "; done) $(for f in `find /lib/x86_64-linux-gnu/ \( -name 'libnss*' -o -name 'libresolv*' \)`; do echo "-l $f "; done) -d /build && \
  curl -sL --retry 3 --insecure "https://busybox.net/downloads/binaries/${BUSYBOX_VERSION}-i686/busybox" -o /build/bin/busybox && \
  chmod +x /build/bin/busybox && \
  for p in [ [[ basename bc cat chroot cp date diff echo less ln ls mkdir more nproc ping ps rm; do ln -s busybox /build/bin/${p}; done && \
  mkdir -p /build/usr/local && \
  chmod a+x /root/scripts/* && \
  cp /root/scripts/* /build/bin/



FROM scratch

LABEL \
  maintainer="Frederico Martins <https://hub.docker.com/u/fscm/>"

EXPOSE 53

COPY --from=build \
  /build .

VOLUME ["/data/unbound"]

ENTRYPOINT ["/bin/run"]

CMD ["help"]
