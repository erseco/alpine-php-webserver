# Docker PHP-FPM 8.4 & Nginx 1.28 on Alpine Linux 3.23

[![Docker Pulls](https://img.shields.io/docker/pulls/erseco/alpine-php-webserver.svg)](https://hub.docker.com/r/erseco/alpine-php-webserver/)
![Docker Image Size](https://img.shields.io/docker/image-size/erseco/alpine-php-webserver)
![alpine 3.23](https://img.shields.io/badge/alpine-3.23-brightgreen.svg)
![nginx 1.28](https://img.shields.io/badge/nginx-1.28-brightgreen.svg)
![php 8.4](https://img.shields.io/badge/php-8.4-brightgreen.svg)
![License MIT](https://img.shields.io/badge/license-MIT-blue.svg)

Example PHP-FPM 8.4 & Nginx 1.28 setup for Docker, build on [Alpine Linux](https://www.alpinelinux.org/).
The image is only +/- 25MB large.

Repository: https://github.com/erseco/alpine-php-webserver

* Built on the lightweight and secure Alpine Linux distribution
* Very small Docker image size (+/-25MB)
* Uses PHP 8.4 for better performance, lower cpu usage & memory footprint
* Multi-arch support: 386, amd64, arm/v6, arm/v7, arm64, ppc64le, s390x
* Optimized for 100 concurrent users
* Optimized to only use resources when there's traffic (by using PHP-FPM's ondemand PM)
* Use of runit instead of supervisord to reduce memory footprint
* The servers Nginx, PHP-FPM run under a non-privileged user (nobody) to make it more secure
* The logs of all the services are redirected to the output of the Docker container (visible with `docker logs -f <container name>`)
* Follows the KISS principle (Keep It Simple, Stupid) to make it easy to understand and adjust the image to your needs

## Supported tags and respective Dockerfile links
<!-- supported-tags:start -->
- `latest`, `3`, `3.23`, `3.23.0` ([Dockerfile](https://github.com/erseco/alpine-php-webserver/blob/3.23.0/Dockerfile))
- `3.22`, `3.22.2` ([Dockerfile](https://github.com/erseco/alpine-php-webserver/blob/3.22.2/Dockerfile))
- `3.21`, `3.21.5` ([Dockerfile](https://github.com/erseco/alpine-php-webserver/blob/3.21.5/Dockerfile))
<!-- supported-tags:end -->

> **Note**: The `main` branch ([Dockerfile](https://github.com/erseco/alpine-php-webserver/blob/main/Dockerfile)) is automatically pushed with the tag **`beta`**.  
> Use this tag for testing purposes before stable releases are published.

## Usage

Start the Docker container:

    docker run -p 80:8080 erseco/alpine-php-webserver

See the PHP info on http://localhost, or the static html page on http://localhost/test.html

Or mount your own code to be served by PHP-FPM & Nginx

    docker run -p 80:8080 -v ~/my-codebase:/var/www/html erseco/alpine-php-webserver

## Running with Docker Compose

Easily serve your local PHP files using Docker Compose. This setup mounts your `./php` directory and binds it to port 8080 on your local machine, allowing for immediate reflection of changes in your PHP files through a web server. It's perfect for local development and testing.

### Docker Compose Configuration

Here's a simple `docker-compose.yml` example to get you started:

```yaml
services:
  webserver:
    image: erseco/alpine-php-webserver
    ports:
      - 8080:8080
    volumes:
      - ./php:/var/www/html
    restart: unless-stopped
```

- **image**: Uses `erseco/alpine-php-webserver`, optimized for PHP applications.
- **ports**: Maps port 8080 from the container to your local machine, accessible at `http://localhost:8080`.
- **volumes**: Mounts your local `./php` directory to `/var/www/html` in the container, enabling live updates to your PHP files.
- **restart**: Ensures the container automatically restarts unless manually stopped, for better reliability.

### How to Use

1. Save the above `docker-compose.yml` in your project directory.
2. Run `docker compose up -d` in your terminal, within the same directory.
3. Access your PHP application at `http://localhost:8080`.

This method ensures a seamless development process, allowing you to focus on coding rather than setup complexities.

## Adding additional daemons
You can add additional daemons (e.g. your own app) to the image by creating runit entries. You only have to write a small shell script which runs your daemon, and runit will keep it up and running for you, restarting it when it crashes, etc.

The shell script must be called `run`, must be executable, and is to be placed in the directory `/etc/service/<NAME>`.

Here's an example showing you how a memcached server runit entry can be made.

    #!/bin/sh
    ### In memcached.sh (make sure this file is chmod +x):
    # `chpst -u memcache` runs the given command as the user `memcache`.
    # If you omit that part, the command will be run as root.
    exec 2>&1 chpst -u memcache /usr/bin/memcached

    ### In Dockerfile:
    RUN mkdir /etc/service/memcached
    ADD memcached.sh /etc/service/memcached/run

Note that the shell script must run the daemon **without letting it daemonize/fork it**. Usually, daemons provide a command line flag or a config file option for that.


## Running scripts during container startup
You can set your own scripts during startup, just add your scripts in `/docker-entrypoint-init.d/`. The scripts are run in lexicographic order.

All scripts must exit correctly, e.g. with exit code 0. If any script exits with a non-zero exit code, the booting will fail.

The following example shows how you can add a startup script. This script simply logs the time of boot to the file /tmp/boottime.txt.

    #!/bin/sh
    ### In logtime.sh (make sure this file is chmod +x):
    date > /tmp/boottime.txt

    ### In Dockerfile:
    ADD logtime.sh /docker-entrypoint-init.d/logtime.sh


## Nginx Configuration

The Nginx configuration is designed to be flexible and easy to customize. By default, the main configuration file is located at `rootfs/etc/nginx/nginx.conf`. 

### Adding Custom Configurations

You can add custom configurations in two ways:

1. **Global Configurations**: Place your configuration files in `/etc/nginx/conf.d/`. These configurations are included globally and affect all server blocks.

2. **Server-Specific Configurations**: For configurations specific to a particular server block, place your files in `/etc/nginx/server-conf.d/`. These are included within the server block, allowing for more granular control.

### Example

To add a custom configuration, create a `.conf` file in the appropriate directory. For example, to add a server-specific rule, you might create a file named `custom-server.conf` in `/etc/nginx/server-conf.d/` with the following content:

```nginx
# Example custom server configuration
location /custom {
    return 200 'Custom server configuration is working!';
    add_header Content-Type text/plain;
}
```

This setup allows you to easily manage and customize your Nginx configurations without modifying the main `nginx.conf` file.
In [rootfs/etc/](rootfs/etc/) you'll find the default configuration files for Nginx, PHP and PHP-FPM.
If you want to extend or customize that you can do so by mounting a configuration file in the correct folder;

Nginx configuration:

    docker run -v "`pwd`/nginx-server.conf:/etc/nginx/conf.d/server.conf" erseco/alpine-php-webserver

PHP configuration:

    docker run -v "`pwd`/php-setting.ini:/etc/php8/conf.d/settings.ini" erseco/alpine-php-webserver

PHP-FPM configuration:

    docker run -v "`pwd`/php-fpm-settings.conf:/etc/php8/php-fpm.d/server.conf" erseco/alpine-php-webserver

## Environment variables

You can define the next environment variables to change values from NGINX and PHP

| Server | Variable Name                 | Default       | description                                                                                                                                                                                                                                  |
|--------|-------------------------------|---------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| NGINX  | nginx_root_directory          | /var/www/html | Sets the root directory for the NGINX server, which specifies the location from which files are served. This is the directory where your web application's public files should reside.                                                       |
| NGINX  | client_max_body_size          | 2m            | Sets the maximum allowed size of the client request body, specified in the “Content-Length” request header field.                                                                                                                            |
| NGINX  | fastcgi_read_timeout          | 60s           | Defines a timeout for reading a response from the FastCGI server.                                                                                                                                                                            |
| NGINX  | fastcgi_send_timeout          | 60s           | Sets a timeout for transmitting a request to the FastCGI server.                                                                                                                                                                             |
| NGINX  | DISABLE_DEFAULT_LOCATION      | false         | If set to "true", this variable disables the default `location /` block in the Nginx configuration. This allows you to mount a custom configuration in `/etc/nginx/server-conf.d/` without conflicts.                                        |
| PHP8   | clear_env                     | no            | Clear environment in FPM workers. Prevents arbitrary environment variables from reaching FPM worker processes by clearing the environment in workers before env vars specified in this pool configuration are added.                         |
| PHP8   | allow_url_fopen               | On            | Enable the URL-aware fopen wrappers that enable accessing URL object like files. Default wrappers are provided for the access of remote files using the ftp or http protocol, some extensions like zlib may register additional wrappers.    |
| PHP8   | allow_url_include             | Off           | Allow the use of URL-aware fopen wrappers with the following functions: include(), include_once(), require(), require_once().                                                                                                                |
| PHP8   | display_errors                | Off           | Determine whether errors should be printed to the screen as part of the output or if they should be hidden from the user.                                                                                                                    |
| PHP8   | file_uploads                  | On            | Whether or not to allow HTTP file uploads.                                                                                                                                                                                                   |
| PHP8   | max_execution_time            | 0             | Maximum time in seconds a script is allowed to run before it is terminated by the parser. This helps prevent poorly written scripts from tying up the server. The default setting is 30.                                                     |
| PHP8   | max_input_time                | -1            | Maximum time in seconds a script is allowed to parse input data, like POST, GET and file uploads.                                                                                                                                            |
| PHP8   | max_input_vars                | 1000          | Maximum number of input variables allowed per request and can be used to deter denial of service attacks involving hash collisions on the input variable names.                                                                              |
| PHP8   | memory_limit                  | 128M          | Maximum amount of memory in bytes that a script is allowed to allocate. This helps prevent poorly written scripts for eating up all available memory on a server. Note that to have no memory limit, set this directive to -1.               |
| PHP8   | post_max_size                 | 8M            | Max size of post data allowed. This setting also affects file upload. To upload large files, this value must be larger than upload_max_filesize. Generally speaking, memory_limit should be larger than post_max_size.                       |
| PHP8   | upload_max_filesize           | 2M            | Maximum size of an uploaded file.                                                                                                                                                                                                            |
| PHP8   | zlib_output_compression       | On            | Whether to transparently compress pages. If this option is set to "On" in php.ini or the Apache configuration, pages are compressed if the browser sends an "Accept-Encoding: gzip" or "deflate" header.                                     |
| PHP8   | date_timezone                 | UTC           | Sets the PHP timezone configuration (date.timezone) in custom.ini. Accepts standard PHP timezone identifiers (e.g., 'America/New_York', 'Europe/London'). See [PHP timezones](https://www.php.net/manual/en/timezones.php) for valid values. |
| PHP8   | intl_default_locale           | en_US         | If you want to change the [PHP locale](https://www.php.net/manual/en/class.locale.php) for the entire application or server globally (e.g. in php.ini), you can set the intl.default_locale directives (e.g. en_US or de_DE)                 |
| PHP8   | opcache_enable                | 0             | Enables/disables OPcache. Set to `1` to enable OPcache for better performance in production.                                                                                                                                                 |
| PHP8   | opcache_memory_consumption    | 256           | The size of the OPcache shared memory storage in megabytes.                                                                                                                                                                                  |
| PHP8   | opcache_max_accelerated_files | 20000         | The maximum number of keys (and files) in the OPcache hash table.                                                                                                                                                                            |
| PHP8   | opcache_validate_timestamps   | 0             | When set to `0`, OPcache doesn't check if files have changed, which is recommended for production. After each deployment, the cache must be cleared manually. Set to `1` for development.                                                    |
| PHP8   | opcache_preload               | *(empty)*     | Specifies a PHP script to be compiled and executed at server start-up, improving performance. See [PHP Preloading](https://www.php.net/manual/en/opcache.configuration.php#ini.opcache.preload). Example: `/var/www/html/config/preload.php` |
| PHP8   | realpath_cache_size           | 4096K         | The size of the realpath cache to be used by PHP.                                                                                                                                                                                            |
| PHP8   | realpath_cache_ttl            | 600           | The time-to-live for the realpath cache.                                                                                                                                                                                                     |
  
## Adding composer

If you need [Composer](https://getcomposer.org/) in your project, here's an easy way to add it.

```dockerfile
FROM erseco/alpine-php-webserver:latest
USER root
# Install composer from the official image
RUN apk add --no-cache composer
USER nobody
# Run composer install to install the dependencies
RUN composer install --optimize-autoloader --no-interaction --no-progress
```

### Building with Composer

If you are building an image that includes your source code and uses Composer to manage dependencies, it's recommended to install the dependencies during the image build process.

Although Composer (`/usr/bin/composer`) is required to install the dependencies, it does not need to remain in the final image. If you're building for production and want a leaner image, you can uninstall it after running `composer install` using `apk del`.

```Dockerfile
FROM erseco/alpine-php-webserver

# Switch to root to install Composer
USER root

# Install Composer and required tools
RUN apk add --no-cache composer

# Copy application source code
COPY ./ /var/www/html
WORKDIR /var/www/html

# Switch to a non-root user for running Composer
USER nobody

# Install PHP dependencies (requires composer.json)
RUN composer install \
    --no-dev \
    --optimize-autoloader \
    --no-interaction \
    --no-progress

# Optional: remove Composer to reduce image size
USER root
RUN apk del composer
USER nobody
```

This keeps the final image clean, reduces its size, and minimizes the available tooling that could be misused in production environments.

## Running Commands as Root

In certain situations, you might need to run commands as `root` within your Moodle container, for example, to install additional packages. You can do this using the `docker compose exec` command with the `--user root` option. Here's how:

```bash
docker compose exec --user root alpine-php-webserver sh
```
