<?php
declare(strict_types=1);

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/http.php';

function get_messages(int $me, int $with, int $sinceId, int $limit): void {
  $pdo = db();
  $sinceId = max(0, $sinceId);
  $limit = max(1, min(200, $limit));

  if ($sinceId > 0) {
    $stmt = $pdo->prepare("
      SELECT id, sender_id, receiver_id, content, created_at
      FROM messages
      WHERE deleted_at IS NULL
        AND id > :since
        AND (
          (sender_id = :me AND receiver_id = :with)
          OR (sender_id = :with AND receiver_id = :me)
        )
      ORDER BY id ASC
      LIMIT {$limit}
    ");
    $stmt->execute([':since' => $sinceId, ':me' => $me, ':with' => $with]);
    json_response($stmt->fetchAll());
  }

  $stmt = $pdo->prepare("
    SELECT id, sender_id, receiver_id, content, created_at
    FROM messages
    WHERE deleted_at IS NULL
      AND (
        (sender_id = :me AND receiver_id = :with)
        OR (sender_id = :with AND receiver_id = :me)
      )
    ORDER BY id DESC
    LIMIT {$limit}
  ");
  $stmt->execute([':me' => $me, ':with' => $with]);
  $rows = array_reverse($stmt->fetchAll());
  json_response($rows);
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
  $messageId = (int)$pdo->lastInsertId();

  $fetch = $pdo->prepare("
    SELECT id, sender_id, receiver_id, content, created_at
    FROM messages
    WHERE id = :id
    LIMIT 1
  ");
  $fetch->execute([':id' => $messageId]);
  $row = $fetch->fetch();
  if (!$row) {
    $row = [
      'id' => $messageId,
      'sender_id' => $me,
      'receiver_id' => $to,
      'content' => $content,
      'created_at' => gmdate('Y-m-d H:i:s'),
    ];
  }
  json_response($row, 201);
}

function delete_message(int $me, int $messageId): void {
  $messageId = max(1, $messageId);
  $pdo = db();

  $stmt = $pdo->prepare("UPDATE messages SET deleted_at = NOW() WHERE id = :id AND sender_id = :me AND deleted_at IS NULL");
  $stmt->execute([':id' => $messageId, ':me' => $me]);

  if ($stmt->rowCount() === 0) {
    json_response(['error' => 'Not found or not allowed'], 404);
  }
  json_response(['ok' => true]);
}
