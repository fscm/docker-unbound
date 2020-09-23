# global args
ARG __BUILD_DIR__="/build"
ARG __DATA_DIR__="/data"
ARG __UNBOUND_DATA_DIR__="${__DATA_DIR__}/unbound"



FROM fscm/debian:buster as build

ARG __BUILD_DIR__
ARG __DATA_DIR__
ARG __UNBOUND_DATA_DIR__
ARG BIND_VERSION="9.17.5"
ARG KERNEL_VERSION="5.8.7"
ARG LIBEVENT_VERSION="2.1.12"
ARG LIBEXPAT_VERSION="2.2.9"
ARG LIBUV_VERSION="1.39.0"
ARG OPENSSL_VERSION="1.1.1g"
ARG UNBOUND_VERSION="1.11.0"
ARG ZLIB_VERSION="1.2.11"
ARG __USER__="root"
ARG __WORK_DIR__="/work"
ARG __SOURCE_DIR__="${__WORK_DIR__}/src"

ENV \
  LANG="C.UTF-8" \
  LC_ALL="C.UTF-8" \
  DEBCONF_NONINTERACTIVE_SEEN="true" \
  DEBIAN_FRONTEND="noninteractive"

USER "${__USER__}"

COPY "LICENSE" "files/" "${__WORK_DIR__}"/
COPY --from=busybox:uclibc "/bin/busybox" "${__WORK_DIR__}"/

WORKDIR "${__WORK_DIR__}"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN \
# build env
  echo '=== setting build env ===' && \
  time { \
    set +h && \
    export __NPROC__="$(getconf _NPROCESSORS_ONLN || echo 1)" && \
    export MAKEFLAGS="--silent --output-sync --no-print-directory --jobs ${__NPROC__} V=0" && \
    export PKG_CONFIG_PATH="/usr/lib/x86_64-linux-musl/pkgconfig" && \
    export TIMEFORMAT='=== time taken: %lR' ; \
  } && \
