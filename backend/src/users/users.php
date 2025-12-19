<?php
header("Content-Type: application/json");
require_once "../config/database.php";

$stmt = $pdo->query("SELECT id, username FROM users");
$users = $stmt->fetchAll();

echo json_encode($users);
