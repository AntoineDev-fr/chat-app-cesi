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

// PUBLIC: POST /auth {username,password}
if ($path === '/auth' && $method === 'POST') {
  $b = get_json_body();
  login_or_register((string)($b['username'] ?? ''), (string)($b['password'] ?? ''));
}

// Auth required
$u = auth_user();
$me = (int)$u['id'];

// GET /me
if ($path === '/me' && $method === 'GET') {
  json_response(['id' => $me, 'username' => (string)$u['username'], 'role' => (string)$u['role']]);
}

// GET /users
if ($path === '/users' && $method === 'GET') {
  list_users($me);
}

// GET /messages/history?with=ID&limit=50
if ($path === '/messages/history' && $method === 'GET') {
  $with = int_param('with', 0);
  $limit = int_param('limit', 50);
  if ($with <= 0) json_response(['error' => 'Missing with'], 400);
  get_history($me, $with, $limit);
}

// GET /messages/new?with=ID&since_id=123
if ($path === '/messages/new' && $method === 'GET') {
  $with = int_param('with', 0);
  $since = int_param('since_id', 0);
  if ($with <= 0) json_response(['error' => 'Missing with'], 400);
  get_new($me, $with, $since);
}

// POST /messages/send {to, content}
if ($path === '/messages/send' && $method === 'POST') {
  $b = get_json_body();
  $to = (int)($b['to'] ?? 0);
  $content = (string)($b['content'] ?? '');
  if ($to <= 0) json_response(['error' => 'Missing to'], 400);
  send_message($me, $to, $content);
}

// DELETE /messages/delete?id=123  (bonus swipe)
if ($path === '/messages/delete' && $method === 'DELETE') {
  $id = int_param('id', 0);
  if ($id <= 0) json_response(['error' => 'Missing id'], 400);
  delete_message($me, $id);
}

json_response(['error' => 'Not Found', 'path' => $path], 404);
