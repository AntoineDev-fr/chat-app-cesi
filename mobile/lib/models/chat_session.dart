class ChatSession {
  ChatSession({
    required this.baseUrl,
    required this.token,
    required this.userId,
    required this.username,
  });

  final String baseUrl;
  final String token;
  final int userId;
  final String username;
}
