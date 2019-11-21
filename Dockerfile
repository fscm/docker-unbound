FROM fscm/debian:buster as build

ARG BIND_VERSION="9.14.7"
ARG BUSYBOX_VERSION="1.31.0"
ARG OPENSSL_VERSION="1.1.1d"
ARG UNBOUND_VERSION="1.9.4"

ENV \
  LANG=C.UTF-8 \
  DEBIAN_FRONTEND=noninteractive

COPY files/ /root/

WORKDIR /root

RUN \
# dependencies
  apt-get -qq update && \
  apt-get -qq -y -o=Dpkg::Use-Pty=0 --no-install-recommends install \
    ca-certificates \
    curl \
    dpkg-dev \
    file \
    gcc \
    libc-dev \
    libcap-dev \
    libevent-dev \
    libexpat1-dev \
    libfstrm-dev \
    libprotobuf-c-dev \
    make \
    nettle-dev \
    protobuf-c-compiler \
    tar \
    > /dev/null 2>&1 && \
# local vars
  __GNU_TYPE__=$(dpkg-architecture --query DEB_BUILD_GNU_TYPE) && \
  __NPROC__=$(getconf _NPROCESSORS_ONLN) && \
# build structure
  for folder in bin sbin lib lib64; do install --directory --owner=root --group=root --mode=0755 /build/usr/${folder}; ln -s usr/${folder} /build/${folder}; done && \
  for folder in tmp data; do install --directory --owner=root --group=root --mode=1777 /build/${folder}; done && \
