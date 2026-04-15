# FAQ

## Which port does the container listen on?

**8080**. Always. The image intentionally avoids privileged ports because it runs as `nobody`. Publish on any host port you like:

```bash
docker run -p 80:8080 erseco/alpine-php-webserver
```

## Which user runs inside the container?

`nobody` (UID **65534**). Nginx, PHP-FPM and every startup script run as this user. Bind-mounted host directories must be readable by UID 65534; named volumes get it right automatically.

## Where do I put my code?

`/var/www/html`. Either mount it (dev) or `COPY` it into a derived image (prod).

## How do I install Composer?

You don't install it into this image — you build your own thin image on top with `apk add --no-cache composer`. See [Composer & Building](composer.md) for the recipe.

## How do I add a PHP extension that isn't bundled?

Build a derived image:

```dockerfile
FROM erseco/alpine-php-webserver:latest
USER root
RUN apk add --no-cache php84-ldap php84-pecl-redis
USER nobody
```

Extensions available in Alpine: <https://pkgs.alpinelinux.org/packages?name=php84-*&branch=edge>

## What's the connection between Nginx and PHP-FPM?

A Unix socket at `/run/php-fpm.sock`. Adopted in [#16](https://github.com/erseco/alpine-php-webserver/issues/16) — faster and more secure than TCP on localhost.

## Why is there a `/fpm-ping` endpoint?

For the Docker healthcheck. It is locked down to `127.0.0.1` ([#20](https://github.com/erseco/alpine-php-webserver/issues/20)) and returns `pong` when PHP-FPM is responsive. External requests get `403`.

## How do I change PHP settings?

Environment variables. The entrypoint expands `/etc/php84/conf.d/custom.ini.tpl` through `envsubst`. See [PHP Configuration](php.md) and the full [Environment Variables](environment-variables.md) reference.

For settings not exposed as env vars, drop your own `.ini` file into `/etc/php84/conf.d/`:

```bash
-v "$PWD/90-app.ini:/etc/php84/conf.d/90-app.ini:ro"
```

## How do I run commands as root?

```bash
docker compose exec --user root web sh
```

Used for installing debug tools, inspecting file ownership, or running one-off apk commands. See [Extending the Image](extending.md).

## Can I run additional services (queue worker, supervisor) in the same container?

Yes — add a `runit` entry. Each daemon lives in `/etc/service/<name>/run`. See [Extending the Image](extending.md) for the full pattern, or read the bundled `nginx` and `php` service scripts for working examples.

## Does it support multi-arch?

Yes: `amd64`, `arm64`, `arm/v7`, `arm/v6`, `386`, `ppc64le`, `s390x`. Just pull `erseco/alpine-php-webserver` on any of them.

## What's the difference between `conf.d/` and `server-conf.d/`?

- `/etc/nginx/conf.d/*.conf` is included inside the `http {}` block — use it for global directives and extra `server {}` blocks.
- `/etc/nginx/server-conf.d/*.conf` is included inside the default `server {}` — use it for custom `location` blocks on the default site.

The distinction was introduced in [#29](https://github.com/erseco/alpine-php-webserver/issues/29).

## How do I turn on OPcache safely?

In production:

```yaml
environment:
  opcache_enable: "1"
  opcache_memory_consumption: "256"
  opcache_max_accelerated_files: "20000"
  opcache_validate_timestamps: "0"
```

And **restart the container on every deploy** — with `validate_timestamps=0`, PHP will not re-read changed files on its own. See [PHP Configuration](php.md).

## How do I get the real client IP?

Set `REAL_IP_FROM` to the list of trusted proxies. Real IP restoration is disabled by default for safety. See [Reverse Proxy & Trusted IPs](reverse-proxy.md).

## What's the image based on? Can I use a newer Alpine version?

Current `main` is on Alpine 3.23, Nginx 1.28, PHP 8.4. Older Alpine versions are available as fixed tags (`3.22`, `3.21`, `3.20`) for backports. Pick the one that matches your stability vs. freshness preference.

## Can I contribute?

Yes — issues and pull requests are welcome. Docs live under `docs/` and are built with [Zensical](https://zensical.org/) via `.github/workflows/docs.yml`.
