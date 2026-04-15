# Extending the Image

The image is built to be extended. Three patterns cover most needs: **extra daemons**, **startup scripts**, and **running commands as root**.

## Adding extra daemons via `runit`

The runtime is managed by [runit](http://smarden.org/runit/). Each daemon has its own directory under `/etc/service/<name>/` containing an executable `run` script. `runit` keeps them alive and restarts them if they crash.

Example: a memcached sidecar.

Create `memcached.sh`:

```sh
#!/bin/sh
exec 2>&1 chpst -u memcache /usr/bin/memcached
```

Then in your `Dockerfile`:

```dockerfile
FROM erseco/alpine-php-webserver:latest

USER root
RUN apk add --no-cache memcached \
 && mkdir -p /etc/service/memcached
COPY memcached.sh /etc/service/memcached/run
RUN chmod +x /etc/service/memcached/run

USER nobody
```

Important rules:

- The daemon **must run in the foreground**. Don't fork, don't double-fork, don't write a PID file. Use the flag your daemon provides (`-F`, `-f`, `--no-daemonize`).
- Exec the final command (`exec` in the shell script) so signals propagate correctly.
- Redirect stderr to stdout (`exec 2>&1 ...`) so both streams reach `docker logs`.
- Use `chpst -u <user>` to drop privileges if the daemon doesn't do it itself.

!!! info
    The image's own `nginx` and `php` services are defined exactly the same way under `rootfs/etc/service/nginx/run` and `rootfs/etc/service/php/run`. Read them as templates.

## Startup scripts (`/docker-entrypoint-init.d/`)

Drop executable scripts into `/docker-entrypoint-init.d/` and they run in **lexicographic order** on every container start, right before `runit` takes over. The booting fails if any script exits non-zero.

```sh
#!/bin/sh
# logtime.sh
date > /tmp/boottime.txt
```

```dockerfile
COPY logtime.sh /docker-entrypoint-init.d/10-logtime.sh
RUN chmod +x /docker-entrypoint-init.d/10-logtime.sh
```

Typical use cases:

- Waiting for a database container (`nc -z db 5432`).
- Warming caches.
- Expanding env-var templates into config files not already covered by `envsubst`.
- Running `composer dump-autoload` after mounting code.

Naming convention: prefix with a two-digit number (`10-`, `20-`, `90-`) to control order.

## Running commands as root

The container runs as `nobody`. Sometimes you need root to install packages, inspect file ownership, or debug something. Use `--user root` on `docker compose exec`:

```bash
docker compose exec --user root web sh
```

Examples:

```bash
# Install a debugging tool
docker compose exec --user root web sh -c "apk add --no-cache nano curl htop"

# Look at who owns the mounted volume
docker compose exec --user root web ls -la /var/www/html

# Run a one-off PHP tool as root
docker compose exec --user root web php -r 'echo PHP_VERSION, PHP_EOL;'
```

## Adding PHP extensions

Packaged in Alpine? One line:

```dockerfile
FROM erseco/alpine-php-webserver:latest

USER root
RUN apk add --no-cache php84-ldap php84-pecl-redis php84-pecl-mongodb
USER nobody
```

Not packaged? Build from PECL with `apk add --no-cache $PHPIZE_DEPS` plus `pecl install`. This is heavier and rarely needed.

## Mounting custom config at runtime

You don't always need a new image. For quick tweaks, mount a file directly:

```bash
# Extra PHP settings
docker run --rm -p 8080:8080 \
  -v "$PWD/90-app.ini:/etc/php84/conf.d/90-app.ini:ro" \
  erseco/alpine-php-webserver

# Extra Nginx server-block rules
docker run --rm -p 8080:8080 \
  -v "$PWD/routes.conf:/etc/nginx/server-conf.d/routes.conf:ro" \
  erseco/alpine-php-webserver
```

See [Nginx Configuration](nginx.md) and [PHP Configuration](php.md) for the directory conventions.

## Rebuild vs. override: which to pick?

| Situation | What to do |
|-----------|------------|
| Tweaking limits (`memory_limit`, `client_max_body_size`, timezone…) | **Environment variables.** No rebuild needed. |
| Adding one PHP extension | **Build your own image** on top with `apk add`. |
| Adding one Nginx route | **Mount a file** into `/etc/nginx/server-conf.d/`. |
| Adding Composer dependencies | **Build your own image**. See [Composer & Building](composer.md). |
| Running an extra daemon (queue worker, supervisor) | **Build your own image** with an extra `runit` entry. |
| Debugging production | **`docker compose exec --user root web sh`** — non-persistent. |
