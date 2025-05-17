import 'package:cogbot/api.dart';
import 'package:cogbot/chat_drawe.dart';
import 'package:cogbot/chatmessage.dart';
import 'package:cogbot/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Learning_Chat extends StatefulWidget {
  const Learning_Chat({super.key});

  @override
  State<Learning_Chat> createState() => _Learning_ChatState();
}

class _Learning_ChatState extends State<Learning_Chat> {
  // Move these variables inside the class as instance variables
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isInitialTopic = true;
  String? _currentChatId;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;
    _textController.clear();

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      Map<String, dynamic> response;
      bool wasInitialTopic = _isInitialTopic;

      if (wasInitialTopic) {
        response = await topicToLearn(userId: userId!, concept: text);
        _currentChatId = response['chat_id'];
        _isInitialTopic = false;
      } else {
        response = await sendFollowUpQuestion(
          userId: userId!,
          chatId: _currentChatId!,
          message: text,
        );
      }

      final botResponse = wasInitialTopic
          ? (response['output'] ?? "Sorry, I couldn't find information on that topic.")
          : (response['response'] ?? "Sorry, I couldn't process your follow-up question.");

      setState(() {
        _messages.add(ChatMessage(text: botResponse, isUser: false));
        _isLoading = false;
      });
    } catch (e) {
      final errorMessage = "Error: ${e.toString()}";
      setState(() {
        _messages.add(ChatMessage(text: errorMessage, isUser: false));
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _loadChat(String chatId, List<ChatMessage> messages) {
    List<ChatMessage> filteredMessages = messages
        .skipWhile((message) => !message.isUser && message.text.startsWith('Profile:'))
        .toList();

    setState(() {
      _currentChatId = chatId;
      _messages.clear(); // Clear existing messages first
      _messages.addAll(filteredMessages); // Then add the loaded messages
      _isInitialTopic = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: ChatDrawer(onChatSelected: _loadChat),
      appBar: AppBar(
        title: Text(
          _isInitialTopic ? 'Start Learning' : 'Your Learning Session',
          style: const TextStyle(fontWeight: FontWeight.bold,color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple.shade800,
        elevation: 2,
        actions: [
          if (!_isInitialTopic)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                setState(() {
                  _messages.clear();
                  _isInitialTopic = true;
                  _currentChatId = null;
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _messages[index],
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          const Divider(height: 1.0),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16), // Bottom padding to raise input
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.deepPurple.shade200),
                    ),
                    child: TextField(
                      controller: _textController,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        hintText: _isInitialTopic
                            ? 'Enter a topic to learn...'
                            : 'Ask a follow-up question...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: _isLoading ? null : _handleSubmitted,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: Colors.deepPurple.shade800,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _isLoading
                        ? null
                        : () => _handleSubmitted(_textController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Properly dispose controllers when leaving the screen
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
