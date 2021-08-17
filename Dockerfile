# global args
ARG __BUILD_DIR__="/build"
ARG __DATA_DIR__="/data"



FROM fscm/centos:stream as build

ARG __BUILD_DIR__
ARG __DATA_DIR__
ARG UNBOUND_VERSION="1.13.2"
ARG __USER__="root"
ARG __WORK_DIR__="/work"
ARG __SOURCE_DIR__="${__WORK_DIR__}/src"

ENV \
  LANG="C.UTF-8" \
  LC_ALL="C.UTF-8"

USER "${__USER__}"

COPY "LICENSE" "files/" "${__WORK_DIR__}"/
COPY --from=busybox:uclibc "/bin/busybox" "${__WORK_DIR__}"/

WORKDIR "${__WORK_DIR__}"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN \
# build env
  echo '--> setting build env' && \
  set +h && \
  export __NPROC__="$(getconf _NPROCESSORS_ONLN || echo 1)" && \
  export DCACHE_LINESIZE="$(getconf LEVEL1_DCACHE_LINESIZE || echo 64)" && \
  export MAKEFLAGS="--silent --no-print-directory --jobs ${__NPROC__}" && \
  export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig && \
# build structure
  echo '--> creating build structure' && \
  for folder in 'bin' 'sbin'; do \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/usr/${folder}"; \
    ln --symbolic "usr/${folder}" "${__BUILD_DIR__}/${folder}"; \
  done && \
  for folder in '/tmp' "${__DATA_DIR__}"; do \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=1777 "${__BUILD_DIR__}${folder}"; \
  done && \
# dependencies
  echo '--> instaling dependencies' && \
  dnf --assumeyes --quiet --setopt=install_weak_deps='no' install \
    autoconf \
    automake \
    binutils \
    byacc \
    ca-certificates \
    curl \
    diffutils \
    file \
    findutils \
    flex \
    gcc \
    gzip \
    jq \
    libtool \
    make \
    perl-interpreter \
    rsync \
    sed \
    tar \
    xz && \
# copy tests
  echo '--> copying test files' && \
  install --owner="${__USER__}" --group="${__USER__}" --mode=0755 --target-directory="${__BUILD_DIR__}/usr/bin" "${__WORK_DIR__}/tests"/* && \
# copy scripts
  echo '--> copying scripts' && \
  install --owner="${__USER__}" --group="${__USER__}" --mode=0755 --target-directory="${__BUILD_DIR__}/usr/bin" "${__WORK_DIR__}/scripts"/* && \
# kernel headers
  echo '--> installing kernel headers' && \
  KERNEL_VERSION="$(curl --silent --location --retry 3 'https://www.kernel.org/releases.json' | jq -r '.latest_stable.version')" && \
  install --directory "${__SOURCE_DIR__}/kernel" && \
  curl --silent --location --retry 3 "https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_VERSION%%.*}.x/linux-${KERNEL_VERSION}.tar.xz" \
    | tar xJ --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/kernel" $(echo linux-*/{Makefile,arch,include,scripts,tools,usr}) && \
  cd "${__SOURCE_DIR__}/kernel" && \
  make INSTALL_HDR_PATH="/usr/local" headers_install > /dev/null && \
  cd ~- && \
  rm -rf "${__SOURCE_DIR__}/kernel" && \
