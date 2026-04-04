#!/bin/sh

shutdown() {
  echo "shutting down container"

  # first shutdown any service started by runit
  for _srv in $(ls -1 /etc/service); do
    sv force-stop $_srv
  done

  # shutdown runsvdir command
  kill -HUP $RUNSVDIR
  wait $RUNSVDIR

  # give processes time to stop
  sleep 0.5

  # kill any other processes still running in the container
  for _pid  in $(ps -eo pid | grep -v PID  | tr -d ' ' | grep -v '^1$' | head -n -6); do
    timeout 5 /bin/sh -c "kill $_pid && wait $_pid || kill -9 $_pid"
  done
  exit
}

# Replace ENV vars in nginx configuration files
if [ "$DISABLE_DEFAULT_LOCATION" = "true" ]; then
  sed -i '/location \/ {/,/}/ s/^/#/' /etc/nginx/nginx.conf
fi

mkdir -p /etc/nginx/conf.d
rm -f /etc/nginx/conf.d/real-ip.conf

if [ -n "${REAL_IP_FROM:-}" ]; then
  real_ip_header=$(printf '%s' "${REAL_IP_HEADER:-X-Forwarded-For}" | tr -d '\r\n')
  real_ip_recursive=$(printf '%s' "${REAL_IP_RECURSIVE:-off}" | tr -d '\r\n')

  case "$real_ip_header" in
    *[!A-Za-z0-9_-]*)
      echo >&2 "Invalid REAL_IP_HEADER value: $real_ip_header"
      exit 1
      ;;
  esac

  case "$real_ip_recursive" in
    on|off) ;;
    *)
      echo >&2 "Invalid REAL_IP_RECURSIVE value: $real_ip_recursive"
      exit 1
      ;;
  esac

  tmpfile=$(mktemp)
  has_real_ip_from="false"
  {
    printf 'real_ip_header %s;\n' "$real_ip_header"
    printf 'real_ip_recursive %s;\n' "$real_ip_recursive"

    for trusted_proxy in $(printf '%s' "$REAL_IP_FROM" | tr ',\n' '  '); do
      case "$trusted_proxy" in
        *[!A-Za-z0-9:./_-]*)
          echo >&2 "Invalid REAL_IP_FROM entry: $trusted_proxy"
          rm -f "$tmpfile"
          exit 1
          ;;
      esac

      has_real_ip_from="true"
      printf 'set_real_ip_from %s;\n' "$trusted_proxy"
    done
  } > "$tmpfile"

  if [ "$has_real_ip_from" = "true" ]; then
    mv "$tmpfile" /etc/nginx/conf.d/real-ip.conf
  else
    rm -f "$tmpfile"
  fi
fi

tmpfile=$(mktemp)
cat /etc/nginx/nginx.conf | envsubst "$(env | cut -d= -f1 | sed -e 's/^/$/')" | tee "$tmpfile" > /dev/null
mv "$tmpfile" /etc/nginx/nginx.conf

# Replace ENV vars in php configuration files
tmpfile=$(mktemp)
cat /etc/php84/conf.d/custom.ini.tpl | envsubst "$(env | cut -d= -f1 | sed -e 's/^/$/')" | tee "$tmpfile" > /dev/null
mv "$tmpfile" /etc/php84/conf.d/custom.ini

tmpfile=$(mktemp)
cat /etc/php84/php-fpm.d/www.conf | envsubst "$(env | cut -d= -f1 | sed -e 's/^/$/')" | tee "$tmpfile" > /dev/null
mv "$tmpfile" /etc/php84/php-fpm.d/www.conf

echo "Starting startup scripts in /docker-entrypoint-init.d ..."
for script in $(find /docker-entrypoint-init.d/ -executable -type f | sort); do

    echo >&2 "*** Running: $script"
    $script
    retval=$?
    if [ $retval != 0 ];
    then
        echo >&2 "*** Failed with return value: $?"
        exit $retval
    fi

done
echo "Finished startup scripts in /docker-entrypoint-init.d"

echo "Starting runit..."
exec runsvdir -P /etc/service &

RUNSVDIR=$!
echo "Started runsvdir, PID is $RUNSVDIR"
echo "wait for processes to start...."

sleep 5
for _srv in $(ls -1 /etc/service); do
    sv status $_srv
done

# If there are additional arguments, execute them
if [ $# -gt 0 ]; then
    exec "$@"
fi

# catch shutdown signals
trap shutdown SIGTERM SIGHUP SIGQUIT SIGINT
wait $RUNSVDIR

shutdown
