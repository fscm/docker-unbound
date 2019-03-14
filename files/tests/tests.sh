#!/bin/bash
#
# Shell script to test the Unbound Docker image.
#
# Copyright 2016-2019, Frederico Martins
#   Author: Frederico Martins <http://github.com/fscm>
#
# SPDX-License-Identifier: MIT
#
# This program is free software. You can use it and/or modify it under the
# terms of the MIT License.
#

BASEDIR=$(dirname $0)

# Variables
UNBOUND_PORT=5300
UNBOUND_TEST_NAME="google.com"
UNBOUND_TEST_DNSSEC_OK="sigok.verteiltesysteme.net"
UNBOUND_TEST_DNSSEC_FAIL="sigfail.verteiltesysteme.net"

__UNBOUND_DATA__="/data/unbound"

# Configuration files
UNBOUND_CONF="${__UNBOUND_DATA__}/unbound.conf"

/bin/echo "=== Docker Build Test ==="

# Create temporary dir (if needed)
if ! [[ -d /tmp ]]; then
  mkdir -m 1777 /tmp
fi

/bin/echo -n "[TEST] Configuring the Unbound server... "
run -p ${UNBOUND_PORT} init &>/dev/null
if [[ "$?" -eq "0" ]]; then
  /bin/echo 'OK'
else
  /bin/echo 'Failed'
  exit 1
fi

/bin/echo -n "[TEST] Starting Unbound server... "
if [[ -f "${UNBOUND_CONF}" ]]; then
  /sbin/unbound -d -p -c "${UNBOUND_CONF}" &>/dev/null &
  if [[ "$?" -eq "0" ]]; then
    /bin/echo 'OK'
  else
    /bin/echo 'Failed'
    exit 4
  fi
else
  /bin/echo 'Failed'
  exit 3
fi

for interface in $(ip -o addr show | awk '{split($4,ip_addr,"/"); print ip_addr[1]}'); do
  /bin/echo -n "[TEST] Running simple query test (${interface})... "
  answer=(dig +short +tries=1 +time=5 -p ${UNBOUND_PORT} @${interface} ${UNBOUND_TEST_NAME})
  if ! [[ -z "${answer}" ]]; then
    /bin/echo 'OK'
  else
    /bin/echo 'Failed'
    exit 5
  fi
done

/bin/echo -n "[TEST] Running DNSSEC query (test OK)... "
dig +short +dnssec +tries=1 +time=5 -p ${UNBOUND_PORT} @127.0.0.1 ${UNBOUND_TEST_DNSSEC_OK} | grep -q "^A "
if [[ "$?" -eq "0" ]]; then
  /bin/echo 'OK'
else
  /bin/echo 'Failed'
  exit 6
fi

/bin/echo -n "[TEST] Running DNSSEC query (test FAIL)... "
dig +dnssec +tries=1 +time=5 -p ${UNBOUND_PORT} @127.0.0.1 ${UNBOUND_TEST_DNSSEC_FAIL} | grep -q "SERVFAIL"
if [[ "$?" -eq "0" ]]; then
  /bin/echo 'OK'
else
  /bin/echo 'Failed'
  exit 7
fi

/bin/echo -n "[TEST] Stoping Unbound server... "
unbound-control stop &>/dev/null
if [[ "$?" -eq "0" ]]; then
  /bin/echo 'OK'
else
  /bin/echo 'Failed'
  exit 8
fi

exit 0
