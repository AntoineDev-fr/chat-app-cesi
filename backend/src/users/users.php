<?php
declare(strict_types=1);

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/http.php';

function list_users(int $excludeId): void {
  $pdo = db();
  $stmt = $pdo->prepare("SELECT id, username FROM users WHERE id != :id ORDER BY username ASC");
  $stmt->execute([':id' => $excludeId]);
  json_response(['users' => $stmt->fetchAll()]);
}
