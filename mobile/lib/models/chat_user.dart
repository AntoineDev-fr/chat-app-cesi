class ChatUser {
  ChatUser({required this.id, required this.username});

  final int id;
  final String username;

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String,
    );
  }
}
