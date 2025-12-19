<?php
declare(strict_types=1);

function db(): PDO {
  static $pdo = null;
  if ($pdo instanceof PDO) return $pdo;

  $host = getenv('DB_HOST') ?: 'db';
  $name = getenv('DB_NAME') ?: 'chatdb';
  $user = getenv('DB_USER') ?: 'chatuser';
  $pass = getenv('DB_PASS') ?: 'chatpass';

  $dsn = "mysql:host={$host};dbname={$name};charset=utf8mb4";
  $pdo = new PDO($dsn, $user, $pass, [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
  ]);
  return $pdo;
}
