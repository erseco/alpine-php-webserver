<?php

header('Content-Type: application/json');

echo json_encode([
    'remote_addr' => $_SERVER['REMOTE_ADDR'] ?? null,
    'forwarded_for' => $_SERVER['HTTP_X_FORWARDED_FOR'] ?? null,
    'cf_connecting_ip' => $_SERVER['HTTP_CF_CONNECTING_IP'] ?? null,
]);
