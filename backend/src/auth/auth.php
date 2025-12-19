<?php
declare(strict_types=1);

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/http.php';

function token_hash(string $token): string {
  return hash('sha256', $token);
}

function bearer_token(): ?string {
  $h = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
  if (stripos($h, 'Bearer ') !== 0) return null;
  $t = trim(substr($h, 7));
  return $t !== '' ? $t : null;
}

function create_session(int $userId): string {
  $token = bin2hex(random_bytes(32));
  $pdo = db();
  $stmt = $pdo->prepare("INSERT INTO sessions (user_id, token_hash, expires_at) VALUES (:uid, :th, DATE_ADD(NOW(), INTERVAL 7 DAY))");
  $stmt->execute([':uid' => $userId, ':th' => token_hash($token)]);
  return $token;
}

function auth_user(): array {
  $token = bearer_token();
  if (!$token) json_response(['error' => 'Unauthorized'], 401);

  $pdo = db();
  $stmt = $pdo->prepare("
    SELECT u.id, u.username, u.role
    FROM sessions s
    JOIN users u ON u.id = s.user_id
    WHERE s.token_hash = :th
      AND (s.expires_at IS NULL OR s.expires_at > NOW())
    LIMIT 1
  ");
  $stmt->execute([':th' => token_hash($token)]);
  $u = $stmt->fetch();
  if (!$u) json_response(['error' => 'Unauthorized'], 401);
  return $u;
}
