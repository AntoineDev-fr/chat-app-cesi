<?php
declare(strict_types=1);

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/http.php';
require_once __DIR__ . '/auth.php';

function validate_username(string $username): string {
  $username = trim($username);
  if ($username === '' || !preg_match('/^[a-zA-Z0-9_.-]{3,32}$/', $username)) {
    json_response(['error' => 'Invalid username'], 400);
  }
  return $username;
}

function login_or_create_user(string $username): void {
  $username = validate_username($username);
  $pdo = db();

  $stmt = $pdo->prepare("SELECT id FROM users WHERE username = :u LIMIT 1");
  $stmt->execute([':u' => $username]);
  $row = $stmt->fetch();

  if (!$row) {
    $ins = $pdo->prepare("INSERT INTO users (username) VALUES (:u)");
    $ins->execute([':u' => $username]);
    $userId = (int)$pdo->lastInsertId();
  } else {
    $userId = (int)$row['id'];
  }

  $token = create_session($userId);
  json_response(['user' => ['id' => $userId, 'username' => $username], 'token' => $token]);
}