# musl
  echo '--> installing musl libc' && \
  install --directory "${__SOURCE_DIR__}/musl/_build" && \
  curl --silent --location --retry 3 "https://musl.libc.org/releases/musl-latest.tar.gz" \
    | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/musl" && \
  cd "${__SOURCE_DIR__}/musl/_build" && \
  ../configure \
    CFLAGS="-O2 -g0 -s -w -pipe -mtune=generic -DNDEBUG -DCLS=${DCACHE_LINESIZE}" \
    --prefix='/usr/local' \
    --disable-debug \
    --disable-shared \
    --enable-wrapper=all \
    --enable-static \
    > /dev/null && \
  make > /dev/null > /dev/null && \
  make install > /dev/null && \
  cd ~- && \
  rm -rf "${__SOURCE_DIR__}/musl" && \
# zlib
  echo '--> installing zlib' && \
  ZLIB_VERSION="$(rpm -q --qf "%{VERSION}" zlib)" && \
  install --directory "${__SOURCE_DIR__}/zlib/_build" && \
  curl --silent --location --retry 3 "https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz" \
    | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/zlib" && \
  cd "${__SOURCE_DIR__}/zlib/_build" && \
  sed -i.orig -e '/(man3dir)/d' ../Makefile.in && \
  CC="musl-gcc -static --static" \
  CFLAGS="-O2 -g0 -s -w -pipe -mtune=generic -DNDEBUG -DCLS=${DCACHE_LINESIZE}" \
  ../configure \
    --prefix='/usr/local' \
    --includedir='/usr/local/include' \
    --libdir='/usr/local/lib' \
    --static \
    > /dev/null && \
  make > /dev/null && \
  make install > /dev/null && \
  cd ~- && \
  rm -rf "${__SOURCE_DIR__}/zlib" && \
# openssl
  echo '--> installing openssl' && \
  OPENSSL_VERSION="$(rpm -q --qf "%{VERSION}" openssl-libs)" && \
  install --directory "${__SOURCE_DIR__}/openssl/_build" && \
  curl --silent --location --retry 3 "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" \
    | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/openssl" && \
  cd "${__SOURCE_DIR__}/openssl/_build" && \
  ../config \
    CC="musl-gcc -static --static" \
    --openssldir='/etc/ssl' \
    --prefix='/usr/local' \
    --libdir='/usr/local/lib' \
    --release \
    --static \
    enable-cms \
    enable-ec_nistp_64_gcc_128 \
    enable-rfc3779 \
    no-comp \
    no-shared \
    no-ssl3 \
    no-weak-ssl-ciphers \
    zlib \
    -pipe \
    -static \
    -DCLS=${DCACHE_LINESIZE} \
    -DNDEBUG \
    -DOPENSSL_NO_HEARTBEATS \
    -O2 -g0 -s -w -pipe -m64 -mtune=generic '-DDEVRANDOM="\"/dev/urandom\""' && \
  make > /dev/null && \
  make install_sw > /dev/null && \
  make install_ssldirs > /dev/null && \
  sed -i.orig -e '/^install_programs:/ s/install_runtime_libs//' Makefile && \
  make DESTDIR="${__BUILD_DIR__}" BIN_SCRIPTS="" INSTALLTOP="/usr" install_programs > /dev/null && \
  make DESTDIR="${__BUILD_DIR__}" MISC_SCRIPTS="" install_ssldirs > /dev/null && \
  find "${__BUILD_DIR__}/etc/ssl" -type f -name '*.dist' -delete && \
  install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/openssl" && \
  install --owner="${__USER__}" --group="${__USER__}" --mode=0644 --target-directory="${__BUILD_DIR__}/licenses/openssl" '../LICENSE' && \
  cd ~- && \
  rm -rf "${__SOURCE_DIR__}/openssl" && \
# libexpat
  echo '--> installing libexpat' && \
  LIBEXPAT_URL="$(curl --silent --location --retry 3 'https://api.github.com/repos/libexpat/libexpat/releases/latest' | jq -r '.assets[] | select(.content_type=="application/gzip") | .browser_download_url')" && \
  install --directory "${__SOURCE_DIR__}/libexpat/_build" && \
  curl --silent --location --retry 3 "${LIBEXPAT_URL}" \
    | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/libexpat" && \
  cd "${__SOURCE_DIR__}/libexpat/_build" && \
  for file in $(find ../ -name 'Makefile.in'); do \
    sed -i.orig \
    -e '/^install-data-hook:/ s/:.*/:/' -e '/^install-data-hook:/,/^$/{//!d}' \
    -e '/^doc_DATA =/ s/=.*/=/' -e '/^doc_DATA =/,/^$/{//!d}' "${file}"; \
  done && \
  ../configure \
    CC="musl-gcc -static --static" \
    CFLAGS="-O2 -g0 -s -w -pipe -mtune=generic -DNDEBUG -DCLS=${DCACHE_LINESIZE}" \
    --quiet \
    --prefix='/usr/local' \
    --includedir='/usr/local/include' \
    --libdir='/usr/local/lib' \
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
  make install > /dev/null && \
  cd ~- && \
  rm -rf "${__SOURCE_DIR__}/libexpat" ; \
