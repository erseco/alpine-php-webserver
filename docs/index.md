# Alpine PHP Webserver

A minimal **Nginx + PHP-FPM** Docker image built on [Alpine Linux](https://www.alpinelinux.org/).

[![Docker Pulls](https://img.shields.io/docker/pulls/erseco/alpine-php-webserver.svg)](https://hub.docker.com/r/erseco/alpine-php-webserver/)
![Docker Image Size](https://img.shields.io/docker/image-size/erseco/alpine-php-webserver)
![License MIT](https://img.shields.io/badge/license-MIT-blue.svg)

## What is this image?

`erseco/alpine-php-webserver` packages Nginx, PHP-FPM and a handful of common PHP extensions into a **~25 MB** container ready to serve any PHP application. It is designed to be:

- **Small** — Alpine base, single-process-group runtime via [`runit`](http://smarden.org/runit/).
- **Secure** — Nginx and PHP-FPM run as the unprivileged `nobody` user.
- **Fast** — `ondemand` FPM process manager; Unix socket between Nginx and PHP; OPcache-ready.
- **Extensible** — drop extra daemons into `/etc/service/<name>/run`, init scripts into `/docker-entrypoint-init.d/`, Nginx snippets into `/etc/nginx/conf.d/` or `/etc/nginx/server-conf.d/`.
- **Configurable via env vars** — every meaningful PHP / Nginx setting is templated at startup via `envsubst`.

This image is the **base for [`erseco/alpine-moodle`](https://github.com/erseco/alpine-moodle)** and powers numerous Symfony, Laravel, WordPress and plain PHP deployments.

## Highlights

- Alpine Linux **3.23**, Nginx **1.28**, PHP **8.4** FPM (see the Dockerfile for the actual versions in each tag)
- Multi-arch: `amd64`, `arm64`, `arm/v7`, `arm/v6`, `386`, `ppc64le`, `s390x`
- `ondemand` FPM process manager — ~zero idle CPU
- Unix-socket FastCGI for Nginx ↔ PHP (`/run/php-fpm.sock`)
- Healthcheck on `/fpm-ping` (localhost-only by design)
- Logs on `stdout` / `stderr` — just `docker logs -f`
- Trusted-proxy real IP support (`REAL_IP_FROM`, Cloudflare, Tunnel)
- `DISABLE_DEFAULT_LOCATION` to fully own the routing layer
- Follows the **KISS** principle — the runtime is a few small shell scripts you can read in minutes

## Where to start

<div class="grid cards" markdown>

- :material-rocket-launch: **[Quick Start](quick-start.md)** — serve your `./php` directory in under a minute.
- :material-docker: **[Docker Compose](docker-compose.md)** — local dev stacks, mounting code, building your own image.
- :material-nginx: **[Nginx Configuration](nginx.md)** — conf.d vs server-conf.d, custom routing, DISABLE_DEFAULT_LOCATION.
- :material-language-php: **[PHP Configuration](php.md)** — custom.ini, OPcache, timezone, locale.
- :material-database: **[Environment Variables](environment-variables.md)** — every supported knob.
- :material-shield-lock: **[Reverse Proxy & Trusted IPs](reverse-proxy.md)** — Traefik, Nginx, Cloudflare, Cloudflare Tunnel.
- :material-package-variant: **[Composer & Building](composer.md)** — recipes for building production images.
- :material-puzzle: **[Extending the Image](extending.md)** — runit daemons, init scripts, running as root.
- :material-heart-pulse: **[Healthcheck & Logs](healthcheck-logs.md)** — what `/fpm-ping` does and where logs go.
- :material-lightbulb-on: **[Troubleshooting](troubleshooting.md)** — solutions to recurring issues.
- :material-help-circle: **[FAQ](faq.md)** — quick answers.

</div>

## Minimal example

```bash
docker run --rm -p 8080:8080 erseco/alpine-php-webserver
```

- <http://localhost:8080/> — `phpinfo()`
- <http://localhost:8080/test.html> — static HTML probe

Mount your own code to serve it:

```bash
docker run --rm -p 8080:8080 -v "$PWD/php:/var/www/html" erseco/alpine-php-webserver
```

## Project links

- Source code: <https://github.com/erseco/alpine-php-webserver>
- Docker Hub: <https://hub.docker.com/r/erseco/alpine-php-webserver>
- GitHub Container Registry: `ghcr.io/erseco/alpine-php-webserver`
- Issue tracker: <https://github.com/erseco/alpine-php-webserver/issues>
