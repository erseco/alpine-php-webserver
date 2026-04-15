# Quick Start

## Run it

```bash
docker run --rm -p 8080:8080 erseco/alpine-php-webserver
```

Open <http://localhost:8080/>. You'll see `phpinfo()` from the bundled `index.php`. The static probe at <http://localhost:8080/test.html> is also served.

Stop with `Ctrl+C`.

## Serve your own code

Bind-mount a local directory into `/var/www/html`:

```bash
docker run --rm -p 8080:8080 \
  -v "$PWD/php:/var/www/html" \
  erseco/alpine-php-webserver
```

Nginx serves static files directly and hands `*.php` requests to PHP-FPM via the Unix socket at `/run/php-fpm.sock`.

!!! tip "The container runs as `nobody` (UID 65534)"
    Bind-mounted files must be readable by that user. For write access (sessions, caches, uploads), make the directory writable too:

    ```bash
    sudo chown -R 65534:65534 ./php
    ```

    Named Docker volumes get the right ownership automatically.

## With Docker Compose

Save as `docker-compose.yml` next to your code:

```yaml
services:
  web:
    image: erseco/alpine-php-webserver
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - ./php:/var/www/html
```

Run it:

```bash
docker compose up -d
docker compose logs -f web
```

See [Docker Compose](docker-compose.md) for more realistic stacks (MariaDB, Redis, reverse proxy).

## What port does it listen on?

**8080** inside the container. The image intentionally does not bind privileged ports because it runs as `nobody`. Map whatever public port you want:

```bash
docker run --rm -p 80:8080 erseco/alpine-php-webserver   # host 80 → container 8080
```

## Tweaking limits on the fly

The most common knobs are exposed as environment variables:

```bash
docker run --rm -p 8080:8080 \
  -e client_max_body_size=64M \
  -e upload_max_filesize=64M \
  -e post_max_size=64M \
  -e memory_limit=256M \
  -e date_timezone=Europe/Madrid \
  -v "$PWD/php:/var/www/html" \
  erseco/alpine-php-webserver
```

See [Environment Variables](environment-variables.md) for the full reference.

## Next steps

- Put it behind a [reverse proxy](reverse-proxy.md) for TLS and real client IPs.
- Build your own image on top with [Composer & Building](composer.md).
- Add custom Nginx routing with [Nginx Configuration](nginx.md).
- Enable OPcache for production — see [PHP Configuration](php.md).
