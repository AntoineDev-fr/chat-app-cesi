import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../models/login_result.dart';

class ApiClient {
  ApiClient({required this.baseUrl, required this.token});

  final String baseUrl;
  final String token;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  static Future<LoginResult> login(String baseUrl, String username) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username}),
    );
    final data = _decodeMap(res);
    if (res.statusCode != 200) throw Exception(data['error'] ?? 'Login failed');
    final user = data['user'] as Map<String, dynamic>? ?? {};
    return LoginResult(
      token: data['token'] as String,
      userId: (user['id'] as num).toInt(),
      username: user['username'] as String,
    );
  }

  Future<List<ChatUser>> fetchUsers() async {
    final res = await http.get(Uri.parse('$baseUrl/users'), headers: _headers);
    final data = _decodeJson(res);
    if (res.statusCode != 200) {
      final error = data is Map<String, dynamic> ? data['error'] : null;
      throw Exception(error ?? 'Users error');
    }
    if (data is! List<dynamic>) throw Exception('Reponse invalide ${res.statusCode}');
    return data.map((e) => ChatUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ChatMessage>> fetchMessages({
    required int withId,
    int sinceId = 0,
    int limit = 50,
  }) async {
    final uri = Uri.parse('$baseUrl/messages').replace(
      queryParameters: {
        'with': withId.toString(),
        'since': sinceId.toString(),
        'limit': limit.toString(),
      },
    );
    final res = await http.get(uri, headers: _headers);
    final data = _decodeJson(res);
    if (res.statusCode != 200) {
      final error = data is Map<String, dynamic> ? data['error'] : null;
      throw Exception(error ?? 'Messages error');
    }
    if (data is! List<dynamic>) throw Exception('Reponse invalide ${res.statusCode}');
    return data.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ChatMessage> sendMessage({required int receiverId, required String content}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/messages'),
      headers: _headers,
      body: jsonEncode({'receiver_id': receiverId, 'content': content}),
    );
    final data = _decodeMap(res);
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception(data['error'] ?? 'Send error');
    }
    return ChatMessage.fromJson(data);
  }

  Future<void> deleteMessage(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/messages/$id'), headers: _headers);
    if (res.statusCode != 200) {
      final data = _decodeMap(res);
      throw Exception(data['error'] ?? 'Delete error');
    }
  }

  static Map<String, dynamic> _decodeMap(http.Response res) {
    final data = _decodeJson(res);
    if (data is Map<String, dynamic>) return data;
    throw Exception('Reponse invalide ${res.statusCode}');
  }

  static dynamic _decodeJson(http.Response res) {
    try {
      return jsonDecode(res.body);
    } catch (_) {
      throw Exception('Reponse invalide ${res.statusCode}');
    }
  }
}
