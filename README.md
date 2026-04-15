# Alpine PHP Webserver

[![Docker Pulls](https://img.shields.io/docker/pulls/erseco/alpine-php-webserver.svg)](https://hub.docker.com/r/erseco/alpine-php-webserver/)
![Docker Image Size](https://img.shields.io/docker/image-size/erseco/alpine-php-webserver)
![alpine 3.23](https://img.shields.io/badge/alpine-3.23-brightgreen.svg)
![nginx 1.28](https://img.shields.io/badge/nginx-1.28-brightgreen.svg)
![php 8.4](https://img.shields.io/badge/php-8.4-brightgreen.svg)
![License MIT](https://img.shields.io/badge/license-MIT-blue.svg)

A minimal **Nginx + PHP-FPM** Docker image built on [Alpine Linux](https://www.alpinelinux.org/) — ~25 MB, multi-arch, configured entirely through environment variables.

> 📚 **Full documentation: <https://erseco.github.io/alpine-php-webserver/>**

The documentation site covers quick start, Docker Compose recipes, Nginx/PHP configuration, reverse proxy and trusted-IP setups (Traefik, Nginx, Cloudflare, Cloudflare Tunnel), a complete environment variable reference, Composer/build recipes, how to extend the image with `runit` daemons and init scripts, the healthcheck and logging story, and a troubleshooting section built from the most frequent support questions.

## Quick start

```bash
docker run --rm -p 8080:8080 erseco/alpine-php-webserver
```

Open <http://localhost:8080/> to see `phpinfo()`, or <http://localhost:8080/test.html> for the static probe.

Mount your own code:

```bash
docker run --rm -p 8080:8080 -v "$PWD/php:/var/www/html" erseco/alpine-php-webserver
```

Compose:

```yaml
services:
  web:
    image: erseco/alpine-php-webserver
    ports:
      - "8080:8080"
    volumes:
      - ./php:/var/www/html
    restart: unless-stopped
```

## Supported tags and respective Dockerfile links

<!-- supported-tags:start -->
- `latest`, `3`, `3.23`, `3.23.3` ([Dockerfile](https://github.com/erseco/alpine-php-webserver/blob/3.23.3/Dockerfile))
- `3.22`, `3.22.2` ([Dockerfile](https://github.com/erseco/alpine-php-webserver/blob/3.22.2/Dockerfile))
- `3.21`, `3.21.5` ([Dockerfile](https://github.com/erseco/alpine-php-webserver/blob/3.21.5/Dockerfile))
- `3.20`, `3.20.8` ([Dockerfile](https://github.com/erseco/alpine-php-webserver/blob/3.20.8/Dockerfile))
<!-- supported-tags:end -->

> **Note**: The `main` branch ([Dockerfile](https://github.com/erseco/alpine-php-webserver/blob/main/Dockerfile)) is automatically pushed with the tag **`beta`**. Use this tag for testing purposes before stable releases are published.

## Key features

- Compact image (~25 MB) built on Alpine Linux
- PHP 8.4 FPM with `ondemand` process manager — idles near-zero CPU
- Unix-socket FastCGI between Nginx and PHP-FPM
- Healthcheck on `/fpm-ping` (localhost-only by design)
- Trusted-proxy real IP support (`REAL_IP_FROM`, Cloudflare, Tunnel)
- `DISABLE_DEFAULT_LOCATION` for full routing control
- Custom Nginx snippets via `/etc/nginx/conf.d/` and `/etc/nginx/server-conf.d/`
- Custom PHP settings via environment variables or `/etc/php84/conf.d/*.ini`
- Extra daemons via `runit` (`/etc/service/<name>/run`)
- Startup scripts via `/docker-entrypoint-init.d/`
- Non-privileged `nobody` user; logs on `stdout` / `stderr`
- Multi-arch: `amd64`, `arm64`, `arm/v7`, `arm/v6`, `386`, `ppc64le`, `s390x`

## Running Commands as Root

The container runs as `nobody`. When you need root (installing extra Alpine packages for debugging, inspecting file ownership, etc.), use `docker compose exec` with `--user root`:

```bash
docker compose exec --user root web sh
```

Example — install debug tools on a running container:

```bash
docker compose exec --user root web sh -c "apk update && apk add nano curl htop"
```

## Environment Variables

The most-requested reference. The full grouped reference (with OPcache, real IP, reverse proxy recipes) lives at <https://erseco.github.io/alpine-php-webserver/environment-variables/>.

| Server | Variable Name                 | Default         | Description |
|--------|-------------------------------|-----------------|-------------|
| NGINX  | `nginx_root_directory`        | `/var/www/html` | Document root for the default server block. |
| NGINX  | `client_max_body_size`        | `2M`            | Max allowed client request body. |
| NGINX  | `fastcgi_read_timeout`        | `60s`           | Max time waiting for a response from PHP-FPM. |
| NGINX  | `fastcgi_send_timeout`        | `60s`           | Max time transmitting a request to PHP-FPM. |
| NGINX  | `DISABLE_DEFAULT_LOCATION`    | `false`         | When `true`, comments out the default `location /` block so you can mount your own via `/etc/nginx/server-conf.d/`. |
| NGINX  | `REAL_IP_HEADER`              | `X-Forwarded-For` | Header Nginx trusts as the real client IP (`X-Forwarded-For`, `CF-Connecting-IP`, …). |
| NGINX  | `REAL_IP_RECURSIVE`           | `off`           | `on` to walk the trusted proxy chain recursively. |
| NGINX  | `REAL_IP_FROM`                | *(empty)*       | Comma-separated list of trusted proxy IPs / CIDRs. Real IP stays disabled until set. |
| PHP8   | `clear_env`                   | `no`            | Keep env vars available to FPM workers. |
| PHP8   | `allow_url_fopen`             | `On`            | Enable URL-aware fopen wrappers. |
| PHP8   | `allow_url_include`           | `Off`           | Allow `include()` / `require()` from URLs. |
| PHP8   | `display_errors`              | `Off`           | Render errors in HTTP responses. |
| PHP8   | `file_uploads`                | `On`            | Enable HTTP uploads. |
| PHP8   | `max_execution_time`          | `0`             | Max script runtime in seconds. `0` = unlimited. |
| PHP8   | `max_input_time`              | `-1`            | Max input parsing time in seconds. `-1` = unlimited. |
| PHP8   | `max_input_vars`              | `1000`          | Max POST/GET variables per request. |
| PHP8   | `memory_limit`                | `128M`          | Per-request memory ceiling. `-1` = unlimited. |
| PHP8   | `post_max_size`               | `8M`            | Max POST body. Must exceed `upload_max_filesize`. |
| PHP8   | `upload_max_filesize`         | `2M`            | Max individual file upload size. |
| PHP8   | `zlib_output_compression`     | `On`            | Transparent output compression. |
| PHP8   | `date_timezone`               | `UTC`           | PHP `date.timezone`. |
| PHP8   | `intl_default_locale`         | `en_US`         | PHP `intl.default_locale`. |
| PHP8   | `opcache_enable`              | `0`             | `1` to enable OPcache. |
| PHP8   | `opcache_memory_consumption`  | `256`           | Shared memory in MB. |
| PHP8   | `opcache_max_accelerated_files`| `20000`        | Max cached files. |
| PHP8   | `opcache_validate_timestamps` | `0`             | `0` = production (restart on deploy); `1` = development. |
| PHP8   | `opcache_preload`             | *(empty)*       | Preload script path. |
| PHP8   | `realpath_cache_size`         | `4096K`         | Realpath cache size. |
| PHP8   | `realpath_cache_ttl`          | `600`           | Realpath cache TTL in seconds. |

## Registries

- Docker Hub: `erseco/alpine-php-webserver`
- GitHub Container Registry: `ghcr.io/erseco/alpine-php-webserver`

## Documentation

The full, searchable documentation lives at **<https://erseco.github.io/alpine-php-webserver/>**:

- [Quick Start](https://erseco.github.io/alpine-php-webserver/quick-start/)
- [Docker Compose examples](https://erseco.github.io/alpine-php-webserver/docker-compose/)
- [Nginx configuration](https://erseco.github.io/alpine-php-webserver/nginx/)
- [PHP configuration](https://erseco.github.io/alpine-php-webserver/php/)
- [Environment variables reference](https://erseco.github.io/alpine-php-webserver/environment-variables/)
- [Reverse proxy & trusted IPs](https://erseco.github.io/alpine-php-webserver/reverse-proxy/)
- [Composer & building your own image](https://erseco.github.io/alpine-php-webserver/composer/)
- [Extending the image](https://erseco.github.io/alpine-php-webserver/extending/)
- [Healthcheck & logs](https://erseco.github.io/alpine-php-webserver/healthcheck-logs/)
- [Troubleshooting](https://erseco.github.io/alpine-php-webserver/troubleshooting/)
- [FAQ](https://erseco.github.io/alpine-php-webserver/faq/)

## Contributing

Issues and pull requests are welcome: <https://github.com/erseco/alpine-php-webserver/issues>.

Documentation sources live under [`docs/`](docs/) and are built with [Zensical](https://zensical.org/) via the `docs.yml` GitHub Actions workflow.

## License

[MIT](LICENSE)
