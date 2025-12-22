import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/chat_session.dart';

class SessionStorage {
  static const _apiKey = 'api';
  static const _tokenKey = 'token';
  static const _userIdKey = 'user_id';
  static const _usernameKey = 'username';

  static Future<String> loadApi() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKey) ?? defaultApiBaseUrl;
  }

  static Future<ChatSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final api = prefs.getString(_apiKey) ?? defaultApiBaseUrl;
    final token = prefs.getString(_tokenKey);
    final userId = prefs.getInt(_userIdKey);
    final username = prefs.getString(_usernameKey);
    if (token != null && userId != null && username != null) {
      return ChatSession(baseUrl: api, token: token, userId: userId, username: username);
    }
    return null;
  }

  static Future<void> save(ChatSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKey, session.baseUrl);
    await prefs.setString(_tokenKey, session.token);
    await prefs.setInt(_userIdKey, session.userId);
    await prefs.setString(_usernameKey, session.username);
  }

  static Future<void> saveApi(String api) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKey, api);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
  }
}
