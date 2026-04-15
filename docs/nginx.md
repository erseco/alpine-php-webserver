# Nginx Configuration

The image ships with a single `nginx.conf` that powers one server block on port **8080**. Every common setting is templated from environment variables at container start through `envsubst`.

## File layout

```
/etc/nginx/
├── nginx.conf                 # main file, envsubst'd at startup
├── conf.d/                    # extra http{} includes (real-ip, global rules)
└── server-conf.d/             # extra server{} includes (per-route rules)
```

You have two extension points depending on **where** the snippet needs to go:

| Directory                    | Include location       | Use for |
|------------------------------|------------------------|---------|
| `/etc/nginx/conf.d/*.conf`   | inside `http {}`       | upstreams, global directives, additional `server {}` blocks, trusted proxy setup |
| `/etc/nginx/server-conf.d/*.conf` | inside the default `server {}` | custom `location` blocks, rewrites, auth rules that apply to the main site |

This split was added in response to [#29](https://github.com/erseco/alpine-php-webserver/issues/29) so you don't have to replace the whole `nginx.conf`.

## Mounting snippets

```bash
docker run --rm -p 8080:8080 \
  -v "$PWD/my-location.conf:/etc/nginx/server-conf.d/my-location.conf:ro" \
  erseco/alpine-php-webserver
```

Compose:

```yaml
services:
  web:
    image: erseco/alpine-php-webserver
    volumes:
      - ./app:/var/www/html
      - ./nginx/my-location.conf:/etc/nginx/server-conf.d/my-location.conf:ro
```

Example `my-location.conf`:

```nginx
location /api/ {
    try_files $uri /api/index.php$is_args$args;
}

location /static/ {
    expires 30d;
    access_log off;
}
```

## Overriding the default `location /`

The default server block includes:

```nginx
location / {
    try_files $uri $uri/ /index.php$is_args$args;
}
```

This works for WordPress, Symfony, Laravel and most front-controller frameworks. If you need something radically different, set `DISABLE_DEFAULT_LOCATION=true` and provide your own `location /` via `/etc/nginx/server-conf.d/` ([#43](https://github.com/erseco/alpine-php-webserver/issues/43)):

```yaml
services:
  web:
    image: erseco/alpine-php-webserver
    environment:
      DISABLE_DEFAULT_LOCATION: "true"
    volumes:
      - ./app:/var/www/html
      - ./nginx/custom-root.conf:/etc/nginx/server-conf.d/custom-root.conf:ro
```

`custom-root.conf`:

```nginx
location / {
    return 200 "Custom root handler\n";
    add_header Content-Type text/plain;
}
```

!!! info "How `DISABLE_DEFAULT_LOCATION` works"
    At startup, the entrypoint comments out the default `location / { ... }` block in `nginx.conf` with `sed`. It does not touch anything else. Your replacement must live in `server-conf.d/`, which is included later in the same server block.

## Clean URLs for Symfony / Laravel

The image already uses a Symfony-friendly `try_files` with `$is_args$args` ([#55](https://github.com/erseco/alpine-php-webserver/issues/55)):

```nginx
try_files $uri $uri/ /index.php$is_args$args;
```

No `?q=` parameter pollution. `PATH_INFO` is populated correctly by the PHP `location` block. Nothing extra to configure for Symfony 5/6/7, Laravel, WordPress or plain PHP front-controllers.

## Full file replacement

If you really need a different `nginx.conf`, mount your own over `/etc/nginx/nginx.conf`. Note that it will still be passed through `envsubst`, so `${var}` references must match defined env vars or be escaped.

```bash
docker run --rm -p 8080:8080 \
  -v "$PWD/nginx.conf:/etc/nginx/nginx.conf:ro" \
  erseco/alpine-php-webserver
```

## Large uploads

Three variables must be raised together:

```yaml
environment:
  client_max_body_size: 100M   # Nginx
  post_max_size:        100M   # PHP
  upload_max_filesize:  100M   # PHP
  memory_limit:         256M   # PHP (must exceed post_max_size)
```

## Long-running scripts

Bump both Nginx and PHP:

```yaml
environment:
  fastcgi_read_timeout: 300s
  fastcgi_send_timeout: 300s
  max_execution_time:    300
```

## Gzip is already on

The default config enables gzip for the full Cloudflare-recommended MIME list. There is nothing to turn on.
