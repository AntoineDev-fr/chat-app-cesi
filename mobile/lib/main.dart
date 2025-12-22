import 'package:flutter/material.dart';

import 'models/chat_session.dart';
import 'screens/contacts_screen.dart';
import 'screens/login_screen.dart';
import 'storage/session_storage.dart';
import 'theme.dart';

void main() {
  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhatsApp CESI',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      home: const AppBootstrap(),
    );
  }
}

class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ChatSession?>(
      future: SessionStorage.load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final session = snapshot.data;
        if (session == null) {
          return const LoginScreen();
        }
        return ContactsScreen(session: session);
      },
    );
  }
}
