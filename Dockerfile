# global args
ARG __BUILD_DIR__="/build"
ARG __DATA_DIR__="/data"



FROM fscm/centos:8 as build

ARG __BUILD_DIR__
ARG __DATA_DIR__
ARG BIND_VERSION="9.17.1"
ARG EXPAT_VERSION="2.2.9"
ARG LIBEVENT_VERSION="2.1.11"
ARG LIBUV_VERSION="1.37.0"
ARG OPENSSL_VERSION="1.1.1g"
ARG UNBOUND_VERSION="1.10.0"
ARG __TOOLCHAIN__="/usr/local/toolchain"
ARG __USER__="root"
ARG __WORK_DIR__="/work"
ARG __SOURCE_DIR__="${__WORK_DIR__}/src"

ENV \
  LANG="C.utf8" \
  LC_ALL="C.utf8" \
  PATH="${__TOOLCHAIN__}/bin:${PATH}"

USER ${__USER__}

COPY "LICENSE" "files/" "${__WORK_DIR__}/"
COPY --from=busybox:uclibc "/bin/busybox" "${__WORK_DIR__}/"
COPY --from=fscm/toolchain:0.0.1 "${__TOOLCHAIN__}" "${__TOOLCHAIN__}"

WORKDIR "${__WORK_DIR__}"

RUN \
# dependencies
  echo '=== instaling dependencies ===' && \
  yum --assumeyes --quiet --enablerepo=PowerTools install \
    bzip2 \
    curl \
    diffutils \
    file \
    findutils \
    flex \
    gawk \
    gzip \
    perl \
    pkgconf-pkg-config \
    python3 \
    sed \
    tar \
    xz && \
  alternatives --set python /usr/bin/python3 && \
# build env
  echo '=== setting build env ===' && \
  set +h && \
  export __NPROC__="$(getconf _NPROCESSORS_ONLN || echo 1)" && \
  export CFLAGS="-O3 -s -w -pipe -m64 -mtune=generic" && \
  export LDFLAGS="-Wl,-rpath,${__TOOLCHAIN__}/lib64" && \
  export LIBTOOLFLAGS="--quiet" && \
  export MAKEFLAGS="--silent --output-sync --no-print-directory --jobs ${__NPROC__} V=0" && \
# build structure
  echo '=== creating build structure ===' && \
  for folder in bin sbin; do install --directory --owner=${__USER__} --group=${__USER__} --mode=0755 "${__BUILD_DIR__}/usr/${folder}"; ln --symbolic "usr/${folder}" "${__BUILD_DIR__}/${folder}"; done && \
  for folder in tmp "${__DATA_DIR__}"; do install --directory --owner=${__USER__} --group=${__USER__} --mode=1777 "${__BUILD_DIR__}/${folder}"; done && \
