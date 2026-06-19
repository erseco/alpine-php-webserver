[Date]


allow_url_fopen = $allow_url_fopen
allow_url_include= $allow_url_include
display_errors= $display_errors
file_uploads= $file_uploads
max_execution_time= $max_execution_time
max_input_time= $max_input_time
max_input_vars= $max_input_vars
memory_limit= $memory_limit
post_max_size= $post_max_size
upload_max_filesize= $upload_max_filesize
zlib.output_compression= $zlib_output_compression
date.timezone= "$date_timezone"
intl.default_locale= "$intl_default_locale"

; Recommended OPcache settings for Symfony
; https://symfony.com/doc/current/performance.html

opcache.enable=$opcache_enable
opcache.enable_cli=$opcache_enable

; The amount of memory to use for OPcache, in megabytes.
opcache.memory_consumption=$opcache_memory_consumption

; The maximum number of files to cache.
opcache.max_accelerated_files=$opcache_max_accelerated_files

; How often to check for changed files, in seconds.
; 1 means always check, which is ideal for development.
; In production, you should set this to 0 and use a cache warmer.
opcache.validate_timestamps=$opcache_validate_timestamps

; If enabled, OPcache will save comments from PHP source files.
; This is required for some libraries, like Doctrine Annotations.
opcache.save_comments=1

; Preloading configuration
opcache.preload=$opcache_preload
opcache.preload_user=nobody

; Realpath cache configuration
realpath_cache_size=$realpath_cache_size
realpath_cache_ttl=$realpath_cache_ttl
