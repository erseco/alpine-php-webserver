# Troubleshooting

Common failure modes and their fixes, mined from the issue tracker.

## `403 Forbidden` on every request

**Cause**: Nginx can't read the files at `nginx_root_directory`. Either the mount is wrong, or the files are not readable by `nobody` (UID 65534). Related: [#25](https://github.com/erseco/alpine-php-webserver/issues/25).

**Fix**:

```bash
sudo chown -R 65534:65534 ./app
sudo find ./app -type d -exec chmod 755 {} \;
sudo find ./app -type f -exec chmod 644 {} \;
```

Or use a named Docker volume, which gets the right ownership automatically.

## `phpinfo()` shows instead of my app

**Cause**: You didn't mount your code and the bundled default `index.php` is being served. Related: [#27](https://github.com/erseco/alpine-php-webserver/issues/27).

**Fix**: mount your code into `/var/www/html`:

```bash
docker run -p 8080:8080 -v "$PWD/app:/var/www/html" erseco/alpine-php-webserver
```

## Symfony / Laravel URLs have a `?q=` query parameter

**Cause**: You are on an old tag from before [#55](https://github.com/erseco/alpine-php-webserver/issues/55) was fixed. The current `try_files` rule is Symfony-friendly.

**Fix**: `docker pull erseco/alpine-php-webserver` to update. If you really need to stay on an older tag, mount a replacement `server-conf.d/` snippet that overrides the default location block — or set `DISABLE_DEFAULT_LOCATION=true` and provide your own.

## Clean URLs / custom routing don't work

**Cause**: The default `location /` block is interfering with your own routing rules. Related: [#43](https://github.com/erseco/alpine-php-webserver/issues/43).

**Fix**: set `DISABLE_DEFAULT_LOCATION=true` and add your rules via `/etc/nginx/server-conf.d/`:

```yaml
environment:
  DISABLE_DEFAULT_LOCATION: "true"
volumes:
  - ./nginx/app.conf:/etc/nginx/server-conf.d/app.conf:ro
```

## Composer build fails with *"could not find a composer.json"*

**Cause**: `composer install` ran before `composer.json` was copied in, or from the wrong working directory. Related: [#40](https://github.com/erseco/alpine-php-webserver/issues/40).

**Fix**: set `WORKDIR` and `COPY` before calling Composer:

```dockerfile
FROM erseco/alpine-php-webserver:latest
USER root
RUN apk add --no-cache composer

COPY --chown=nobody:nobody ./ /var/www/html
WORKDIR /var/www/html
USER nobody

RUN composer install --no-dev --optimize-autoloader --no-interaction --no-progress
```

See [Composer & Building](composer.md).

## Healthcheck always fails from my browser

**Cause**: Expected. The `/fpm-ping` endpoint is localhost-only by design ([#20](https://github.com/erseco/alpine-php-webserver/issues/20)). External probes get a `403`.

**Fix**: use Docker's native healthcheck (already enabled) or add your own public health endpoint in your app:

```php
<?php
// public/health.php
http_response_code(200);
echo "ok\n";
```

## Real client IP is always `172.x.y.z`

**Cause**: Nginx is correctly reporting the Docker network gateway, because you haven't told it which proxies to trust. Related: [#72](https://github.com/erseco/alpine-php-webserver/issues/72), [#74](https://github.com/erseco/alpine-php-webserver/issues/74).

**Fix**:

```yaml
environment:
  REAL_IP_HEADER: X-Forwarded-For
  REAL_IP_RECURSIVE: "on"
  REAL_IP_FROM: 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
```

See [Reverse Proxy & Trusted IPs](reverse-proxy.md) for Cloudflare-specific ranges.

## `$_SERVER['HTTPS']` is empty behind HTTPS proxy

**Cause**: The proxy isn't forwarding `X-Forwarded-Proto`, so Nginx doesn't set `HTTPS=on` for FPM.

**Fix**: On the **proxy** side, forward it:

```nginx
proxy_set_header X-Forwarded-Proto https;
```

The image already wires `X-Forwarded-Proto` → `$forwarded_scheme` → `HTTPS`.

## Uploads fail silently at ~2 MB

**Cause**: Three limits stack, and two of them are PHP defaults from the image ([see defaults](environment-variables.md)).

**Fix**: raise all three together:

```yaml
environment:
  client_max_body_size: 64M     # Nginx
  post_max_size: 64M            # PHP
  upload_max_filesize: 64M      # PHP
  memory_limit: 256M            # PHP, must exceed post_max_size
```

## Upload hangs for large files

**Cause**: FastCGI timeouts kick in before PHP finishes handling the upload.

**Fix**:

```yaml
environment:
  fastcgi_read_timeout: 300s
  fastcgi_send_timeout: 300s
  max_execution_time: 300
  max_input_time: 300
```

## Permission denied writing to `vendor/` or mounted volume

**Cause**: Files are owned by `root` from an earlier build / bind mount, and `nobody` can't write to them.

**Fix**:

```bash
# One-off fix on a bind-mounted host directory
sudo chown -R 65534:65534 ./app
```

Or inside a custom image:

```dockerfile
USER root
RUN chown -R nobody:nobody /var/www/html
USER nobody
```

## Container exits immediately with a `runit` error

**Cause**: A service in `/etc/service/<name>/run` crashed on start and `runit` couldn't recover, or a script in `/docker-entrypoint-init.d/` exited non-zero.

**Fix**: run with `docker compose logs -f` to see which script or service failed. The entrypoint prints `*** Failed with return value: N` for init scripts and `sv status <name>` output for services.

## OPcache serves stale code after deploy

**Cause**: `opcache_validate_timestamps=0` is set (correct for production), but the container was not restarted after the deploy.

**Fix**: either restart the container on each deploy (`docker compose up -d --force-recreate web`), or keep `opcache_validate_timestamps=1` during active development.

## Can I run multiple Nginx server blocks?

Yes. Drop additional `server { ... }` declarations into `/etc/nginx/conf.d/*.conf` (not `server-conf.d/` — that one is included *inside* the default server block, not at the `http {}` level). See [Nginx Configuration](nginx.md).

## Still stuck?

Open an issue with:

- The exact image tag (`docker image ls | grep alpine-php-webserver`)
- Your Compose file or `docker run` command (scrubbed of secrets)
- `docker compose logs web` output for the failing start
- Your proxy config if it's a reverse-proxy problem