# libevent
  echo '--> installing libevent' && \
  LIBEVENT_URL="$(curl --silent --location --retry 3 'https://api.github.com/repos/libevent/libevent/releases/latest' | jq -r '.assets[] | select(.content_type=="application/gzip") | .browser_download_url')" && \
  install --directory "${__SOURCE_DIR__}/libevent/_build" && \
  curl --silent --location --retry 3 "${LIBEVENT_URL}" \
    | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/libevent" && \
  cd "${__SOURCE_DIR__}/libevent/_build" && \
  ../configure \
    CC="musl-gcc -static --static" \
    CFLAGS="-O2 -g0 -s -w -pipe -mtune=generic -DNDEBUG -DCLS=${DCACHE_LINESIZE}" \
    --quiet \
    --prefix='/usr/local' \
    --includedir='/usr/local/include' \
    --libdir='/usr/local/lib' \
    --sysconfdir='/etc' \
    --enable-fast-install \
    --enable-silent-rules \
    --enable-static \
    --disable-debug-mode \
    --disable-doxygen-html \
    --disable-samples \
    --disable-shared && \
  make > /dev/null && \
  make install > /dev/null && \
  cd ~- && \
  rm -rf "${__SOURCE_DIR__}/libevent" && \
# libuv
  echo '--> installing libuv' && \
  LIBUV_URL="$(curl --silent --location --retry 3 'https://api.github.com/repos/libuv/libuv/releases/latest' | jq -r '.tarball_url')" && \
  install --directory "${__SOURCE_DIR__}/libuv/_build" && \
  curl --silent --location --retry 3 "${LIBUV_URL}" \
    | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/libuv" && \
  cd "${__SOURCE_DIR__}/libuv/_build" && \
  ../autogen.sh && \
  ../configure \
    CC="musl-gcc -static --static" \
    CFLAGS="-O2 -g0 -s -w -pipe -mtune=generic -DNDEBUG -DCLS=${DCACHE_LINESIZE}" \
    --quiet \
    --prefix='/usr/local' \
    --includedir='/usr/local/include' \
    --libdir='/usr/local/lib' \
    --libexecdir='/usr/local/libexec' \
    --sysconfdir='/etc' \
    --enable-fast-install \
    --enable-silent-rules \
    --enable-static \
    --disable-shared && \
  make > /dev/null && \
  make install > /dev/null && \
  cd ~- && \
  rm -rf "${__SOURCE_DIR__}/libuv" && \
# bind utilities
  echo '--> installing bind utilities' && \
  BIND_VERSION="9.16.19" && \
  install --directory "${__SOURCE_DIR__}/bind/_build" && \
  curl --silent --location --retry 3 "https://downloads.isc.org/isc/bind${BIND_VERSION%%.*}/${BIND_VERSION}/bind-${BIND_VERSION}.tar.xz" \
    | tar xJ --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/bind" && \
  cd "${__SOURCE_DIR__}/bind/_build" && \
  ../configure \
    CC="musl-gcc -static --static" \
    CFLAGS="-O2 -g0 -s -w -pipe -mtune=generic -DNDEBUG -DCLS=${DCACHE_LINESIZE}" \
    --quiet \
    --prefix='/usr' \
    --localstatedir='/tmp' \
    --sysconfdir='/etc' \
    --with-zlib \
    --without-cmocka \
    --without-python \
    --enable-developer \
    --enable-mutex-atomics \
    --enable-static \
    --disable-linux-caps \
    --disable-shared && \
  for target in ./lib/{isc,dns,isccfg,irs,ns,bind${BIND_VERSION%%.*}} ./bin/dig; do \
    make --directory="${target}" > /dev/null; \
  done && \
  make --directory='bin/dig' DESTDIR="${__BUILD_DIR__}" MANPAGES="" install > /dev/null && \
  install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/bind" && \
  install --owner="${__USER__}" --group="${__USER__}" --mode=0644 --target-directory="${__BUILD_DIR__}/licenses/bind" '../LICENSE' && \
  cd ~- && \
  rm -rf "${__SOURCE_DIR__}/bind" && \
