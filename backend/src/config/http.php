<?php
declare(strict_types=1);

function json_response(array $data, int $status = 200): void {
  http_response_code($status);
  header('Content-Type: application/json; charset=utf-8');
  echo json_encode($data, JSON_UNESCAPED_UNICODE);
  exit;
}

function get_json_body(): array {
  $raw = file_get_contents('php://input') ?: '';
  if ($raw === '') return [];
  $data = json_decode($raw, true);
  return is_array($data) ? $data : [];
}

function int_param(string $key, int $default = 0): int {
  return isset($_GET[$key]) ? (int)$_GET[$key] : $default;
}

function str_param(string $key, string $default = ''): string {
  return isset($_GET[$key]) ? (string)$_GET[$key] : $default;
}
