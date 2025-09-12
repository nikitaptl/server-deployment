#!/bin/bash
set -e

echo "Проверка подписи сертификатов CA"
openssl verify -CAfile ca.crt server.crt
openssl verify -CAfile ca.crt client.crt

echo
echo "Проверка SAN у сервера"
openssl x509 -in server.crt -noout -text | grep -A1 "Subject Alternative Name"

echo
echo "Проверка назначения сертификатов"
openssl verify -purpose sslserver -CAfile ca.crt server.crt
openssl verify -purpose sslclient -CAfile ca.crt client.crt
