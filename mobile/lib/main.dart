import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

void main() {
  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat App CESI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5BB2FF)),
        useMaterial3: true,
      ),
      home: const ChatHome(),
    );
  }
}

class ChatHome extends StatefulWidget {
  const ChatHome({super.key});

  @override
  State<ChatHome> createState() => _ChatHomeState();
}

class _ChatHomeState extends State<ChatHome> {
  final _apiController = TextEditingController(text: 'http://localhost:8080');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _messageController = TextEditingController();

  ApiClient? _api;
  String? _token;
  int? _userId;
  String? _username;
  List<ChatUser> _users = [];
  ChatUser? _selectedUser;
  List<ChatMessage> _messages = [];
  int _lastMessageId = 0;
  Timer? _poller;
  bool _loadingUsers = false;
  bool _loadingMessages = false;
  String _status = '';
  String? _locationText;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _poller?.cancel();
    _apiController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedApi = prefs.getString('api') ?? 'http://localhost:8080';
    final savedToken = prefs.getString('token');
    final savedUserId = prefs.getInt('user_id');
    final savedUsername = prefs.getString('username');
    _apiController.text = savedApi;
    if (savedToken != null && savedUserId != null && savedUsername != null) {
      setState(() {
        _api = ApiClient(baseUrl: savedApi, token: savedToken);
        _token = savedToken;
        _userId = savedUserId;
        _username = savedUsername;
      });
      await _fetchUsers();
    }
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api', _apiController.text.trim());
    if (_token != null && _userId != null && _username != null) {
      await prefs.setString('token', _token!);
      await prefs.setInt('user_id', _userId!);
      await prefs.setString('username', _username!);
    } else {
      await prefs.remove('token');
      await prefs.remove('user_id');
      await prefs.remove('username');
    }
  }

  void _setStatus(String message) {
    setState(() => _status = message);
  }

  Future<void> _login() async {
    final api = _apiController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (api.isEmpty || username.isEmpty || password.isEmpty) {
      _setStatus('API, username et mot de passe requis.');
      return;
    }
    _setStatus('Connexion en cours...');
    try {
      final result = await ApiClient.login(api, username, password);
      setState(() {
        _api = ApiClient(baseUrl: api, token: result.token);
        _token = result.token;
        _userId = result.userId;
        _username = result.username;
        _selectedUser = null;
        _messages = [];
      });
      await _saveSession();
      await _fetchUsers();
      _setStatus('Connecte');
    } catch (err) {
      _setStatus(err.toString());
    }
  }

  Future<void> _logout() async {
    _poller?.cancel();
    setState(() {
      _api = null;
      _token = null;
      _userId = null;
      _username = null;
      _selectedUser = null;
      _messages = [];
      _lastMessageId = 0;
    });
    await _saveSession();
    _setStatus('Deconnecte');
  }

  Future<void> _fetchUsers() async {
    if (_api == null) return;
    setState(() => _loadingUsers = true);
    try {
      final users = await _api!.fetchUsers();
      setState(() => _users = users);
    } catch (err) {
      _setStatus('Erreur users: $err');
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _selectUser(ChatUser user) async {
    setState(() {
      _selectedUser = user;
      _messages = [];
      _lastMessageId = 0;
      _loadingMessages = true;
    });
    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (_api == null || _selectedUser == null) return;
    try {
      final msgs = await _api!.history(_selectedUser!.id);
      setState(() {
        _messages = msgs;
        _lastMessageId = msgs.isNotEmpty ? msgs.last.id : 0;
        _loadingMessages = false;
      });
      _startPolling();
    } catch (err) {
      _setStatus('Erreur historique: $err');
      if (mounted) setState(() => _loadingMessages = false);
    }
  }

  void _startPolling() {
    _poller?.cancel();
    _poller = Timer.periodic(const Duration(seconds: 2), (_) => _pollNew());
  }

  Future<void> _pollNew() async {
    if (_api == null || _selectedUser == null) return;
    try {
      final fresh = await _api!.newMessages(_selectedUser!.id, _lastMessageId);
      if (fresh.isNotEmpty) {
        setState(() {
          _messages.addAll(fresh);
          _lastMessageId = _messages.last.id;
        });
        _vibrate();
      }
    } catch (_) {
      // ignore poll errors
    }
  }

  Future<void> _sendMessage() async {
    if (_api == null || _selectedUser == null || _userId == null) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    try {
      final id = await _api!.sendMessage(_selectedUser!.id, text);
      final msg = ChatMessage(
        id: id,
        senderId: _userId!,
        receiverId: _selectedUser!.id,
        content: text,
        createdAt: DateTime.now(),
      );
      setState(() {
        _messages.add(msg);
        _lastMessageId = id;
        _messageController.clear();
      });
    } catch (err) {
      _setStatus('Erreur envoi: $err');
    }
  }

  Future<void> _deleteMessage(int id) async {
    if (_api == null) return;
    try {
      await _api!.deleteMessage(id);
      setState(() {
        _messages = _messages.where((m) => m.id != id).toList();
      });
    } catch (err) {
      _setStatus('Suppression impossible: $err');
    }
  }

  Future<void> _updateLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setStatus('Service GPS desactive');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        _setStatus('Permission localisation refusee');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      setState(() {
        _locationText = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      });
      _setStatus('Localisation mise a jour');
    } catch (err) {
      _setStatus('Localisation impossible: $err');
    }
  }

  Future<void> _vibrate() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 80);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat App CESI'),
        actions: [
          if (_token != null)
            IconButton(
              tooltip: 'Deconnexion',
              onPressed: _logout,
              icon: const Icon(Icons.logout),
            ),
          IconButton(
            tooltip: 'Localisation',
            onPressed: _updateLocation,
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildAuthCard(),
              const SizedBox(height: 10),
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  final vertical = constraints.maxWidth < 900;
                  if (vertical) {
                    return Column(
                      children: [
                        _buildUsersCard(height: 220),
                        const SizedBox(height: 10),
                        Expanded(child: _buildChatCard()),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      SizedBox(width: 320, child: _buildUsersCard()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildChatCard()),
                    ],
                  );
                }),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _status,
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthCard() {
    final logged = _token != null;
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('API + Auth', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _apiController,
                    decoration: const InputDecoration(labelText: 'URL API', hintText: 'http://localhost:8080'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: _fetchUsers, child: const Text('Ping users')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _login,
                  child: const Text('Login/Sign up'),
                ),
                const SizedBox(width: 8),
                if (logged) OutlinedButton(onPressed: _logout, child: const Text('Reset')),
              ],
            ),
            if (_username != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Connecte en tant que $_username (#$_userId)'),
              ),
            if (_locationText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Localisation: $_locationText'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersCard({double? height}) {
    final content = _loadingUsers
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final user = _users[index];
              final selected = _selectedUser?.id == user.id;
              return ListTile(
                selected: selected,
                title: Text(user.username),
                subtitle: Text('#${user.id}'),
                onTap: () => _selectUser(user),
              );
            },
          );
    return Card(
      elevation: 3,
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Utilisateurs', style: TextStyle(fontWeight: FontWeight.w600)),
                  IconButton(
                    tooltip: 'Rafraichir',
                    onPressed: _fetchUsers,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _users.isEmpty ? const Center(child: Text('Aucun utilisateur')) : content),
          ],
        ),
      ),
    );
  }

  Widget _buildChatCard() {
    return Card(
      elevation: 3,
      child: Column(
        children: [
          ListTile(
            title: Text(_selectedUser == null ? 'Pas de conversation' : 'Chat avec ${_selectedUser!.username}'),
            subtitle: Text(_selectedUser == null ? 'Choisis un utilisateur' : 'Historique et live every 2s'),
            trailing: _loadingMessages ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : null,
          ),
          const Divider(height: 1),
          Expanded(
            child: _selectedUser == null
                ? const Center(child: Text('Selectionne un utilisateur pour afficher les messages'))
                : _buildMessageList(),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(hintText: 'Ton message'),
                    enabled: _selectedUser != null,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selectedUser == null ? null : _sendMessage,
                  child: const Text('Envoyer'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      reverse: false,
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final mine = msg.senderId == _userId;
        final bubble = Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: mine ? Colors.blue.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: mine ? Colors.blueAccent : Colors.grey.shade400),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mine ? 'Moi' : _selectedUser?.username ?? 'Autre',
                style: TextStyle(fontWeight: FontWeight.w600, color: mine ? Colors.blue : Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(msg.content),
              const SizedBox(height: 4),
              Text(
                '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        );
        if (!mine) return bubble;
        return Dismissible(
          key: ValueKey(msg.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            color: Colors.redAccent,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => _deleteMessage(msg.id),
          child: bubble,
        );
      },
    );
  }
}

class ApiClient {
  ApiClient({required this.baseUrl, required this.token});
  final String baseUrl;
  final String token;

  Map<String, String> get _headers => {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};

  static Future<LoginResult> login(String baseUrl, String username, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    final data = _decode(res);
    if (res.statusCode != 200) throw Exception(data['error'] ?? 'Auth failed');
    return LoginResult(
      token: data['token'] as String,
      userId: (data['user_id'] as num).toInt(),
      username: data['username'] as String,
    );
  }

  Future<List<ChatUser>> fetchUsers() async {
    final res = await http.get(Uri.parse('$baseUrl/users'), headers: _headers);
    final data = _decode(res);
    if (res.statusCode != 200) throw Exception(data['error'] ?? 'Users error');
    final list = (data['users'] as List<dynamic>? ?? []);
    return list.map((e) => ChatUser.fromJson(e)).toList();
  }

  Future<List<ChatMessage>> history(int withId) async {
    final res = await http.get(Uri.parse('$baseUrl/messages/history?with=$withId&limit=50'), headers: _headers);
    final data = _decode(res);
    if (res.statusCode != 200) throw Exception(data['error'] ?? 'History error');
    final list = (data['messages'] as List<dynamic>? ?? []);
    return list.map((e) => ChatMessage.fromJson(e)).toList();
  }

  Future<List<ChatMessage>> newMessages(int withId, int sinceId) async {
    final res = await http.get(Uri.parse('$baseUrl/messages/new?with=$withId&since_id=$sinceId'), headers: _headers);
    final data = _decode(res);
    if (res.statusCode != 200) throw Exception(data['error'] ?? 'Poll error');
    final list = (data['messages'] as List<dynamic>? ?? []);
    return list.map((e) => ChatMessage.fromJson(e)).toList();
  }

  Future<int> sendMessage(int to, String content) async {
    final res = await http.post(
      Uri.parse('$baseUrl/messages/send'),
      headers: _headers,
      body: jsonEncode({'to': to, 'content': content}),
    );
    final data = _decode(res);
    if (res.statusCode != 201) throw Exception(data['error'] ?? 'Send error');
    return (data['message_id'] as num).toInt();
  }

  Future<void> deleteMessage(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/messages/delete?id=$id'), headers: _headers);
    final data = _decode(res);
    if (res.statusCode != 200) throw Exception(data['error'] ?? 'Delete error');
  }

  static Map<String, dynamic> _decode(http.Response res) {
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Reponse invalide ${res.statusCode}');
    }
  }
}

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

class LoginResult {
  LoginResult({required this.token, required this.userId, required this.username});
  final String token;
  final int userId;
  final String username;
}
