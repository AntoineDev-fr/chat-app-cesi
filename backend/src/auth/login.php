<?php
declare(strict_types=1);

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/http.php';
require_once __DIR__ . '/auth.php';

function login_or_register(string $username, string $password): void {
  $username = trim($username);

  if ($username === '' || !preg_match('/^[a-zA-Z0-9_.-]{3,32}$/', $username)) {
    json_response(['error' => 'Invalid username'], 400);
  }
  if (strlen($password) < 6 || strlen($password) > 200) {
    json_response(['error' => 'Invalid password'], 400);
  }

  $pdo = db();
  $stmt = $pdo->prepare("SELECT id, password_hash FROM users WHERE username = :u LIMIT 1");
  $stmt->execute([':u' => $username]);
  $row = $stmt->fetch();

  if (!$row) {
    $hash = password_hash($password, PASSWORD_BCRYPT);
    $ins = $pdo->prepare("INSERT INTO users (username, password_hash, role) VALUES (:u, :p, 'user')");
    $ins->execute([':u' => $username, ':p' => $hash]);
    $userId = (int)$pdo->lastInsertId();
  } else {
    $userId = (int)$row['id'];
    if (!password_verify($password, (string)$row['password_hash'])) {
      json_response(['error' => 'Invalid credentials'], 401);
    }
  }

  $token = create_session($userId);
  json_response(['token' => $token, 'user_id' => $userId, 'username' => $username]);
}
