#!/bin/sh
# {{ ansible_managed }}

set -eu

p12_temp="$(/usr/bin/mktemp -t XXXXXXXXXXXXXXXXXXXX)"
JAVAHOME="$(dirname "$(/usr/local/bin/javaPathHelper -c unifi)")"

/usr/bin/openssl pkcs12 -export -in /etc/ssl/unifi.jgoguen.ca/cert.pem \
	-inkey /etc/ssl/unifi.jgoguen.ca/privkey.pem \
	-certfile /etc/ssl/unifi.jgoguen.ca/chain.pem -out "${p12_temp}" \
	-name unifi -password pass:aircontrolenterprise

"${JAVAHOME}/keytool" -importkeystore -srckeystore "${p12_temp}" \
	-srcstoretype PKCS12 -srcstorepass aircontrolenterprise \
	-destkeystore /usr/local/share/unifi/data/keystore.new \
	-storepass aircontrolenterprise

/usr/sbin/rcctl stop unifi
/bin/mv /usr/local/share/unifi/data/keystore /usr/local/share/unifi/data/keystore.bak
/bin/mv /usr/local/share/unifi/data/keystore.new /usr/local/share/unifi/data/keystore
/usr/sbin/rcctl start unifi
