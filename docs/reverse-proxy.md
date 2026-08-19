# Reverse Proxy & Trusted IPs

When `alpine-php-webserver` runs behind any HTTPS-terminating proxy you typically need two things:

1. **The PHP app must see the original client IP** — not the proxy's.
2. **PHP must know the public request scheme and port** — so canonical URLs, redirects, and secure cookies work correctly.

The image supports both, but the proxy must forward the relevant headers.

## Real client IP

Nginx rewrites `$remote_addr` only for proxies you explicitly trust. Set `REAL_IP_FROM` to the list of trusted hops:

```bash
docker run \
  -e REAL_IP_HEADER=X-Forwarded-For \
  -e REAL_IP_RECURSIVE=on \
  -e REAL_IP_FROM=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16 \
  erseco/alpine-php-webserver
```

`REAL_IP_RECURSIVE=on` walks the header chain past every trusted entry, which is almost always what you want.

!!! danger "Never use public CIDR ranges"
    Do not set `REAL_IP_FROM=0.0.0.0/0` or any public-range shortcut. That would let any client spoof `X-Forwarded-For`. Trust only IPs you control.

## HTTPS and public port awareness

The default Nginx server block preserves the forwarded scheme, HTTPS status, and public port for PHP:

```nginx
set $forwarded_scheme "http";
if ($http_x_forwarded_proto = "https") {
    set $forwarded_scheme "https";
}

map $http_x_forwarded_port $forwarded_server_port {
    default $server_port;
    "~^[0-9]{1,5}$" $http_x_forwarded_port;
}

fastcgi_param HTTP_X_FORWARDED_PROTO $forwarded_scheme;
fastcgi_param SERVER_PORT $forwarded_server_port;
fastcgi_param HTTPS $https if_not_empty;
```

With `X-Forwarded-Proto: https`, applications can detect the original HTTPS request. When the proxy also forwards a numeric `X-Forwarded-Port`, PHP receives that public port in `$_SERVER['SERVER_PORT']`. If the header is absent or invalid, the container listener port is used instead.

This matters when the public URL uses a non-standard port, for example `https://app.example.com:6443`, while the proxy forwards traffic internally to port `8080`.

## Traefik

Compose labels, no file changes on the Traefik side:

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

Traefik forwards `X-Forwarded-Proto` automatically and can forward `X-Forwarded-Port` for non-standard public ports. Match the upstream port — **8080**, not 80.

## Nginx (front proxy)

```nginx
server {
    listen 443 ssl http2;
    server_name app.example.com;

    ssl_certificate     /etc/letsencrypt/live/app.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/app.example.com/privkey.pem;

    client_max_body_size 100M;

    location / {
        proxy_pass         http://web:8080;
        proxy_http_version 1.1;

        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto https;
        proxy_set_header   X-Forwarded-Host  $host;
        proxy_set_header   X-Forwarded-Port  $server_port;

        proxy_read_timeout 300s;
    }
}

server {
    listen 80;
    server_name app.example.com;
    return 301 https://$host$request_uri;
}
```

Set `X-Forwarded-Port` to the actual public listener port when the frontend uses a non-standard port.

On the container side:

```yaml
environment:
  REAL_IP_HEADER: X-Forwarded-For
  REAL_IP_RECURSIVE: "on"
  REAL_IP_FROM: 10.0.0.0/8   # the internal network used between nginx and web
  client_max_body_size: 100M
```

## Apache (mod_proxy)

```apache
<VirtualHost *:443>
    ServerName app.example.com

    SSLEngine on
    SSLCertificateFile      /etc/letsencrypt/live/app.example.com/fullchain.pem
    SSLCertificateKeyFile   /etc/letsencrypt/live/app.example.com/privkey.pem

    ProxyPreserveHost On
    RequestHeader set X-Forwarded-Proto "https"
    RequestHeader set X-Forwarded-Port  "443"

    ProxyPass        / http://web:8080/
    ProxyPassReverse / http://web:8080/
</VirtualHost>
```

```bash
a2enmod proxy proxy_http ssl headers rewrite
```

## Caddy

```caddy
app.example.com {
    reverse_proxy web:8080 {
        header_up Host              {host}
        header_up X-Forwarded-Proto {scheme}
        header_up X-Forwarded-For   {remote}
    }
}
```

```yaml
environment:
  REAL_IP_HEADER: X-Forwarded-For
  REAL_IP_RECURSIVE: "on"
  REAL_IP_FROM: 172.16.0.0/12   # Docker default bridge range
```

## Cloudflare (proxied DNS)

```bash
docker run \
  -e REAL_IP_HEADER=CF-Connecting-IP \
  -e REAL_IP_RECURSIVE=on \
  -e REAL_IP_FROM=173.245.48.0/20,103.21.244.0/22,103.22.200.0/22,103.31.4.0/22,141.101.64.0/18,108.162.192.0/18,190.93.240.0/20,188.114.96.0/20,197.234.240.0/22,198.41.128.0/17,162.158.0.0/15,104.16.0.0/13,104.24.0.0/14,172.64.0.0/13,131.0.72.0/22 \
  erseco/alpine-php-webserver
```

Cloudflare sets `CF-Connecting-IP` to the real client IP on every proxied request. Use the full, current list of Cloudflare IPs:

- <https://developers.cloudflare.com/fundamentals/concepts/cloudflare-ip-addresses/>
- <https://www.cloudflare.com/ips-v4/>
- <https://www.cloudflare.com/ips-v6/>

Keep that list updated (e.g. via a cron that re-deploys the container with refreshed env vars).

## Cloudflare Tunnel / Zero Trust

When `cloudflared` runs as a sidecar or a same-network container, the only hop Nginx sees is the tunnel connector on the internal Docker network:

```yaml
environment:
  REAL_IP_HEADER: CF-Connecting-IP
  REAL_IP_RECURSIVE: "on"
  REAL_IP_FROM: 172.16.0.0/12   # tighten to the actual subnet cloudflared runs in
```

Trust only the private CIDR of your tunnel connector, not the entire Cloudflare edge.

## Checklist

Before opening a support issue:

- [ ] The proxy upstream port is `8080` (not 80, not 443).
- [ ] The proxy forwards `X-Forwarded-Proto`, `X-Forwarded-For`, and `Host`.
- [ ] For non-standard public ports, the proxy also forwards `X-Forwarded-Port`.
- [ ] `REAL_IP_FROM` lists only IPs you control.
- [ ] The PHP app reads `$_SERVER['HTTPS']`, `$_SERVER['SERVER_PORT']`, and `$_SERVER['REMOTE_ADDR']` as needed.
- [ ] `client_max_body_size` is raised if users upload large files.
