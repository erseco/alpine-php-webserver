# PHP Configuration

PHP settings are templated from a single file — `/etc/php84/conf.d/custom.ini.tpl` — which the entrypoint runs through `envsubst` and writes to `/etc/php84/conf.d/custom.ini`. FPM pool settings (`/etc/php84/php-fpm.d/www.conf`) get the same treatment.

Concretely, **anything you can change via a documented env var is already wired up**. You don't need to mount a custom `php.ini` for the vast majority of settings.

## Core runtime knobs

| Variable               | Default | Purpose |
|------------------------|---------|---------|
| `memory_limit`         | `128M`  | Per-request memory ceiling. Raise for Composer, Moosh, large imports. `-1` = unlimited. |
| `max_execution_time`   | `0`     | Max seconds a script can run. `0` = unlimited. |
| `max_input_time`       | `-1`    | Max seconds parsing input (POST, GET, uploads). `-1` = unlimited. |
| `max_input_vars`       | `1000`  | Max POST/GET variables per request. Raise for Moodle-style admin forms. |
| `post_max_size`        | `8M`    | Max POST body size. Must exceed `upload_max_filesize`. |
| `upload_max_filesize`  | `2M`    | Max individual file upload size. |
| `file_uploads`         | `On`    | Enable HTTP uploads. |
| `display_errors`       | `Off`   | Render errors in responses. Leave off in production. |
| `allow_url_fopen`      | `On`    | Enable URL-aware fopen wrappers. |
| `allow_url_include`    | `Off`   | Allow `include()` from URLs. Leave off. |
| `zlib_output_compression` | `On`  | Transparent output compression. |
| `clear_env`            | `no`    | Keep env vars available to FPM workers. |

## Locale and timezone

| Variable             | Default   | Purpose |
|----------------------|-----------|---------|
| `date_timezone`      | `UTC`     | `date.timezone` in `custom.ini`. Use [PHP timezone identifiers](https://www.php.net/manual/en/timezones.php) — `Europe/Madrid`, `America/New_York`, etc. |
| `intl_default_locale`| `en_US`   | `intl.default_locale` in `custom.ini`. Used by the `intl` extension and `Locale::getDefault()`. |

```yaml
environment:
  date_timezone: Europe/Madrid
  intl_default_locale: es_ES
```

## OPcache

OPcache is installed but **disabled by default** so that development mounts reflect changes immediately. Turn it on for production:

```yaml
environment:
  opcache_enable: "1"
  opcache_memory_consumption: "256"
  opcache_max_accelerated_files: "20000"
  opcache_validate_timestamps: "0"
```

| Variable                       | Default   | Purpose |
|--------------------------------|-----------|---------|
| `opcache_enable`               | `0`       | `1` = enable OPcache. |
| `opcache_memory_consumption`   | `256`     | MB reserved for the opcode cache. |
| `opcache_max_accelerated_files`| `20000`   | Max number of cached files (keep above your script count). |
| `opcache_validate_timestamps`  | `0`       | `0` = skip mtime checks (prod); `1` = revalidate each request (dev). |
| `opcache_preload`              | *(empty)* | Path to a [preload script](https://www.php.net/manual/en/opcache.configuration.php#ini.opcache.preload). |
| `realpath_cache_size`          | `4096K`   | Realpath cache size. |
| `realpath_cache_ttl`           | `600`     | Realpath cache TTL in seconds. |

!!! warning "`opcache_validate_timestamps=0` + live mounts"
    With `opcache_validate_timestamps=0`, PHP will not re-read files on the fly. In production that is what you want (rebuild the image or restart the container on every deploy). In development, keep it at `1` or OPcache disabled.

### Preloading

```yaml
environment:
  opcache_enable: "1"
  opcache_preload: /var/www/html/config/preload.php
```

Preload runs at FPM worker startup, so any error in the script will keep workers from booting. Start with a small preload file and grow it.

## Bundled extensions

The image ships with a curated set of PHP 8.4 extensions — enough for most frameworks out of the box:

- Core: `ctype`, `curl`, `dom`, `exif`, `fileinfo`, `iconv`, `intl`, `json`, `mbstring`, `openssl`, `session`, `simplexml`, `soap`, `sodium`, `tokenizer`, `xml`, `xmlreader`, `zip`, `zlib`, `phar`
- Image: `gd`
- Databases: `mysqli`, `pdo`, `pdo_mysql`, `pgsql`, `sqlite3`
- Performance: `opcache`, `pecl-apcu`

Need something else (e.g. `ldap`, `redis`, `imagick`)? Build a thin image on top — see [Composer & Building](composer.md):

```dockerfile
FROM erseco/alpine-php-webserver:latest
USER root
RUN apk add --no-cache php84-ldap php84-pecl-redis
USER nobody
```

## Mounting your own `php.ini` snippet

The entrypoint only manages `custom.ini`. You can drop additional `.ini` files into `/etc/php84/conf.d/` and PHP will pick them up:

```bash
docker run --rm -p 8080:8080 \
  -v "$PWD/90-my-app.ini:/etc/php84/conf.d/90-my-app.ini:ro" \
  erseco/alpine-php-webserver
```

Filename convention: `NN-name.ini` where `NN` controls load order. Use a number ≥ `90` to override the image defaults.

## Verifying the running configuration

```bash
# Effective settings (merged)
docker compose exec web php -i | head -60

# Just one setting
docker compose exec web php -r 'echo ini_get("memory_limit"), PHP_EOL;'

# Check which modules are loaded
docker compose exec web php -m
```
