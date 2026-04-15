# Composer & Building Your Own Image

`alpine-php-webserver` intentionally ships **without** Composer so the base image stays at ~25 MB. For projects that need Composer, build a thin image on top.

## Development: install Composer at runtime

Good for quickly testing a project without building a custom image:

```bash
docker run --rm -it \
  -v "$PWD:/var/www/html" \
  -w /var/www/html \
  --user root \
  erseco/alpine-php-webserver \
  sh -c "apk add --no-cache composer && composer install"
```

!!! tip
    Use this only for one-off tasks. Adding packages at runtime every boot is slow and leaves you without reproducible builds.

## Production: bake Composer into your image

This is the pattern you want for CI/CD pipelines:

```dockerfile
FROM erseco/alpine-php-webserver:latest

USER root
RUN apk add --no-cache composer

COPY --chown=nobody:nobody ./ /var/www/html
WORKDIR /var/www/html

USER nobody

RUN composer install \
    --no-dev \
    --optimize-autoloader \
    --no-interaction \
    --no-progress

USER root
RUN apk del composer
USER nobody
```

Build it:

```bash
docker build -t myapp:latest .
docker run --rm -p 8080:8080 myapp:latest
```

Things to note:

- **`COPY --chown=nobody:nobody`** — the image runs as `nobody`. Without this, files will be owned by root and PHP-FPM will see them, but cache/log directories will not be writable.
- **`WORKDIR /var/www/html`** — Composer must run in the directory that actually contains `composer.json` ([#40](https://github.com/erseco/alpine-php-webserver/issues/40)). Running it somewhere else produces *"Composer could not find a composer.json file in /var/www/html"*.
- **`USER nobody` before `composer install`** — Composer writes to `vendor/`, which has to end up owned by `nobody` so the runtime user can read it. Running Composer as root is legal but then you need an extra `chown`.
- **Removing Composer after install** is optional but recommended — it trims about 5 MB and removes a tool attackers could misuse inside the container.

## Multi-stage builds

For bigger projects, split dependencies and runtime:

```dockerfile
# ---- build stage ----
FROM composer:2 AS build

WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-progress

COPY . .
RUN composer dump-autoload --no-dev --classmap-authoritative

# ---- runtime stage ----
FROM erseco/alpine-php-webserver:latest

COPY --from=build --chown=nobody:nobody /app /var/www/html
WORKDIR /var/www/html
```

Advantages:

- Runtime image stays tiny (no Composer binary, no build cache).
- `vendor/` is installed once during the build stage, not on every container start.
- Works great with BuildKit cache mounts for even faster builds.

## Private Composer packages

Private repositories need an auth token. Pass it as a build secret so it never ends up in the final image:

```dockerfile
# syntax=docker/dockerfile:1.6
FROM erseco/alpine-php-webserver:latest

USER root
RUN apk add --no-cache composer

COPY --chown=nobody:nobody ./ /var/www/html
WORKDIR /var/www/html
USER nobody

RUN --mount=type=secret,id=composer_auth,target=/home/nobody/.composer/auth.json,uid=65534 \
    composer install --no-dev --optimize-autoloader --no-interaction --no-progress

USER root
RUN apk del composer
USER nobody
```

Build:

```bash
DOCKER_BUILDKIT=1 docker build \
  --secret id=composer_auth,src="$HOME/.composer/auth.json" \
  -t myapp:latest .
```

## Why `apk add composer` is safe

Composer is packaged in Alpine's official repositories. Installing it with `apk` is exactly what the upstream Composer image does internally. No `curl | sh`, no GPG ceremony.

## Troubleshooting

### `Composer could not find a composer.json file in /var/www/html`

Cause: Composer ran before `composer.json` was copied in, or in a different directory. Fix the build order ([#40](https://github.com/erseco/alpine-php-webserver/issues/40)):

```dockerfile
COPY --chown=nobody:nobody ./ /var/www/html
WORKDIR /var/www/html
USER nobody
RUN composer install ...
```

### `Permission denied` writing to `vendor/`

Cause: Composer is running as `root` but the source files were already copied with `--chown=nobody:nobody`, or vice versa. Pick one approach and stick with it:

- Option A — copy as `nobody`, run Composer as `nobody` (recommended, shown above).
- Option B — copy as root, run Composer as root, then `chown -R nobody:nobody /var/www/html` at the end.

### `Your requirements could not be resolved` on ARM

Some platform-specific packages fail on `arm/v6` or `arm/v7`. Use `--ignore-platform-reqs` only if you know the missing extension is optional for your use case, or cross-compile from an `amd64` builder.