# copy tests
  echo '=== copying test files ===' && \
  install --owner=${__USER__} --group=${__USER__} --mode=0755 --target-directory="${__BUILD_DIR__}/usr/bin" "${__WORK_DIR__}/tests"/* && \
# copy scripts
  echo '=== copying scripts ===' && \
  install --owner=${__USER__} --group=${__USER__} --mode=0755 --target-directory="${__BUILD_DIR__}/usr/bin" "${__WORK_DIR__}/scripts"/* && \
# openssl
  echo '=== installing openssl ===' && \
  install --directory "${__SOURCE_DIR__}/openssl/_build" && \
  curl --silent --location --retry 3 "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" \
    | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/openssl" && \
  cd "${__SOURCE_DIR__}/openssl/_build" && \
  ../config \
    --prefix="${__TOOLCHAIN__}" \
    --libdir="${__TOOLCHAIN__}/lib64" \
    --openssldir='/etc/ssl' \
    --release \
    enable-cms \
    enable-ec_nistp_64_gcc_128 \
    enable-rfc3779 \
    no-weak-ssl-ciphers \
    no-ssl3 \
    zlib \
    -DOPENSSL_NO_HEARTBEATS && \
  make > /dev/null && \
  make install_sw > /dev/null && \
  make install_ssldirs DESTDIR="${__BUILD_DIR__}" > /dev/null && \
  install --owner=${__USER__} --group=${__USER__} --mode=0755 --target-directory="${__BUILD_DIR__}/usr/bin" "${__TOOLCHAIN__}/bin/openssl" && \
  find "${__BUILD_DIR__}/etc" -type f -name '*.dist' -delete && \
  find "${__BUILD_DIR__}/etc/ssl/misc" -not -type d -delete && \
  install --directory --owner=${__USER__} --group=${__USER__} --mode=0755 "${__BUILD_DIR__}/licenses/openssl" && \
  (cd "${__SOURCE_DIR__}/openssl" && find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/openssl" ';') && \
  cd - && \
  rm -rf "${__SOURCE_DIR__}/openssl" && \
# mozilla root certificates
  echo '=== installing root certificates ===' && \
  install --directory "${__SOURCE_DIR__}/certificates/certs" && \
  curl --silent --location --retry 3 "https://github.com/mozilla/gecko-dev/raw/master/security/nss/lib/ckfw/builtins/certdata.txt" \
    --output "${__SOURCE_DIR__}/certificates/certdata.txt" && \
  cd "${__SOURCE_DIR__}/certificates" && \
  for cert in $(sed -n -e '/^# Certificate/=' "${__SOURCE_DIR__}/certificates/certdata.txt"); do \
    awk "NR==${cert},/^CKA_TRUST_STEP_UP_APPROVED/" "${__SOURCE_DIR__}/certificates/certdata.txt" > "${__SOURCE_DIR__}/certificates/certs/${cert}.tmp"; \
  done && \
  for file in "${__SOURCE_DIR__}/certificates/certs/"*.tmp; do \
    _cert_name_=$(sed -n -e '/^# Certificate/{s/ /_/g;s/.*"\(.*\)".*/\1/p}' "${file}"); \
    printf $(awk '/^CKA_VALUE/{flag=1;next}/^END/{flag=0}flag{printf $0}' "${file}") \
      | openssl x509 -inform DER -outform PEM -out "${__SOURCE_DIR__}/certificates/certs/${_cert_name_}.crt"; \
  done && \
  install --directory --owner=${__USER__} --group=${__USER__} --mode=0755 "${__BUILD_DIR__}/etc/ssl/certs" && \
  install --owner=${__USER__} --group=${__USER__} --mode=0644 --target-directory="${__BUILD_DIR__}/etc/ssl/certs" "${__SOURCE_DIR__}/certificates/certs"/*.crt && \
  c_rehash "${__BUILD_DIR__}/etc/ssl/certs" && \
  cat "${__SOURCE_DIR__}/certificates/certs"/*.crt > "${__BUILD_DIR__}/etc/ssl/certs/certificates.crt" && \
  install --directory --owner=${__USER__} --group=${__USER__} --mode=0755 "${__BUILD_DIR__}/licenses/mozilla/certificates" && \
  curl --silent --location --retry 3 "https://raw.githubusercontent.com/spdx/license-list-data/master/text/MPL-2.0.txt" \
    --output "${__BUILD_DIR__}/licenses/mozilla/certificates/MPL-2.0" && \
  cd - && \
  rm -rf "${__SOURCE_DIR__}/certificates" && \
# expat
  echo '=== installing expat ===' && \
  install --directory "${__SOURCE_DIR__}/expat/_build" && \
  curl --silent --location --retry 3 "https://github.com/libexpat/libexpat/releases/download/R_${EXPAT_VERSION//./_}/expat-${EXPAT_VERSION}.tar.gz" \
    | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/expat" && \
  cd "${__SOURCE_DIR__}/expat/_build" && \
  ../configure \
    --quiet \
    --prefix="${__TOOLCHAIN__}" \
    --libdir="${__TOOLCHAIN__}/lib64" \
    --without-docbook \
    --enable-silent-rules \
    --disable-static && \
  make > /dev/null && \
  make install-strip > /dev/null && \
  rm -f "${__TOOLCHAIN__}/lib64"/libexpat*.la && \
  install --directory --owner=${__USER__} --group=${__USER__} --mode=0755 "${__BUILD_DIR__}/licenses/expat" && \
  (cd "${__SOURCE_DIR__}/expat" && find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/expat" ';') && \
  cd - && \
  rm -rf "${__SOURCE_DIR__}/expat" && \
# libevent
  echo '=== installing libevent ===' && \
  install --directory "${__SOURCE_DIR__}/libevent/_build" && \
  curl --silent --location --retry 3 "https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}-stable/libevent-${LIBEVENT_VERSION}-stable.tar.gz" \
    | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/libevent" && \
  cd "${__SOURCE_DIR__}/libevent/_build" && \
  ../configure \
    --quiet \
    --prefix="${__TOOLCHAIN__}" \
    --libdir="${__TOOLCHAIN__}/lib64" \
    --enable-silent-rules \
    --disable-static && \
  make > /dev/null && \
  make install-strip > /dev/null && \
  rm -f "${__TOOLCHAIN__}/lib64"/libevent*.la && \
  install --directory --owner=${__USER__} --group=${__USER__} --mode=0755 "${__BUILD_DIR__}/licenses/libevent" && \
  (cd "${__SOURCE_DIR__}/libevent" && find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/libevent" ';') && \
  cd - && \
  rm -rf "${__SOURCE_DIR__}/libevent" && \