# copy tests
  #install --directory --owner=root --group=root --mode=0755 /build/usr/bin && \
  install --owner=root --group=root --mode=0755 --target-directory=/build/usr/bin /root/tests/* && \
# copy scripts
  install --owner=root --group=root --mode=0755 --target-directory=/build/usr/bin /root/scripts/* && \
# busybox
  curl --silent --location --retry 3 "https://busybox.net/downloads/binaries/${BUSYBOX_VERSION}-i686-uclibc/busybox" \
    -o /build/usr/bin/busybox && \
  chmod +x /build/usr/bin/busybox && \
  for p in [ awk basename bc cat chroot chmod cp date diff du env getopt grep gzip hostname id kill killall ln ls mkdir mknod mktemp more mv nproc ping printf ps pwd rm sed sh stty; do ln /build/usr/bin/busybox /build/usr/bin/${p}; done && \
  for p in arp ip ipaddr nameif; do ln /build/usr/bin/busybox /build/usr/sbin/${p}; done && \
# openssl
  install --directory /src/openssl && \
  curl --silent --location --retry 3 "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" \
    | tar xz --no-same-owner --strip-components=1 -C /src/openssl && \
  cd /src/openssl && \
  ./config -Wl,-rpath=/usr/lib/${__GNU_TYPE__} \
    --prefix="/usr" \
    --openssldir="/etc/ssl" \
    --libdir="/usr/lib/${__GNU_TYPE__}" \
    no-idea \
    no-mdc2 \
    no-rc5 \
    no-zlib \
    no-ssl3 \
    no-ssl3-method \
    enable-rfc3779 \
    enable-cms \
    enable-ec_nistp_64_gcc_128 && \
  make --silent -j "${__NPROC__}" && \
  make --silent install_sw install_ssldirs DESTDIR=/build INSTALL='install -p' && \
  find /build -depth -type f -name c_rehash -delete && \
  #find /build -depth \( \( -type d -a \( -name include -o -name pkgconfig -o -name share \) \) -o \( -type f -a \( -name '*.a' -o -name '*.la' -o -name '*.dist' \) \) \) -exec rm -rf '{}' + && \
  cd - && \
# use built openssl
  rm -f /usr/lib/x86_64-linux-gnu/libssl.* /usr/lib/x86_64-linux-gnu/libcrypto.* /usr/bin/openssl && \
  ln -s /build/usr/lib/x86_64-linux-gnu/libssl.* /usr/lib/x86_64-linux-gnu/ && \
  ln -s /build/usr/lib/x86_64-linux-gnu/libcrypto.* /usr/lib/x86_64-linux-gnu/ && \
  ln -s /build/usr/bin/openssl /usr/bin/openssl && \
  ln -s /build/usr/include/openssl /usr/include/openssl && \
  #echo '/build/usr/lib/x86_64-linux-gnu' > /etc/ld.so.conf.d/00_build.conf && \
  #ldconfig && \
# bind utilities
  install --directory /src/bind && \
  curl --silent --location --retry 3 "https://downloads.isc.org/isc/bind${BIND_VERSION%%.*}/${BIND_VERSION}/bind-${BIND_VERSION}.tar.gz" \
    | tar xz --no-same-owner --strip-components=1 -C /src/bind/ && \
  cd /src/bind && \
  ./configure LDFLAGS="-Wl,-rpath,/usr/lib/${__GNU_TYPE__}" \
    --quiet \
    --prefix="/usr" \
    --libdir="/usr/lib/${__GNU_TYPE__}" \
    --with-gssapi=no \
    --with-libtool \
    --with-openssl="/usr" \
    --without-libxml2 \
    --without-libjson \
    --without-lmdb \
    --without-python \
    --disable-epoll \
    --disable-kqueue \
    --disable-devpoll \
    --disable-linux-caps \
    --disable-symtable \
    --enable-shared \
    --enable-dnstap && \
  make --silent -j "${__NPROC__}" --directory=lib/isc && \
  make --silent -j "${__NPROC__}" --directory=lib/dns && \
  make --silent -j "${__NPROC__}" --directory=lib/isccfg && \
  make --silent -j "${__NPROC__}" --directory=lib/irs && \
  make --silent -j "${__NPROC__}" --directory=lib/ns && \
  make --silent -j "${__NPROC__}" --directory=lib/bind9 && \
  make --silent -j "${__NPROC__}" --directory=bin/dig && \
  make --silent --directory=lib/isc install DESTDIR=/build INSTALL='install -p' && \
  make --silent --directory=lib/dns install DESTDIR=/build INSTALL='install -p' && \
  make --silent --directory=lib/isccfg install DESTDIR=/build INSTALL='install -p' && \
  make --silent --directory=lib/irs install DESTDIR=/build INSTALL='install -p' && \
  make --silent --directory=lib/ns install DESTDIR=/build INSTALL='install -p' && \
  make --silent --directory=lib/bind9 install DESTDIR=/build INSTALL='install -p' && \
  make --silent --directory=bin/dig install DESTDIR=/build INSTALL='install -p' && \
  #find /build -depth \( \( -type d -a \( -name include -o -name pkgconfig -o -name share \) \) -o \( -type f -a \( -name '*.a' -o -name '*.la' -o -name '*.dist' \) \) \) -exec rm -rf '{}' + && \
  cd - && \
# unbound
  install --directory /src/unbound && \
  curl --silent --location --retry 3 "https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz" \
    | tar xz --no-same-owner --strip-components=1 -C /src/unbound/ && \
  cd /src/unbound && \
  ./configure LDFLAGS="-Wl,-rpath,/usr/lib/${__GNU_TYPE__}" \
    --quiet \
    --prefix="/usr" \
    --libdir="/usr/lib/${__GNU_TYPE__}" \
    --sysconfdir="/data" \
    --with-pidfile="/tmp/unbound.pid" \
    --with-rootkey-file="/data/unbound/root.key" \
    --with-libevent \
    --with-pthreads \
    --with-chroot-dir="" \
    --with-dnstap-socket-path="/tmp/dnstap.sock" \
    --without-pyunbound \
    --without-pythonmodule \
    --enable-subnet \
    --enable-dnstap \
    --enable-event-api \
    --enable-static=no && \
  make --silent -j "${__NPROC__}" && \
  make --silent install DESTDIR=/build INSTALL='install -p' && \
  find /build/data -depth -type d -name unbound -exec rm -rf '{}' + && \
  find /build -depth \( \( -type d -a \( -name include -o -name pkgconfig -o -name share \) \) -o \( -type f -a \( -name '*.a' -o -name '*.la' -o -name '*.dist' \) \) \) -exec rm -rf '{}' + && \
  cd - && \
# system settings
  install --directory --owner=root --group=root --mode=0755 /build/run/systemd && \
  echo 'docker' > /build/run/systemd/container && \
# lddcp
  curl --silent --location --retry 3 "https://raw.githubusercontent.com/fscm/tools/master/lddcp/lddcp" -o ./lddcp && \
  chmod +x ./lddcp && \
  ./lddcp $(for f in `find /build/ -type f -executable`; do echo "-p $f "; done) $(for f in `find /lib/x86_64-linux-gnu/ \( -name 'libnss*' -o -name 'libresolv*' \)`; do echo "-l $f "; done) -d /build && \
# ca certificates
  install --owner=root --group=root --mode=0644 --target-directory=/build/etc/ssl/certs /etc/ssl/certs/*.pem && \
  chroot /build openssl rehash /etc/ssl/certs && \
  install --owner=root --group=root --mode=0644 /etc/ssl/certs/ca-certificates.crt /build/etc/ssl/certs



FROM scratch

LABEL \
  maintainer="Frederico Martins <https://hub.docker.com/u/fscm/>"

EXPOSE 53/udp

COPY --from=build \
  /build .

VOLUME ["/data"]

WORKDIR /data

ENV LANG=C.UTF-8

ENTRYPOINT ["/usr/bin/run"]

CMD ["help"]
