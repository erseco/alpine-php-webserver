#!/usr/bin/env sh
set -eu

apk --no-cache add curl
curl --silent --fail http://app:8080 | grep 'PHP 8.4'

default_response=$(curl --silent --fail -H 'X-Forwarded-For: 198.51.100.24, 172.16.0.9' http://app:8080/real-ip.php)
! echo "$default_response" | grep -q '"remote_addr":"198.51.100.24"'
echo "$default_response" | grep '"server_port":"8080"'

forwarded_port_response=$(curl --silent --fail -H 'X-Forwarded-Port: 6443' http://app:8080/real-ip.php)
echo "$forwarded_port_response" | grep '"server_port":"6443"'

invalid_forwarded_port_response=$(curl --silent --fail -H 'X-Forwarded-Port: invalid' http://app:8080/real-ip.php)
echo "$invalid_forwarded_port_response" | grep '"server_port":"8080"'

real_ip_response=$(curl --silent --fail -H 'X-Forwarded-For: 198.51.100.24, 172.16.0.9' http://realip:8080/real-ip.php)
echo "$real_ip_response" | grep '"remote_addr":"198.51.100.24"'
echo "$real_ip_response" | grep '"forwarded_for":"198.51.100.24, 172.16.0.9"'
