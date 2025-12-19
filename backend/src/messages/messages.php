<?php
declare(strict_types=1);

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/http.php';

function get_history(int $me, int $with, int $limit): void {
  $pdo = db();
  $limit = max(1, min(200, $limit));

  $stmt = $pdo->prepare("
    SELECT id, sender_id, receiver_id, content, created_at
    FROM messages
    WHERE (sender_id = :me AND receiver_id = :with)
       OR (sender_id = :with AND receiver_id = :me)
    ORDER BY id DESC
    LIMIT {$limit}
  ");
  $stmt->execute([':me' => $me, ':with' => $with]);
  $rows = array_reverse($stmt->fetchAll());
  json_response(['messages' => $rows]);
}

function get_new(int $me, int $with, int $sinceId): void {
  $pdo = db();
  $sinceId = max(0, $sinceId);

  $stmt = $pdo->prepare("
    SELECT id, sender_id, receiver_id, content, created_at
    FROM messages
    WHERE id > :since
      AND (
        (sender_id = :me AND receiver_id = :with)
        OR (sender_id = :with AND receiver_id = :me)
      )
    ORDER BY id ASC
    LIMIT 200
  ");
  $stmt->execute([':since' => $sinceId, ':me' => $me, ':with' => $with]);
  json_response(['messages' => $stmt->fetchAll()]);
}

function send_message(int $me, int $to, string $content): void {
  $content = trim($content);
  if ($content === '' || mb_strlen($content) > 2000) {
    json_response(['error' => 'Invalid content'], 400);
  }

  $pdo = db();
  $chk = $pdo->prepare("SELECT id FROM users WHERE id = :id LIMIT 1");
  $chk->execute([':id' => $to]);
  if (!$chk->fetch()) json_response(['error' => 'Receiver not found'], 404);

  $stmt = $pdo->prepare("INSERT INTO messages (sender_id, receiver_id, content) VALUES (:s, :r, :c)");
  $stmt->execute([':s' => $me, ':r' => $to, ':c' => $content]);

  json_response(['ok' => true, 'message_id' => (int)$pdo->lastInsertId()], 201);
}

function delete_message(int $me, int $messageId): void {
  $messageId = max(1, $messageId);
  $pdo = db();

  $stmt = $pdo->prepare("DELETE FROM messages WHERE id = :id AND sender_id = :me");
  $stmt->execute([':id' => $messageId, ':me' => $me]);

  if ($stmt->rowCount() === 0) {
    json_response(['error' => 'Not found or not allowed'], 404);
  }
  json_response(['ok' => true]);
}
