#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

set -e -u

rootCAfile="ca"
keydir="keys"
servername=""
cn="www.examos.aalto.fi"
o="examos.aalto.fi"
email="admin@examos.fi"

openssl=$(which openssl)


_usage ()
{
    echo "usage ${0} <option>"
    echo
    echo " Options:"
    echo "    -c <rootCA file>       Define a root CA cert&key name. If they don't exist, generates."
    echo "    -d <keyfile directory> The directory where keys are stored. The rootCA file" 
    echo "                           should also be found from here! Default: 'keys'"
    echo "    -h                     This help message"
    exit ${1}
}

while getopts 'a:c:d:s:sh' arg; do
    case "${arg}" in
      a) application="${OPTARG}" ;;
      c) rootCAfile="${OPTARG}" ;;
      d) keydir="${OPTARG}" ;;
      s) servername="${OPTARG}" ;;
      h) _usage 0 ;;
      *)
         echo "Invalid argument '${arg}'"
         _usage 1
         ;;
    esac
done

if [ -z "${rootCAfile}" ]; then
  echo "Root CA file not defined! Please define a rootCA file!"
  usage 1
fi

if [ ! -d "${DIR}/${keydir}" ]; then
  echo "--- Key directory ${DIR}/${keydir} not found - creating ..."
  mkdir -p ${DIR}/${keydir}/{server,client}
fi

if [ ! -f "${DIR}/${keydir}/${rootCAfile}.key" ]; then
  echo "--- Creating rootCA key and cert for key '${rootCAfile}' ..."
  $openssl req -newkey rsa:2048 -x509 -nodes -sha512 -days 3650 -extensions v3_ca -keyout ${DIR}/${keydir}/${rootCAfile}.key -out ${DIR}/${keydir}/${rootCAfile}.crt -subj "/CN=${cn}/O=${o}/OU=generate-rootCA/emailAddress=${email}"
  $openssl x509 -in ${DIR}/${keydir}/${rootCAfile}.crt -nameopt multiline -subject -noout
  echo "Generated CA certificate and key for ${DIR}/${keydir}/${rootCAfile}!"
  chmod 400 ${DIR}/${keydir}/${rootCAfile}.key
  chmod 444 ${DIR}/${keydir}/${rootCAfile}.crt
fi


echo "--- Creating server and application keys!"
for app in 'server' 'client'; do
  $openssl genrsa -out ${DIR}/${keydir}/${app}/${app}.key 2048
  if [[ ! -z $servername && $app == "server" ]]; then
    $openssl req -new -sha512 -out ${DIR}/${keydir}/${app}/${app}.csr -key ${DIR}/${keydir}/${app}/${app}.key -subj "/CN=${servername}/O=${o}/OU=generate-cert/emailAddress=${email}"
  else
    $openssl req -new -sha512 -out ${DIR}/${keydir}/${app}/${app}.csr -key ${DIR}/${keydir}/${app}/${app}.key -subj "/CN=${app}/O=${o}/OU=generate-cert/emailAddress=${email}"
  fi
  chmod 400 ${DIR}/${keydir}/${app}/${app}.key
  [[ ! -f "${DIR}/${keydir}/${app}/${app}.csr" ]] && { echo "Failed creating cert for ${app}!"; exit 1; }
  $openssl x509 -req -sha512 -in ${DIR}/${keydir}/${app}/${app}.csr -CA ${DIR}/${keydir}/${rootCAfile}.crt -CAkey ${DIR}/${keydir}/${rootCAfile}.key -CAcreateserial -CAserial "${DIR}/${keydir}/ca.srl" -out ${DIR}/${keydir}/${app}/${app}.crt -days 3650 #-extensions JPMextensions
  chmod 444 ${DIR}/${keydir}/${app}/${app}.crt
  cp ${DIR}/${keydir}/${rootCAfile}.crt ${DIR}/${keydir}/${app}/${rootCAfile}.crt
done

