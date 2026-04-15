# Docker Compose Examples

Drop-in compose stacks for common use cases. Adapt the image tag, passwords and volume paths to your needs.

## Minimal local dev

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

## With MariaDB

```yaml
services:
  web:
    image: erseco/alpine-php-webserver
    restart: unless-stopped
    environment:
      date_timezone: Europe/Madrid
      memory_limit: 256M
    ports:
      - "8080:8080"
    volumes:
      - ./app:/var/www/html
    depends_on:
      - db

  db:
    image: mariadb:lts
    restart: unless-stopped
    environment:
      MARIADB_ROOT_PASSWORD: rootpw
      MARIADB_DATABASE: app
      MARIADB_USER: app
      MARIADB_PASSWORD: app
    volumes:
      - mariadb:/var/lib/mysql

volumes:
  mariadb:
```

## With PostgreSQL

```yaml
services:
  web:
    image: erseco/alpine-php-webserver
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - ./app:/var/www/html
    depends_on:
      - db

  db:
    image: postgres:alpine
    restart: unless-stopped
    environment:
      POSTGRES_PASSWORD: app
      POSTGRES_USER: app
      POSTGRES_DB: app
    volumes:
      - postgres:/var/lib/postgresql

volumes:
  postgres:
```

## Behind a reverse proxy (Traefik)

No host port required — the reverse proxy talks to the service over the internal network.

```yaml
services:
  web:
    image: erseco/alpine-php-webserver
    restart: unless-stopped
    environment:
      REAL_IP_HEADER: X-Forwarded-For
      REAL_IP_RECURSIVE: "on"
      REAL_IP_FROM: 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
    volumes:
      - ./app:/var/www/html
    networks:
      - proxy
      - default
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=proxy"
      - "traefik.http.routers.app.rule=Host(`app.example.com`)"
      - "traefik.http.routers.app.entrypoints=websecure"
      - "traefik.http.routers.app.tls=true"
      - "traefik.http.routers.app.tls.certresolver=letsencrypt"
      - "traefik.http.services.app.loadbalancer.server.port=8080"

networks:
  proxy:
    external: true
```

See [Reverse Proxy & Trusted IPs](reverse-proxy.md) for Nginx, Apache, Caddy and Cloudflare variants.

## Building your own image on top

Use `build:` instead of `image:` when your project needs Composer or custom config baked in.

```yaml
services:
  web:
    build:
      context: .
      dockerfile: Dockerfile
    restart: unless-stopped
    ports:
      - "8080:8080"
```

A matching `Dockerfile`:

```dockerfile
FROM erseco/alpine-php-webserver:latest

USER root
RUN apk add --no-cache composer
USER nobody

COPY --chown=nobody:nobody ./ /var/www/html
WORKDIR /var/www/html

RUN composer install --no-dev --optimize-autoloader --no-interaction --no-progress

USER root
RUN apk del composer
USER nobody
```

See [Composer & Building](composer.md) for the full recipe.

## Production tuning

```yaml
services:
  web:
    image: erseco/alpine-php-webserver
    restart: unless-stopped
    environment:
      # Serve uploaded files / large POSTs
      client_max_body_size: 64M
      post_max_size: 64M
      upload_max_filesize: 64M
      memory_limit: 256M
      max_execution_time: 60
      fastcgi_read_timeout: 90s
      fastcgi_send_timeout: 90s

      # OPcache for production
      opcache_enable: "1"
      opcache_memory_consumption: "256"
      opcache_max_accelerated_files: "20000"
      opcache_validate_timestamps: "0"

      # Locale / timezone
      date_timezone: UTC
      intl_default_locale: en_US
    volumes:
      - ./app:/var/www/html
```

!!! warning "OPcache with `opcache_validate_timestamps=0`"
    Production images that opt into `opcache_validate_timestamps=0` **must** be rebuilt (or the container restarted) on every deploy. Otherwise OPcache will keep serving the previous revision of your PHP files.
