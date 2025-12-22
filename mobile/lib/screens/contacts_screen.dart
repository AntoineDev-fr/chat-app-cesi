import 'package:flutter/material.dart';

import '../models/chat_session.dart';
import '../models/chat_user.dart';
import '../services/api_client.dart';
import '../storage/session_storage.dart';
import '../theme.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, required this.session});

  final ChatSession session;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  late final ApiClient _api;
  List<ChatUser> _users = [];
  bool _loading = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _api = ApiClient(baseUrl: widget.session.baseUrl, token: widget.session.token);
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _loading = true;
      _status = '';
    });
    try {
      final users = await _api.fetchUsers();
      setState(() => _users = users);
    } catch (err) {
      setState(() => _status = 'Erreur: $err');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await SessionStorage.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String _initials(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            tooltip: 'Rafraichir',
            onPressed: _fetchUsers,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') _logout();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'logout', child: Text('Deconnexion')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchUsers,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _users.length + _extraRows,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final row = _rowType(index);
            if (row == _ContactsRow.status) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _status,
                  style: const TextStyle(color: waGreen, fontWeight: FontWeight.w600),
                ),
              );
            }
            if (row == _ContactsRow.loading) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (row == _ContactsRow.empty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Aucun utilisateur')),
              );
            }
            final user = _users[_userIndex(index)];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey.shade300,
                child: Text(
                  _initials(user.username),
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ),
              title: Text(user.username, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('ID #${user.id}', style: const TextStyle(color: Colors.black54)),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(session: widget.session, user: user),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  int get _extraRows {
    var count = 0;
    if (_status.isNotEmpty) count += 1;
    if (_users.isEmpty) count += 1;
    return count;
  }

  _ContactsRow _rowType(int index) {
    var cursor = index;
    if (_status.isNotEmpty) {
      if (cursor == 0) return _ContactsRow.status;
      cursor -= 1;
    }
    if (_users.isEmpty) {
      return _loading ? _ContactsRow.loading : _ContactsRow.empty;
    }
    return _ContactsRow.user;
  }

  int _userIndex(int index) {
    var cursor = index;
    if (_status.isNotEmpty) cursor -= 1;
    return cursor;
  }
}

enum _ContactsRow { status, loading, empty, user }
