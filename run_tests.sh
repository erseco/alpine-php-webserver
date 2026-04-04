#!/usr/bin/env sh
set -eu

apk --no-cache add curl
curl --silent --fail http://app:8080 | grep 'PHP 8.4'

default_response=$(curl --silent --fail -H 'X-Forwarded-For: 198.51.100.24, 172.16.0.9' http://app:8080/real-ip.php)
! echo "$default_response" | grep -q '"remote_addr":"198.51.100.24"'

real_ip_response=$(curl --silent --fail -H 'X-Forwarded-For: 198.51.100.24, 172.16.0.9' http://realip:8080/real-ip.php)
echo "$real_ip_response" | grep '"remote_addr":"198.51.100.24"'
echo "$real_ip_response" | grep '"forwarded_for":"198.51.100.24, 172.16.0.9"'
