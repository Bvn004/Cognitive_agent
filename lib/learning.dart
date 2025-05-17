import 'package:cogbot/api.dart';
import 'package:cogbot/chat_drawe.dart';
import 'package:cogbot/chatmessage.dart';
import 'package:cogbot/login.dart'; // This should have the global `userId` variable
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
    // Optionally, load the last active chat or start with an empty state
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
        // The backend should handle saving the initial message and response
      } else {
        response = await sendFollowUpQuestion(
          userId: userId!,
          chatId: _currentChatId!,
          message: text,
        );
        // The backend should handle saving the follow-up question and response
      }

      final botResponse =
          wasInitialTopic
              ? (response['output'] ??
                  "Sorry, I couldn't find information on that topic.")
              : (response['response'] ??
                  "Sorry, I couldn't process your follow-up question.");

      setState(() {
        _messages.add(ChatMessage(text: botResponse, isUser: false));
        _isLoading = false;
      });
    } catch (e) {
      final errorMessage =
          "Sorry, there was an error processing your request: ${e.toString()}";
      setState(() {
        _messages.add(ChatMessage(text: errorMessage, isUser: false));
        _isLoading = false;
      });
      // The backend should handle saving the error message if needed
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
    // Filter out the first message if it's the profile initialization
    List<ChatMessage> filteredMessages =
        messages
            .skipWhile(
              (message) =>
                  !message.isUser && message.text.startsWith('Profile:'),
            )
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
          _isInitialTopic ? 'Start Learning' : '', // More dynamic title
        ),
        backgroundColor: const Color.fromARGB(255, 143, 143, 143),
        elevation: 0,
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
              tooltip: 'Start New Topic',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _messages[index],
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          const Divider(height: 1.0),
          Container(
            decoration: BoxDecoration(color: Theme.of(context).cardColor),
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText:
                          _isInitialTopic
                              ? 'Enter a topic to learn...'
                              : 'Ask a follow-up question...',
                      border: InputBorder.none,
                    ),
                    onSubmitted:
                        _isLoading ? null : (text) => _handleSubmitted(text),
                    enabled: !_isLoading,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed:
                      _isLoading
                          ? null
                          : () => _handleSubmitted(_textController.text),
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