# unbound
  echo '--> installing unbound' && \
  install --directory "${__SOURCE_DIR__}/unbound/_build" && \
  curl --silent --location --retry 3 "https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz" \
    | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/unbound" && \
  cd "${__SOURCE_DIR__}/unbound/_build" && \
  for file in $(find ../ -name 'Makefile.in'); do \
    sed -i.orig \
      -e '/for mpage in/,/done/d' \
      -e '/INSTALL.*-[cd].*mandir/d' \
      -e '/INSTALL.*DESTDIR.*pkgconfig/d' \
      -e '/^install-all/s/:.*/:\tall/' "${file}"; \
  done && \
  ../configure \
    CC="musl-gcc -static --static" \
    CFLAGS="-O2 -g0 -s -w -pipe -mtune=generic -DNDEBUG -DCLS=${DCACHE_LINESIZE}" \
    --quiet \
    --prefix='/usr' \
    --libdir='/usr/lib' \
    --libexecdir='/usr/libexec' \
    --sysconfdir="${__DATA_DIR__}" \
    --with-chroot-dir="" \
    --with-pidfile="/tmp/unbound.pid" \
    --with-pthreads \
    --with-rootkey-file="${__DATA_DIR__}/unbound/root.key" \
    #--with-run-dir="" \
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
  _config_file_="/etc$(cat Makefile | sed -n -e "/^configfile=/ s|.*=${__DATA_DIR__}\(.*\)|\1|p")" && \
  make > /dev/null && \
  make DESTDIR="${__BUILD_DIR__}" configfile="${_config_file_}" install > /dev/null && \
  install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/unbound" && \
  install --owner="${__USER__}" --group="${__USER__}" --mode=0644 --target-directory="${__BUILD_DIR__}/licenses/unbound" '../LICENSE' && \
  cd ~- && \
  rm -rf "${__SOURCE_DIR__}/unbound" && \
# busybox
  echo '--> installing busybox' && \
  install --owner="${__USER__}" --group="${__USER__}" --mode=0755 --target-directory="${__BUILD_DIR__}/usr/bin" "${__WORK_DIR__}/busybox" && \
  install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/busybox" && \
  curl --silent --location --retry 3 "https://git.busybox.net/busybox/plain/LICENSE" --output "${__BUILD_DIR__}/licenses/busybox/LICENSE" && \
  for p in [ awk basename bc cat chmod cp date diff getopt grep ip mkdir nproc printf rm sed sh test; do \
    p_path="$(${__WORK_DIR__}/busybox --list-full | sed 's/$/ /' | grep -F "/${p} "  | sed -e '/^usr/! s|^|usr/|' -e 's/ $//')"; \
    ln "${__BUILD_DIR__}/usr/bin/busybox" "${__BUILD_DIR__}/${p_path}"; \
  done && \
# mozilla root certificates
  echo '--> installing root certificates' && \
  install --directory "${__SOURCE_DIR__}/certificates/certs" && \
  curl --silent --location --retry 3 "https://github.com/mozilla/gecko-dev/raw/master/security/nss/lib/ckfw/builtins/certdata.txt" \
    --output "${__SOURCE_DIR__}/certificates/certdata.txt" && \
  cd "${__SOURCE_DIR__}/certificates" && \
  for cert in $(sed -n -e '/^# Certificate/=' "${__SOURCE_DIR__}/certificates/certdata.txt"); do \
    awk "NR==${cert},/^CKA_TRUST_STEP_UP_APPROVED/" "${__SOURCE_DIR__}/certificates/certdata.txt" > "${__SOURCE_DIR__}/certificates/certs/${cert}.tmp"; \
  done && \
  for file in "${__SOURCE_DIR__}/certificates/certs/"*.tmp; do \
    _cert_name_=$(sed -n -e '/^# Certificate/{s/.*"\(.*\)".*/\1/p}' "${file}"); \
    _cert_file_=${_cert_name_// /_}; \
    echo "# ${_cert_name_}" >> "${__SOURCE_DIR__}/certificates/certs/ca-bundle.crt" && \
    printf $(awk '/^CKA_VALUE/{flag=1;next}/^END/{flag=0}flag{printf $0}' "${file}") \
      | openssl x509 -inform DER -outform PEM \
      | tee -a "${__SOURCE_DIR__}/certificates/ca-bundle.crt" \
      > "${__SOURCE_DIR__}/certificates/certs/${_cert_file_}.crt"; \
  done && \
  install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/etc/ssl/certs" && \
  install --owner="${__USER__}" --group="${__USER__}" --mode=0644 --target-directory="${__BUILD_DIR__}/etc/ssl/certs" "${__SOURCE_DIR__}/certificates/certs"/*.crt && \
  c_rehash "${__BUILD_DIR__}/etc/ssl/certs" && \
  install --owner="${__USER__}" --group="${__USER__}" --mode=0644 --target-directory="${__BUILD_DIR__}/etc/ssl/certs" "${__SOURCE_DIR__}/certificates/ca-bundle.crt" && \
  install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/mozilla/certificates" && \
  curl --silent --location --retry 3 "https://raw.githubusercontent.com/spdx/license-list-data/master/text/MPL-2.0.txt" \
    --output "${__BUILD_DIR__}/licenses/mozilla/certificates/MPL-2.0" && \
  cd ~- && \
  rm -rf "${__SOURCE_DIR__}/certificates" && \
# stripping
#   echo '--> stripping binaries' && \
#   find "${__BUILD_DIR__}"/usr/{,s}bin -type f -not -links +1 -exec strip --strip-all {} ';' && \
#   strip --strip-all "${__BUILD_DIR__}"/usr/bin/busybox && \
# cleanup
#   echo '=== cleaning up ===' && \
#   time { \
#     rm -rf "${__BUILD_DIR__}/usr/lib" "${__BUILD_DIR__}/usr/include" ; \
#   } && \
# licenses
  echo '--> project licenses' && \
  install --owner="${__USER__}" --group="${__USER__}" --mode=0644 --target-directory="${__BUILD_DIR__}/licenses" "${__WORK_DIR__}/LICENSE" && \
# done
  echo '--> all done!'



FROM scratch

ARG __BUILD_DIR__
ARG __DATA_DIR__

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
  DATA_DIR="${__DATA_DIR__}"

HEALTHCHECK \
  --interval=30s \
  --timeout=10s \
  --start-period=60s \
  CMD dig +short +tries=1 +time=5 @127.0.0.1 google.com || exit 99

ENTRYPOINT ["/usr/bin/entrypoint"]

CMD ["help"]
