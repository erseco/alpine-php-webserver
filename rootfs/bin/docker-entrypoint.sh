#!/bin/sh

shutdown() {
  echo "shutting down container"

  # first shutdown any service started by runit
  for _service_dir in /etc/service/*; do
    [ -d "$_service_dir" ] || continue
    sv force-stop "$(basename "$_service_dir")"
  done

  # shutdown runsvdir command
  kill -HUP $RUNSVDIR
  wait $RUNSVDIR

  # give processes time to stop
  sleep 0.5

  # kill any other processes still running in the container
  for _pid in $(ps -eo pid= | awk '$1 != 1 { print $1 }' | head -n -6); do
    timeout 5 /bin/sh -c "kill $_pid && wait $_pid || kill -9 $_pid"
  done
  exit
}

# Replace ENV vars in nginx configuration files
if [ "$DISABLE_DEFAULT_LOCATION" = "true" ]; then
  sed -i '/location \/ {/,/}/ s/^/#/' /etc/nginx/nginx.conf
fi

tmpfile=$(mktemp)
envsubst "$(env | cut -d= -f1 | sed -e 's/^/$/')" < /etc/nginx/nginx.conf | tee "$tmpfile" > /dev/null
mv "$tmpfile" /etc/nginx/nginx.conf

# Replace ENV vars in php configuration files
tmpfile=$(mktemp)
envsubst "$(env | cut -d= -f1 | sed -e 's/^/$/')" < /etc/php84/conf.d/custom.ini.tpl | tee "$tmpfile" > /dev/null
mv "$tmpfile" /etc/php84/conf.d/custom.ini

tmpfile=$(mktemp)
envsubst "$(env | cut -d= -f1 | sed -e 's/^/$/')" < /etc/php84/php-fpm.d/www.conf | tee "$tmpfile" > /dev/null
mv "$tmpfile" /etc/php84/php-fpm.d/www.conf

echo "Starting startup scripts in /docker-entrypoint-init.d ..."
for script in $(find /docker-entrypoint-init.d/ -executable -type f | sort); do

    echo >&2 "*** Running: $script"
    $script
    retval=$?
    if [ $retval != 0 ];
    then
        echo >&2 "*** Failed with return value: $retval"
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
for _service_dir in /etc/service/*; do
    [ -d "$_service_dir" ] || continue
    sv status "$(basename "$_service_dir")"
done

# If there are additional arguments, execute them
if [ $# -gt 0 ]; then
    exec "$@"
fi

# catch shutdown signals
trap shutdown TERM HUP QUIT INT
wait $RUNSVDIR

shutdown
