ARG ARCH=
FROM ${ARCH}alpine:3.24

LABEL org.opencontainers.image.authors="Ernesto Serrano <info@ernesto.es>" \
      org.opencontainers.image.description="Lightweight container with Nginx & PHP-FPM based on Alpine Linux."

# Set pipefail to catch errors in piped commands
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# Install packages
# Note: PHP 8.5 bundles OPcache into core, so there is no separate php85-opcache
# package; json and zlib are likewise provided by the php85 core package.
RUN apk --no-cache add \
        php85 \
        php85-ctype \
        php85-curl \
        php85-dom \
        php85-exif \
        php85-fileinfo \
        php85-fpm \
        php85-gd \
        php85-iconv \
        php85-intl \
        php85-json \
        php85-mbstring \
        php85-mysqli \
        php85-openssl \
        php85-pecl-apcu \
        php85-pdo \
        php85-pdo_mysql \
        php85-pgsql \
        php85-phar \
        php85-session \
        php85-simplexml \
        php85-soap \
        php85-sodium \
        php85-sqlite3 \
        php85-tokenizer \
        php85-xml \
        php85-xmlreader \
        php85-zip \
        php85-zlib \
        nginx \
        runit \
        curl \
# Bring in gettext so we can get `envsubst`, then throw
# the rest away. To do this, we need to install `gettext`
# then move `envsubst` out of the way so `gettext` can
# be deleted completely, then move `envsubst` back.
    && apk add --no-cache --virtual .gettext gettext \
    && mv /usr/bin/envsubst /tmp/ \
    && runDeps="$( \
        scanelf --needed --nobanner /tmp/envsubst \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
    )" \
    && apk add --no-cache $runDeps \
    && apk del .gettext \
    && mv /tmp/envsubst /usr/local/bin/ \
# Remove alpine cache
    && rm -rf /var/cache/apk/* \
# Remove default server definition
    && rm /etc/nginx/http.d/default.conf \
# Make sure files/folders needed by the processes are accessable when they run under the nobody user
    && mkdir -p /run /var/lib/nginx /var/www/html /var/log/nginx \
    && chown -R nobody:nobody /run /var/lib/nginx /var/www/html /var/log/nginx

# Add configuration files
COPY --chown=nobody rootfs/ /

# Switch to use a non-root user from here on
USER nobody

# Add application
WORKDIR /var/www/html

# Expose the port nginx is reachable on
EXPOSE 8080

# Let runit start nginx & php-fpm
# Ensure /bin/docker-entrypoint.sh is always executed
ENTRYPOINT ["/bin/docker-entrypoint.sh"]


# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping || exit 1

ENV nginx_root_directory=/var/www/html \
    client_max_body_size=2M \
    clear_env=no \
    allow_url_fopen=On \
    allow_url_include=Off \
    display_errors=Off \
    file_uploads=On \
    max_execution_time=0 \
    max_input_time=-1 \
    max_input_vars=1000 \
    memory_limit=128M \
    post_max_size=8M \
    upload_max_filesize=2M \
    zlib_output_compression=On \
    date_timezone=UTC \
    intl_default_locale=en_US \
    fastcgi_read_timeout=60s \
    fastcgi_send_timeout=60s \
    REAL_IP_HEADER=X-Forwarded-For \
    REAL_IP_RECURSIVE=off \
    REAL_IP_FROM="" \
    # Recommended OPcache settings for Symfony
    opcache_enable=0 \
    opcache_memory_consumption=256 \
    opcache_max_accelerated_files=20000 \
    opcache_validate_timestamps=0 \
    opcache_preload="" \
    realpath_cache_size=4096K \
    realpath_cache_ttl=600