# build structure
  echo '=== creating build structure ===' && \
  time { \
    for folder in 'bin' 'sbin'; do \
      install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/usr/${folder}"; \
      ln --symbolic "usr/${folder}" "${__BUILD_DIR__}/${folder}"; \
    done && \
    for folder in 'include' 'lib'; do \
      ln --symbolic "/usr/${folder}/x86_64-linux-musl" "${__BUILD_DIR__}/usr/${folder}"; \
    done && \
    for folder in '/tmp' "${__DATA_DIR__}"; do \
      install --directory --owner="${__USER__}" --group="${__USER__}" --mode=1777 "${__BUILD_DIR__}${folder}"; \
    done ; \
  } && \
# copy tests
  echo '=== copying test files ===' && \
  time { \
    install --owner="${__USER__}" --group="${__USER__}" --mode=0755 --target-directory="${__BUILD_DIR__}/usr/bin" "${__WORK_DIR__}/tests"/* ; \
  } && \
# copy scripts
  echo '=== copying script files ===' && \
  time { \
    install --owner="${__USER__}" --group="${__USER__}" --mode=0755 --target-directory="${__BUILD_DIR__}/usr/bin" "${__WORK_DIR__}/scripts"/* ; \
  } && \
# dependencies
  echo '=== instaling dependencies ===' && \
  time { \
    apt-get -qq update && \
    apt-get -qq -y -o=Dpkg::Use-Pty=0 --no-install-recommends install \
      autoconf \
      automake \
      bison \
      bzip2 \
      ca-certificates \
      curl \
      file \
      flex \
      gcc \
      libc-dev \
      libtool \
      libtool-bin \
      make \
      musl-tools \
      openssl \
      pkg-config \
      rsync \
      xz-utils \
      > /dev/null 2>&1 ; \
  } && \
# kernel headers
  echo '=== installing kernel headers ===' && \
  time { \
    install --directory "${__SOURCE_DIR__}/kernel" && \
    curl --silent --location --retry 3 "https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_VERSION%%.*}.x/linux-${KERNEL_VERSION}.tar.xz" \
      | tar xJ --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/kernel" --wildcards "*LICENSE*" "*COPYING*" $(echo linux-*/{Makefile,arch,include,scripts,tools,usr}) && \
    cd "${__SOURCE_DIR__}/kernel" && \
    make INSTALL_HDR_PATH="./_headers" headers_install > /dev/null && \
    cp --recursive './_headers/include'/*  "${__BUILD_DIR__}/usr/include" && \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/linux" && \
    find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/linux" ';' && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/kernel" ; \
  } && \
# zlib
  echo '=== installing zlib ===' && \
  time { \
    install --directory "${__SOURCE_DIR__}/zlib/_build" && \
    curl --silent --location --retry 3 "https://zlib.net/zlib-${ZLIB_VERSION}.tar.xz" \
      | tar xJ --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/zlib" && \
    cd "${__SOURCE_DIR__}/zlib/_build" && \
    sed -i.orig -e '/(man3dir)/d' ../Makefile.in && \
    CC="musl-gcc -static --static --sysroot='${__BUILD_DIR__}'" \
    ../configure \
      --includedir='/usr/include' \
      --libdir='/usr/lib' \
      --prefix='/usr' \
      --sysconfdir='/etc' \
      --static \
      > /dev/null && \
    make > /dev/null && \
    make DESTDIR="${__BUILD_DIR__}" install > /dev/null && \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/zlib" && \
    (cd .. && find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/zlib" ';') && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/zlib" ; \
  } && \
# openssl
  echo '=== installing openssl ===' && \
  time { \
    install --directory "${__SOURCE_DIR__}/openssl/_build" && \
    curl --silent --location --retry 3 "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" \
      | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/openssl" && \
    cd "${__SOURCE_DIR__}/openssl/_build" && \
    ../config \
      CC="musl-gcc -static --static --sysroot='${__BUILD_DIR__}'" \
      --libdir='/usr/lib' \
      --openssldir='/etc/ssl' \
      --prefix='/usr' \
      --release \
      --static \
      enable-cms \
      enable-ec_nistp_64_gcc_128 \
      enable-rfc3779 \
      no-comp \
      no-shared \
      no-ssl3 \
      no-weak-ssl-ciphers \
      no-zlib \
      -pipe \
      -static \
      -DNDEBUG \
      -DOPENSSL_NO_HEARTBEATS && \
    make > /dev/null && \
    make DESTDIR="${__BUILD_DIR__}" install_sw > /dev/null && \
    make DESTDIR="${__BUILD_DIR__}" install_ssldirs > /dev/null && \
    rm -rf "${__BUILD_DIR__}/etc/ssl/misc" && \
    rm -rf "${__BUILD_DIR__}/usr/bin/c_rehash" && \
    find "${__BUILD_DIR__}/etc" -type f -name '*.dist' -delete && \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/openssl" && \
    (cd .. && find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/openssl" ';') && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/openssl" ; \
  } && \
# libexpat
  echo '=== installing libexpat ===' && \
  time { \
    install --directory "${__SOURCE_DIR__}/libexpat/_build" && \
    curl --silent --location --retry 3 "https://github.com/libexpat/libexpat/releases/download/R_${LIBEXPAT_VERSION//./_}/expat-${LIBEXPAT_VERSION}.tar.gz" \
      | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/libexpat" && \
    cd "${__SOURCE_DIR__}/libexpat/_build" && \
    for file in $(find ../ -name 'Makefile.in'); do \
      sed -i.orig \
      -e '/^install-data-hook:/ s/:.*/:/' -e '/^install-data-hook:/,/^$/{//!d}' \
      -e '/^doc_DATA =/ s/=.*/=/' -e '/^doc_DATA =/,/^$/{//!d}' "${file}"; \
    done && \
    ../configure \
      CC="musl-gcc -static --static --sysroot='${__BUILD_DIR__}'" \
      --quiet \
      --includedir='/usr/include' \
      --libdir='/usr/lib' \
      --libexecdir='/usr/libexec' \
      --prefix='/usr' \
      --sysconfdir='/etc' \
      --without-docbook \
      --without-examples \
      --without-tests \
      --without-xmlwf \
      --enable-fast-install \
      --enable-silent-rules \
      --enable-static \
      --disable-shared && \
    make > /dev/null && \
    make DESTDIR="${__BUILD_DIR__}" install > /dev/null && \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/libexpat" && \
    (cd .. && find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/libexpat" ';') && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/libexpat" ; \
  } && \
# libevent
  echo '=== installing libevent ===' && \
  time { \
    install --directory "${__SOURCE_DIR__}/libevent/_build" && \
    curl --silent --location --retry 3 "https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}-stable/libevent-${LIBEVENT_VERSION}-stable.tar.gz" \
      | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/libevent" && \
    cd "${__SOURCE_DIR__}/libevent/_build" && \
    ../configure \
      CC="musl-gcc -static --static --sysroot='${__BUILD_DIR__}'" \
      --quiet \
      --includedir='/usr/include' \
      --libdir='/usr/lib' \
      --libexecdir='/usr/libexec' \
      --prefix='/usr' \
      --sysconfdir='/etc' \
      --enable-fast-install \
      --enable-silent-rules \
      --enable-static \
      --disable-debug-mode \
      --disable-doxygen-html \
      --disable-samples \
      --disable-shared && \
    make > /dev/null && \
    make DESTDIR="${__BUILD_DIR__}" install > /dev/null && \
    rm -rf "${__BUILD_DIR__}/usr/bin/event_rpcgen.py" && \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/libevent" && \
    (cd .. && find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/libevent" ';') && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/libevent" ; \
  } && \
# libuv
  echo '=== installing libuv ===' && \
  time { \
    install --directory "${__SOURCE_DIR__}/libuv/_build" && \
    curl --silent --location --retry 3 "https://dist.libuv.org/dist/v${LIBUV_VERSION}/libuv-v${LIBUV_VERSION}.tar.gz" \
      | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/libuv" && \
    cd "${__SOURCE_DIR__}/libuv/_build" && \
    ../autogen.sh && \
    ../configure \
      CC="musl-gcc -static --static --sysroot='${__BUILD_DIR__}'" \
      --quiet \
      --includedir='/usr/include' \
      --libdir='/usr/lib' \
      --libexecdir='/usr/libexec' \
      --prefix='/usr' \
      --sysconfdir='/etc' \
      --enable-fast-install \
      --enable-silent-rules \
      --enable-static \
      --disable-shared && \
    make > /dev/null && \
    make DESTDIR="${__BUILD_DIR__}" install > /dev/null && \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/libuv" && \
    (cd .. && find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/libuv" ';') && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/libuv" ; \
  } && \
# zlib
  echo '=== installing zlib ===' && \
  time { \
    install --directory "${__SOURCE_DIR__}/zlib/_build" && \
    curl --silent --location --retry 3 "https://zlib.net/zlib-${ZLIB_VERSION}.tar.xz" \
      | tar xJ --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/zlib" && \
    cd "${__SOURCE_DIR__}/zlib/_build" && \
    sed -i.orig -e '/(man3dir)/d' ../Makefile.in && \
    CC="musl-gcc -static --static --sysroot='${__BUILD_DIR__}'" \
    ../configure \
      --includedir='/usr/include' \
      --libdir='/usr/lib' \
      --prefix='/usr' \
      --sysconfdir='/etc' \
      --static \
      > /dev/null && \
    make > /dev/null && \
    make DESTDIR="${__BUILD_DIR__}" install > /dev/null && \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/zlib" && \
    (cd .. && find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/zlib" ';') && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/zlib" ; \
  } && \
\
# bind utilities
  echo '=== installing bind utilities ===' && \
  time { \
    install --directory "${__SOURCE_DIR__}/bind/_build" && \
    curl --silent --location --retry 3 "https://downloads.isc.org/isc/bind${BIND_VERSION%%.*}/${BIND_VERSION}/bind-${BIND_VERSION}.tar.xz" \
      | tar xJ --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/bind" && \
    cd "${__SOURCE_DIR__}/bind/_build" && \
    ../configure \
      CC="musl-gcc -static --static --sysroot='${__BUILD_DIR__}'" \
      --quiet \
      --includedir='/usr/include' \
      --libdir='/usr/lib' \
      --libexecdir='/usr/libexec' \
      --localstatedir='/tmp' \
      --prefix='/usr' \
      --with-zlib \
      --without-cmocka \
      --enable-developer \
      --enable-ltdl-install \
      --enable-mutex-atomics \
      --enable-shared \
      --enable-static \
      --disable-linux-caps && \
    for target in ./libltdl ./lib/{isc,dns,isccfg,irs,ns,bind${BIND_VERSION%%.*}} ./bin/dig; do \
      make --directory="${target}" > /dev/null; \
    done && \
    make --directory='bin/dig' DESTDIR="${__BUILD_DIR__}" MANPAGES="" install > /dev/null && \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/bind" && \
    (cd .. && find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/bind" ';') && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/bind" ; \
  } && \
# unbound
  echo '=== installing unbound ===' && \
  time { \
    install --directory "${__SOURCE_DIR__}/unbound/_build" && \
    curl --silent --location --retry 3 "https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz" \
      | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/unbound" && \
    cd "${__SOURCE_DIR__}/unbound/_build" && \
    for file in $(find ../ -name 'Makefile.in'); do \
      sed -i.orig \
        -e '/for mpage in/,/done/d' \
        -e '/INSTALL.*-[cd].*mandir/d' "${file}"; \
    done && \
    ../configure \
      CC="musl-gcc -static --static --sysroot='${__BUILD_DIR__}'" \
      --quiet \
      --includedir='/usr/include' \
      --libdir='/usr/lib' \
      --libexecdir='/usr/libexec' \
      --prefix='/usr' \
      --sysconfdir='/etc' \
      --with-chroot-dir="" \
      --with-libevent="${__BUILD_DIR__}/usr" \
      --with-libexpat="${__BUILD_DIR__}/usr" \
      --with-pidfile="/tmp/unbound.pid" \
      --with-pthreads \
      --with-rootkey-file="${__UNBOUND_DATA_DIR__}/root.key" \
      --with-run-dir="" \
      --with-ssl="${__BUILD_DIR__}/usr" \
      --without-pythonmodule \
      --without-pyunbound \
      --enable-event-api \
      --enable-fast-install \
      --enable-static \
      --enable-subnet \
      --enable-tfo-client \
      --enable-tfo-server \
      --disable-dnstap \
      --disable-shared && \
    make > /dev/null && \
    make DESTDIR="${__BUILD_DIR__}" install > /dev/null && \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/unbound" && \
    (cd .. && find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/unbound" ';') && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/unbound" ; \
  } && \
# busybox
  echo '=== installing busybox ===' && \
  time { \
    install --owner="${__USER__}" --group="${__USER__}" --mode=0755 --target-directory="${__BUILD_DIR__}/usr/bin" "${__WORK_DIR__}/busybox" && \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/busybox" && \
    curl --silent --location --retry 3 "https://busybox.net/downloads/busybox-$(${__BUILD_DIR__}/usr/bin/busybox --help | head -1 | sed -E -n -e 's/.*v([0-9\.]+) .*/\1/p').tar.bz2" \
      | tar xj --no-same-owner --strip-components=1 -C "${__BUILD_DIR__}/licenses/busybox" --wildcards '*LICENSE*' && \
    for p in [ awk basename bc cat chmod cp date diff getopt grep ip mkdir nproc printf rm sed sh test; do \
      ln "${__BUILD_DIR__}/usr/bin/busybox" "${__BUILD_DIR__}/$(${__BUILD_DIR__}/usr/bin/busybox --list-full | sed 's/$/ /' | grep -F "/${p} " | sed 's/ $//')"; \
    done ; \
  } && \
# mozilla root certificates
  echo '=== installing root certificates ===' && \
  time { \
    install --directory "${__SOURCE_DIR__}/certificates/certs" && \
    curl --silent --location --retry 3 "https://github.com/mozilla/gecko-dev/raw/master/security/nss/lib/ckfw/builtins/certdata.txt" \
      --output "${__SOURCE_DIR__}/certificates/certdata.txt" && \
    cd "${__SOURCE_DIR__}/certificates" && \
    for cert in $(sed -n -e '/^# Certificate/=' "${__SOURCE_DIR__}/certificates/certdata.txt"); do \
      awk "NR==${cert},/^CKA_TRUST_STEP_UP_APPROVED/" "${__SOURCE_DIR__}/certificates/certdata.txt" > "${__SOURCE_DIR__}/certificates/certs/${cert}.tmp"; \
    done && \
    for file in "${__SOURCE_DIR__}/certificates/certs/"*.tmp; do \
      _cert_name_=$(sed -n -e '/^# Certificate/{s/ /_/g;s/.*"\(.*\)".*/\1/p}' "${file}"); \
      printf '%b' $(awk '/^CKA_VALUE/{flag=1;next}/^END/{flag=0}flag{printf $0}' "${file}") \
        | openssl x509 -inform DER -outform PEM -out "${__SOURCE_DIR__}/certificates/certs/${_cert_name_}.pem"; \
    done && \
    install --owner="${__USER__}" --group="${__USER__}" --mode=0644 --target-directory="${__BUILD_DIR__}/etc/ssl/certs" "${__SOURCE_DIR__}/certificates/certs"/*.pem && \
    c_rehash "${__BUILD_DIR__}/etc/ssl/certs" && \
    cat "${__SOURCE_DIR__}/certificates/certs"/*.pem > "${__BUILD_DIR__}/etc/ssl/certs/ca-certificates.crt" && \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/mozilla/certificates" && \
    curl --silent --location --retry 3 "https://raw.githubusercontent.com/spdx/license-list-data/master/text/MPL-2.0.txt" \
      --output "${__BUILD_DIR__}/licenses/mozilla/certificates/MPL-2.0" && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/certificates" ; \
  } && \
# stripping
  echo '=== stripping binaries ===' && \
  time { \
    find "${__BUILD_DIR__}/usr/bin" "${__BUILD_DIR__}/usr/sbin" -type f -not -links +1 -exec strip --strip-all {} ';' ; \
  } && \
# cleanup
  echo '=== cleaning up ===' && \
  time { \
    rm -rf "${__BUILD_DIR__}/usr/lib" "${__BUILD_DIR__}/usr/include" ; \
  } && \
# licenses
  echo '=== project licenses ===' && \
  time { \
    install --owner="${__USER__}" --group="${__USER__}" --mode=0644 --target-directory="${__BUILD_DIR__}/licenses" "${__WORK_DIR__}/LICENSE" ; \
  } && \
# system settings
  echo '=== system settings ===' && \
  time { \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/run/systemd" && \
    echo 'docker' > "${__BUILD_DIR__}/run/systemd/container" ; \
  } && \
# done
  echo '=== all done! ==='



FROM scratch

ARG __BUILD_DIR__
ARG __DATA_DIR__
ARG __UNBOUND_DATA_DIR__

LABEL \
  maintainer="Frederico Martins <https://hub.docker.com/u/fscm/>" \
  vendor="fscm" \
  cmd="docker container run --detach --publish 53:53/udp fscm/unbound start" \
  params="--volume ./:${__DATA_DIR__}:rw"

EXPOSE \
  53/tcp \
  53/udp

COPY --from=build "${__BUILD_DIR__}" "/"

VOLUME ["${__DATA_DIR__}"]

WORKDIR "${__DATA_DIR__}"

ENV \
  UNBOUND_DATA_DIR="${__UNBOUND_DATA_DIR__}"

HEALTHCHECK \
  --interval=30s \
  --timeout=10s \
  --start-period=60s \
  CMD dig +short +tries=1 +time=5 @127.0.0.1 google.com || exit 99

ENTRYPOINT ["/usr/bin/entrypoint"]

CMD ["help"]
