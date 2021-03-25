#!/bin/bash

set -e -u

genroot=
application=
cn="www.examos.aalto.fi"
o="examos.fi"
email="admin@examos.fi"

openssl=$(which openssl)


_usage ()
{
    echo "usage ${0} <option>"
    echo
    echo " Options:"
    echo "    -a <application>   Define application name"
    echo "    -c <rootCA file>   Generate a root CA cert&key"
    echo "    -h                 This help message"
    exit ${1}
}

while getopts 'a:c:sh' arg; do
    case "${arg}" in
    	a) application="${OPTARG}" ;;
        c) genroot="${OPTARG}" ;;
        h) _usage 0 ;;
        *)
           echo "Invalid argument '${arg}'"
           _usage 1
           ;;
    esac
done

if [ ! -z "$genroot" ] && [ ! -f "${genroot}.key" ]; then
	echo "--- Creating rootCA key and cert"
	$openssl req -newkey rsa:2048 -x509 -nodes -sha512 -days 3650 -extensions v3_ca -keyout ${genroot}.key -out ${genroot}.crt -subj "/CN=${cn}/O=${o}/OU=generate-rootCA/emailAddress=${email}"
	$openssl x509 -in ${genroot}.crt -nameopt multiline -subject -noout
	echo "Created CA certificate in ${genroot}.crt"
	chmod 400 ${genroot}.key
	chmod 444 ${genroot}.crt
fi

# If we are not generating the ${genroot}, check that it exists
if [ ! -z "$application" ]; then
	[[ ! -f "${genroot}.key" ]] && { echo "No root ca files found! Please generate with option -c first!"; exit 1; }
fi

if [ ! -z "$application" ]; then
	echo "--- Creating server key and signing request"
	$openssl genrsa -out $application.key 2048
	$openssl req -new -sha512 -out $application.csr -key $application.key -subj "/CN=${application}/O=${o}/OU=generate-cert/emailAddress=${email}"
	chmod 400 $application.key
	[[ ! -f "$application.csr" ]] && { echo ""; exit 1; }

	echo "--- Creating and signing server certificate"
	$openssl x509 -req -sha512 -in $application.csr -CA ${genroot}.crt -CAkey ${genroot}.key -CAcreateserial -CAserial "ca.srl" -out $application.crt -days 3650 -extensions JPMextensions
	chmod 444 $application.crt
fi

