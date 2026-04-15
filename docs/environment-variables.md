# Environment Variables

Full reference for every setting exposed by `erseco/alpine-php-webserver`. Defaults come from the `Dockerfile` and are applied unless you override them.

## Nginx

| Variable                 | Default                  | Purpose |
|--------------------------|--------------------------|---------|
| `nginx_root_directory`   | `/var/www/html`          | Document root for the default server block. |
| `client_max_body_size`   | `2M`                     | Max allowed request body size. Raise for uploads. |
| `fastcgi_read_timeout`   | `60s`                    | Max time waiting for a response from PHP-FPM. |
| `fastcgi_send_timeout`   | `60s`                    | Max time transmitting a request to PHP-FPM. |
| `DISABLE_DEFAULT_LOCATION` | `false`                | Comment out the built-in `location / { ... }` block so you can provide your own via `/etc/nginx/server-conf.d/`. See [#43](https://github.com/erseco/alpine-php-webserver/issues/43). |

## Trusted proxy / real IP

Real IP restoration is **disabled by default**. Configure `REAL_IP_FROM` with a strict allow-list of trusted proxies to enable it.

| Variable             | Default             | Purpose |
|----------------------|---------------------|---------|
| `REAL_IP_HEADER`     | `X-Forwarded-For`   | Header Nginx reads as the client IP (`X-Forwarded-For`, `CF-Connecting-IP`, `X-Real-IP`…). |
| `REAL_IP_RECURSIVE`  | `off`               | `on` = walk the trusted chain recursively. |
| `REAL_IP_FROM`       | *(empty)*           | Comma-separated list of trusted proxy IPs / CIDRs. **Real IP stays disabled until this is set.** |

See [Reverse Proxy & Trusted IPs](reverse-proxy.md) for concrete recipes.

!!! danger "Never use broad public ranges"
    `REAL_IP_FROM=0.0.0.0/0` would let any client spoof the configured header. Trust only proxies you control (internal CIDRs, Cloudflare's published ranges, your tunnel connector, etc.).

## PHP runtime

| Variable                 | Default | Purpose |
|--------------------------|---------|---------|
| `clear_env`              | `no`    | Keep env vars available to FPM workers. |
| `allow_url_fopen`        | `On`    | URL-aware `fopen()`. |
| `allow_url_include`      | `Off`   | URL-aware `include()` / `require()`. Leave off. |
| `display_errors`         | `Off`   | Render errors in HTTP responses. |
| `file_uploads`           | `On`    | Enable HTTP uploads. |
| `max_execution_time`     | `0`     | Max seconds per script. `0` = unlimited. |
| `max_input_time`         | `-1`    | Max seconds parsing input. `-1` = unlimited. |
| `max_input_vars`         | `1000`  | Max input vars per request. |
| `memory_limit`           | `128M`  | Per-request memory ceiling. |
| `post_max_size`          | `8M`    | Max POST body. Must exceed `upload_max_filesize`. |
| `upload_max_filesize`    | `2M`    | Max single file upload. |
| `zlib_output_compression`| `On`    | Transparent output compression. |
| `date_timezone`          | `UTC`   | PHP `date.timezone`. |
| `intl_default_locale`    | `en_US` | PHP `intl.default_locale`. |

## OPcache

| Variable                       | Default   | Purpose |
|--------------------------------|-----------|---------|
| `opcache_enable`               | `0`       | `1` to enable OPcache. |
| `opcache_memory_consumption`   | `256`     | Shared memory in MB. |
| `opcache_max_accelerated_files`| `20000`   | Max cached files. |
| `opcache_validate_timestamps`  | `0`       | `1` revalidates on every request (dev); `0` never (prod). |
| `opcache_preload`              | *(empty)* | Preload script path. |
| `realpath_cache_size`          | `4096K`   | Realpath cache size. |
| `realpath_cache_ttl`           | `600`     | Realpath cache TTL (seconds). |

See [PHP Configuration](php.md) for usage notes and examples.

## Adding your own variables

Anything not in this table can be injected via:

- `/etc/nginx/conf.d/*.conf` or `/etc/nginx/server-conf.d/*.conf` for Nginx directives
- `/etc/php84/conf.d/NN-*.ini` for PHP settings
- A custom image extending this one

See [Extending the Image](extending.md).
