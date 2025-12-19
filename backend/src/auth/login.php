<?php
header("Content-Type: application/json");
require_once "../config/database.php";

$data = json_decode(file_get_contents("php://input"), true);

if (!isset($data["username"], $data["password"])) {
    http_response_code(400);
    echo json_encode(["error" => "Missing fields"]);
    exit;
}

$username = trim($data["username"]);
$password = $data["password"];

// Recherche utilisateur
$stmt = $pdo->prepare("SELECT * FROM users WHERE username = ?");
$stmt->execute([$username]);
$user = $stmt->fetch();

if ($user) {
    // Login
    if (!password_verify($password, $user["password"])) {
        http_response_code(401);
        echo json_encode(["error" => "Invalid password"]);
        exit;
    }
} else {
    // Register
    $hash = password_hash($password, PASSWORD_DEFAULT);
    $stmt = $pdo->prepare("INSERT INTO users (username, password) VALUES (?, ?)");
    $stmt->execute([$username, $hash]);

    $user = [
        "id" => $pdo->lastInsertId(),
        "username" => $username
    ];
}

echo json_encode([
    "id" => $user["id"],
    "username" => $user["username"]
]);
