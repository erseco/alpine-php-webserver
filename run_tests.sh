#!/usr/bin/env sh
set -eu

apk --no-cache add curl >/dev/null

app_url="${APP_URL:-http://app:8080}"

echo "Waiting for ${app_url} ..."
attempt=1
while [ "$attempt" -le 30 ]; do
  if curl --silent --show-error --fail "${app_url}/" > /tmp/index.html; then
    break
  fi

  attempt=$((attempt + 1))
  sleep 1
done

if [ ! -s /tmp/index.html ]; then
  echo "Application did not become ready at ${app_url}" >&2
  exit 1
fi

echo "Checking PHP response ..."
grep -Eq 'PHP Version 8\.4|PHP 8\.4' /tmp/index.html

echo "Checking static file delivery ..."
curl --silent --show-error --fail "${app_url}/test.html" \
  | grep -F 'This static HTML file is served by Nginx'

echo "Checking direct PHP execution ..."
curl --silent --show-error --fail "${app_url}/index.php" \
  | grep -Eq 'PHP Version 8\.4|PHP 8\.4'
