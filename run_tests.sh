#!/usr/bin/env sh
set -eu

apk --no-cache add curl >/dev/null

app_url="${APP_URL:-http://app:8080}"
index_response="$(mktemp)"
php_version_pattern='PHP (Version )?8\.4'

expect_status() {
  path="$1"
  expected_status="$2"
  response_status="$(
    curl --silent --show-error --output /dev/null --write-out '%{http_code}' "${app_url}${path}"
  )"

  if [ "${response_status}" != "${expected_status}" ]; then
    echo "Expected ${path} to return HTTP ${expected_status}, got ${response_status}" >&2
    exit 1
  fi
}

cleanup() {
  rm -f "${index_response}"
}

trap cleanup EXIT

echo "Waiting for ${app_url} ..."
attempt=1
while [ "$attempt" -le 30 ]; do
  if curl --silent --show-error --fail "${app_url}/" > "${index_response}"; then
    break
  fi

  attempt=$((attempt + 1))
  sleep 1
done

if [ ! -s "${index_response}" ]; then
  echo "Application did not become ready at ${app_url}" >&2
  exit 1
fi

echo "Checking PHP response ..."
grep -Eq "${php_version_pattern}" "${index_response}"

echo "Checking static file delivery ..."
curl --silent --show-error --fail "${app_url}/test.html" \
  | grep -F 'This static HTML file is served by Nginx'

echo "Checking direct PHP execution ..."
curl --silent --show-error --fail "${app_url}/index.php" \
  | grep -Eq "${php_version_pattern}"

echo "Checking PHP response headers ..."
curl --silent --show-error --fail --head "${app_url}/index.php" \
  | grep -Ei '^content-type: text/html'

echo "Checking protected dotfiles are denied ..."
expect_status '/.git/config' '403'

echo "Checking PHP-FPM ping is not exposed externally ..."
expect_status '/fpm-ping' '403'
