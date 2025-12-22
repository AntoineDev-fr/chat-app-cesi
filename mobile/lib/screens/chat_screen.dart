import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../models/chat_user.dart';
import '../services/api_client.dart';
import '../theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.session, required this.user});

  final ChatSession session;
  final ChatUser user;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ApiClient _api;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  int _lastMessageId = 0;
  Timer? _poller;
  bool _loading = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _api = ApiClient(baseUrl: widget.session.baseUrl, token: widget.session.token);
    _loadHistory();
  }

  @override
  void dispose() {
    _poller?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _status = '';
    });
    try {
      final msgs = await _api.fetchMessages(withId: widget.user.id, sinceId: 0, limit: 50);
      setState(() {
        _messages = msgs;
        _lastMessageId = msgs.isNotEmpty ? msgs.last.id : 0;
      });
      _startPolling();
      _scrollToBottom();
    } catch (err) {
      setState(() => _status = 'Erreur: $err');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startPolling() {
    _poller?.cancel();
    _poller = Timer.periodic(const Duration(seconds: 5), (_) => _pollNew());
  }

  Future<void> _pollNew() async {
    try {
      final fresh = await _api.fetchMessages(withId: widget.user.id, sinceId: _lastMessageId, limit: 200);
      if (fresh.isNotEmpty) {
        setState(() {
          _messages.addAll(fresh);
          _lastMessageId = _messages.last.id;
        });
        _scrollToBottom();
      }
    } catch (_) {
      // ignore poll errors
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    try {
      final msg = await _api.sendMessage(receiverId: widget.user.id, content: text);
      setState(() {
        _messages.add(msg);
        _lastMessageId = msg.id;
        _messageController.clear();
      });
      _scrollToBottom();
    } catch (err) {
      setState(() => _status = 'Erreur envoi: $err');
    }
  }

  Future<void> _deleteMessage(ChatMessage msg) async {
    try {
      await _api.deleteMessage(msg.id);
      setState(() {
        _messages = _messages.where((m) => m.id != msg.id).toList();
      });
    } catch (err) {
      setState(() => _status = 'Suppression impossible: $err');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.user.username),
      ),
      body: Column(
        children: [
          if (_loading)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.white,
              color: waAccent,
            ),
          Expanded(
            child: Container(
              color: waChatBg,
              child: _messages.isEmpty
                  ? Center(
                      child: Text(
                        _status.isEmpty ? 'Aucun message' : _status,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final mine = msg.senderId == widget.session.userId;
                        final bubble = _buildMessageBubble(context, msg, mine);
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
                          onDismissed: (_) => _deleteMessage(msg),
                          child: bubble,
                        );
                      },
                    ),
            ),
          ),
          if (_status.isNotEmpty && _messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _status,
                  style: const TextStyle(color: waGreen, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Message',
                filled: true,
                fillColor: Color(0xFFF7F7F7),
                prefixIcon: Icon(Icons.emoji_emotions_outlined),
                suffixIcon: Icon(Icons.attach_file),
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                  borderSide: BorderSide(color: Colors.black12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                  borderSide: BorderSide(color: Colors.black12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                  borderSide: BorderSide(color: waGreen, width: 1.2),
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: waAccent,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send),
              color: Colors.white,
              tooltip: 'Envoyer',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, ChatMessage msg, bool mine) {
    final bubbleColor = mine ? waOutgoing : waIncoming;
    final alignment = mine ? Alignment.centerRight : Alignment.centerLeft;
    final maxWidth = MediaQuery.of(context).size.width * 0.7;
    final cappedWidth = maxWidth > 520 ? 520.0 : maxWidth;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(mine ? 16 : 4),
      bottomRight: Radius.circular(mine ? 4 : 16),
    );
    final time = _formatTime(msg.createdAt);

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cappedWidth),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                msg.content,
                style: const TextStyle(fontSize: 15, height: 1.3),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  time,
                  style: const TextStyle(fontSize: 11, color: waMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
