<?php
declare(strict_types=1);

require_once __DIR__ . '/config/http.php';
require_once __DIR__ . '/config/database.php';

require_once __DIR__ . '/auth/auth.php';
require_once __DIR__ . '/auth/login.php';
require_once __DIR__ . '/users/users.php';
require_once __DIR__ . '/messages/messages.php';

$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

// CORS (pratique pour tests)
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS');
if ($method === 'OPTIONS') exit;

if ($path === '/' && $method === 'GET') {
  echo "API OK 🚀";
  exit;
}

if ($path === '/health' && $method === 'GET') {
  // Vérifie DB
  try { db()->query("SELECT 1"); } catch (Throwable $e) {
    json_response(['ok' => false, 'db' => 'down'], 500);
  }
  json_response(['ok' => true]);
}

// PUBLIC: POST /auth/login {username}
if ($path === '/auth/login' && $method === 'POST') {
  $b = get_json_body();
  login_or_create_user((string)($b['username'] ?? ''));
}

// PUBLIC: POST /auth {username} (compat)
if ($path === '/auth' && $method === 'POST') {
  $b = get_json_body();
  login_or_create_user((string)($b['username'] ?? ''));
}

// Auth required
$u = auth_user();
$me = (int)$u['id'];

// GET /me
if ($path === '/me' && $method === 'GET') {
  json_response(['id' => $me, 'username' => (string)$u['username']]);
}

// GET /users
if ($path === '/users' && $method === 'GET') {
  list_users($me);
}

// GET /messages?with=ID&since=123
if ($path === '/messages' && $method === 'GET') {
  $with = int_param('with', 0);
  $since = int_param('since', 0);
  $limit = int_param('limit', 50);
  if ($with <= 0) json_response(['error' => 'Missing with'], 400);
  get_messages($me, $with, $since, $limit);
}

// POST /messages {receiver_id, content}
if ($path === '/messages' && $method === 'POST') {
  $b = get_json_body();
  $to = (int)($b['receiver_id'] ?? 0);
  $content = (string)($b['content'] ?? '');
  if ($to <= 0) json_response(['error' => 'Missing receiver_id'], 400);
  send_message($me, $to, $content);
}

// DELETE /messages/{id}  (bonus swipe)
if ($method === 'DELETE' && preg_match('#^/messages/(\\d+)$#', $path, $m)) {
  $id = (int)$m[1];
  if ($id <= 0) json_response(['error' => 'Missing id'], 400);
  delete_message($me, $id);
}

json_response(['error' => 'Not Found', 'path' => $path], 404);