# libuv
  echo '=== installing libuv ===' && \
  install --directory "${__SOURCE_DIR__}/libuv/_build" && \
  curl --silent --location --retry 3 "https://dist.libuv.org/dist/v${LIBUV_VERSION}/libuv-v${LIBUV_VERSION}.tar.gz" \
    | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/libuv" && \
  cd "${__SOURCE_DIR__}/libuv/_build" && \
  ../autogen.sh && \
  ../configure \
    --quiet \
    --prefix="${__TOOLCHAIN__}" \
    --libdir="${__TOOLCHAIN__}/lib64" \
    --enable-silent-rules \
    --disable-static && \
  make > /dev/null && \
  make install-strip > /dev/null && \
  rm -f "${__TOOLCHAIN__}/lib64"/libuv*.la && \
  install --directory --owner=${__USER__} --group=${__USER__} --mode=0755 "${__BUILD_DIR__}/licenses/libuv" && \
  (cd "${__SOURCE_DIR__}/libuv" && find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/libuv" ';') && \
  cd - && \
  rm -rf "${__SOURCE_DIR__}/libuv" && \
# bind utilities
  echo '=== installing bind utilities ===' && \
  install --directory "${__SOURCE_DIR__}/bind/_build" && \
  curl --silent --location --retry 3 "https://downloads.isc.org/isc/bind${BIND_VERSION%%.*}/${BIND_VERSION}/bind-${BIND_VERSION}.tar.xz" \
    | tar xJ --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/bind" && \
  cd "${__SOURCE_DIR__}/bind/_build" && \
  sed -i'.orig' -e '/^MANPAGES =/ s/=.*/=/' -e '/mkinstalldirs.*mandir/d' ../bin/dig/Makefile.in && \
  ../configure \
    PKG_CONFIG_PATH="${__TOOLCHAIN__}/lib64/pkgconfig" \
    --quiet \
    --prefix="${__TOOLCHAIN__}" \
    --bindir='/usr/bin' \
    --libdir="${__TOOLCHAIN__}/lib64" \
    --sbindir='/usr/sbin' \
    --with-openssl="${__TOOLCHAIN__}" \
    --without-gssapi \
    --without-json-c \
    --without-libxml2 \
    --without-lmdb \
    --without-python \
    --enable-shared \
    --disable-dnstap \
    --disable-epoll \
    --disable-kqueue \
    --disable-devpoll \
    --disable-linux-caps \
    --disable-static  && \
  for lib in ./lib/{isc,dns,isccfg,irs,ns,bind${BIND_VERSION%%.*}}; do \
    make --directory="${lib}" > /dev/null; \
    make --directory="${lib}" install > /dev/null; \
  done && \
  make --directory=bin/dig > /dev/null && \
  make --directory=bin/dig install DESTDIR="${__BUILD_DIR__}" MANPAGES="" > /dev/null && \
  rm -f "${__TOOLCHAIN__}/lib64"/lib{isc,dns,isccfg,irs,ns,bind${BIND_VERSION%%.*}}*.la && \
  install --directory --owner=${__USER__} --group=${__USER__} --mode=0755 "${__BUILD_DIR__}/licenses/bind" && \
  (cd "${__SOURCE_DIR__}/bind" && find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' -o -name '*COPYRIGHT*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/bind" ';') && \
  cd - && \
  rm -rf "${__SOURCE_DIR__}/bind" && \
# unbound
  echo '=== installing unbound ===' && \
  install --directory "${__SOURCE_DIR__}/unbound/_build" && \
  curl --silent --location --retry 3 "https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz" \
    | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/unbound" && \
  cd "${__SOURCE_DIR__}/unbound/_build" && \
  ../configure \
    --quiet \
    --prefix='/usr' \
    --datarootdir='${prefix}/_delete_/share' \
    --includedir='${prefix}/_delete_/include' \
    --libdir="${__TOOLCHAIN__}/lib64" \
    --sysconfdir="${__DATA_DIR__}" \
    --with-chroot-dir="" \
    --with-libevent="${__TOOLCHAIN__}" \
    --with-libexpat="${__TOOLCHAIN__}" \
    --with-pidfile="/tmp/unbound.pid" \
    --with-pthreads \
    --with-rootkey-file="${__DATA_DIR__}/unbound/root.key" \
    --with-ssl="${__TOOLCHAIN__}" \
    --without-pythonmodule \
    --without-pyunbound \
    --enable-event-api \
    --enable-shared \
    --enable-subnet \
    --enable-tfo-client \
    --enable-tfo-server \
    --disable-dnstap \
    --disable-static && \
  make > /dev/null && \
  make install DESTDIR="${__BUILD_DIR__}" > /dev/null && \
  rm -rf "${__BUILD_DIR__}/usr/_delete_" && \
  rm -rf "${__BUILD_DIR__}${__TOOLCHAIN__}/lib64"/{pkgconfig,*.la} && \
  rm -rf "${__BUILD_DIR__}${__DATA_DIR__}"/* && \
  install --directory --owner=${__USER__} --group=${__USER__} --mode=0755 "${__BUILD_DIR__}/licenses/unbound" && \
  (cd "${__SOURCE_DIR__}/unbound" && find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/unbound" ';') && \
  cd - && \
  rm -rf "${__SOURCE_DIR__}/unbound" && \
