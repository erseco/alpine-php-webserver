<?php

$expected_extensions = [
    'ctype',
    'curl',
    'dom',
    'exif',
    'fileinfo',
    'gd',
    'iconv',
    'intl',
    'json',
    'mbstring',
    'mysqli',
    'opcache',
    'openssl',
    'apcu',
    'pdo',
    'pdo_mysql',
    'pgsql',
    'phar',
    'session',
    'simplexml',
    'soap',
    'sodium',
    'tokenizer',
    'xml',
    'xmlreader',
    'zip',
    'zlib',
];

$missing_extensions = [];

foreach ($expected_extensions as $extension) {
    if (!extension_loaded($extension)) {
        $missing_extensions[] = $extension;
    }
}

if (empty($missing_extensions)) {
    echo "All expected PHP extensions are loaded.\n";
    exit(0);
} else {
    fwrite(STDERR, "Missing PHP extensions: " . implode(', ', $missing_extensions) . "\n");
    exit(1);
}