import 'package:flutter/material.dart';

import '../models/chat_session.dart';
import '../services/api_client.dart';
import '../storage/session_storage.dart';
import '../theme.dart';
import 'contacts_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _apiController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _loading = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadApi();
  }

  @override
  void dispose() {
    _apiController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadApi() async {
    final api = await SessionStorage.loadApi();
    if (!mounted) return;
    setState(() => _apiController.text = api);
  }

  void _setStatus(String message) {
    setState(() => _status = message);
  }

  Future<void> _submit() async {
    if (_loading) return;
    final api = _apiController.text.trim();
    final username = _usernameController.text.trim();
    if (api.isEmpty || username.isEmpty) {
      _setStatus('URL API et username requis.');
      return;
    }
    setState(() {
      _loading = true;
      _status = 'Connexion en cours...';
    });
    try {
      await SessionStorage.saveApi(api);
      final result = await ApiClient.login(api, username);
      final session = ChatSession(
        baseUrl: api,
        token: result.token,
        userId: result.userId,
        username: result.username,
      );
      await SessionStorage.save(session);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ContactsScreen(session: session)),
      );
    } catch (err) {
      _setStatus(err.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: waGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 32),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'WhatsApp CESI',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Connecte-toi pour acceder a tes conversations.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _apiController,
                            enabled: !_loading,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'URL API',
                              hintText: 'http://10.0.2.2:8080',
                              prefixIcon: Icon(Icons.link),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _usernameController,
                            enabled: !_loading,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.person),
                            ),
                            onSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Se connecter'),
                            ),
                          ),
                          if (_status.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                _status,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: waGreen, fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'En continuant, tu acceptes les conditions d\'utilisation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