# busybox
  echo '=== installing busybox ===' && \
  install --owner=${__USER__} --group=${__USER__} --mode=0755 --target-directory="${__BUILD_DIR__}/usr/bin" "${__WORK_DIR__}/busybox" && \
  install --directory --owner=${__USER__} --group=${__USER__} --mode=0755 "${__BUILD_DIR__}/licenses/busybox" && \
  curl --silent --location --retry 3 "https://busybox.net/downloads/busybox-$(${__BUILD_DIR__}/usr/bin/busybox --help | head -1 | sed -E -n -e 's/.*v([0-9\.]+) .*/\1/p').tar.bz2" \
    | tar xj --no-same-owner --strip-components=1 -C "${__BUILD_DIR__}/licenses/busybox" --wildcards '*LICENSE*' && \
  for p in [ awk basename bc cat chmod cp date diff getopt grep ip mkdir nproc printf rm sed sh test; do ln "${__BUILD_DIR__}/usr/bin/busybox" "${__BUILD_DIR__}/$(${__BUILD_DIR__}/usr/bin/busybox --list-full | sed 's/$/ /' | grep -F "/${p} " | sed 's/ $//')"; done && \
# lddcp
  echo '=== copying required libs ===' && \
  curl --silent --location --retry 3 --output "${__WORK_DIR__}/lddcp" "https://raw.githubusercontent.com/fscm/tools/master/lddcp/lddcp" && \
  chmod +x "${__WORK_DIR__}/lddcp" && \
  "${__WORK_DIR__}"/lddcp $(for f in `find "${__BUILD_DIR__}" -type f -not -links +1 -executable`; do echo "-p $f "; done) $(for f in `find "${__TOOLCHAIN__}/lib64" \( -name 'libnss*.so*' -o -name 'libresolv*.so*' \)`; do echo "-l $f "; done) -d "${__BUILD_DIR__}" && \
# stripping
  echo '=== stripping libraries and binaries ===' && \
  find "${__BUILD_DIR__}${__TOOLCHAIN__}/lib64" -type f -name '*.so*' -exec strip --strip-unneeded {} ';' && \
  find "${__BUILD_DIR__}/usr/bin" "${__BUILD_DIR__}/usr/sbin" -type f -not -links +1 -exec strip --strip-all {} ';' && \
# licenses
  echo '=== project licenses ===' && \
  install --owner=${__USER__} --group=${__USER__} --mode=0644 --target-directory="${__BUILD_DIR__}/licenses" "${__WORK_DIR__}/LICENSE" && \
# system settings
  echo '=== system settings ===' && \
  install --directory --owner=${__USER__} --group=${__USER__} --mode=0755 "${__BUILD_DIR__}/run/systemd" && \
  echo 'docker' > "${__BUILD_DIR__}/run/systemd/container" && \
# done
  echo '=== all done! ==='



FROM scratch

ARG __BUILD_DIR__
ARG __DATA_DIR__

LABEL \
  maintainer="Frederico Martins <https://hub.docker.com/u/fscm/>" \
  vendor="fscm" \
  cmd="docker container run --detach --publish 53:53/udp fscm/unbound start" \
  params="--volume ./:${__DATA_DIR__}:rw "

EXPOSE \
  53/tcp \
  53/udp

COPY --from=build "${__BUILD_DIR__}" "/"

VOLUME ["${__DATA_DIR__}"]

WORKDIR "${__DATA_DIR__}"

HEALTHCHECK \
  --interval=30s \
  --timeout=10s \
  --start-period=60s \
  CMD dig +short +tries=1 +time=5 @127.0.0.1 google.com || exit 99

ENTRYPOINT ["/usr/bin/run"]

CMD ["help"]
