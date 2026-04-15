# Healthcheck & Logs

## Healthcheck

The image defines a Docker healthcheck that hits `/fpm-ping` on the local Nginx:

```dockerfile
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping || exit 1
```

How it works:

- Nginx has a dedicated `location ~ ^/(fpm-status|fpm-ping)$` block.
- That block only allows requests from `127.0.0.1` — the rest of the world sees a `403`.
- The request is forwarded to PHP-FPM via the Unix socket `/run/php-fpm.sock`.
- PHP-FPM responds with the literal string `pong` when it's healthy.

Why both Nginx and PHP-FPM: healthy Nginx alone is not enough — you want to detect a PHP-FPM worker pool that stopped responding. Hitting `/fpm-ping` proves the FastCGI path works end-to-end.

### Checking healthcheck status

```bash
docker ps                         # look at the STATUS column
docker inspect --format='{{json .State.Health}}' <container>
```

### Using it from outside localhost

It intentionally does not work from outside. Trying `curl http://host:8080/fpm-ping` returns `403 Forbidden` — this is by design ([#20](https://github.com/erseco/alpine-php-webserver/issues/20)). If you need an external probe, expose your own public `/health` endpoint in your app that checks whatever your app considers "healthy":

```php
// /var/www/html/health.php
<?php
http_response_code(200);
header('Content-Type: text/plain');
echo "ok\n";
```

## Logs

All logs go to the container's standard streams so `docker logs` just works.

| Source          | Stream    | Notes |
|-----------------|-----------|-------|
| Nginx access    | `stdout`  | Custom `main_timed` format including `$request_time` and `$upstream_response_time`. |
| Nginx error     | `stderr`  | Level: `notice`. |
| PHP-FPM         | `stdout` / `stderr` | Worker errors and `php-fpm` messages. |
| Your PHP app    | `stdout` / `stderr` | Via `error_log = /dev/stderr` in `custom.ini`. |
| runit services  | `stderr`  | `runit` writes start/stop events and crash loops. |

### Viewing logs

```bash
docker compose logs -f web                    # follow
docker compose logs --since 10m web            # recent slice
docker compose logs web | grep " 500 "         # 500s from the access log
```

### Custom log format

The format is defined once in `nginx.conf`:

```nginx
log_format main_timed '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for" '
                      '$request_time $upstream_response_time $pipe $upstream_cache_status';
```

That's enough to debug slow responses — `$request_time` is total Nginx time, `$upstream_response_time` is PHP-FPM time. The gap between the two is how long Nginx spent buffering and sending.

### Forwarding to an aggregator

Docker log drivers already do this for you — just configure your daemon or Compose stack:

```yaml
services:
  web:
    image: erseco/alpine-php-webserver
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

Or use `syslog`, `fluentd`, `awslogs`, etc. Nothing special required on the image side.

## Access log discipline

Access logs are noisy, but **do not disable them**. They are the first thing you will need when something breaks. If volume is a concern, rotate at the Docker log driver (`json-file` with `max-size`/`max-file`) or ship them to an aggregator with its own retention.

## Tailing with timestamps

`docker logs --timestamps` adds an RFC3339 timestamp per line:

```bash
docker compose logs -f --timestamps web
```
