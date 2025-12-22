class ChatMessage {
  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.createdAt,
  });

  final int id;
  final int senderId;
  final int receiverId;
  final String content;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] as num).toInt(),
      senderId: (json['sender_id'] as num).toInt(),
      receiverId: (json['receiver_id'] as num).toInt(),
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
