import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cogbot/api.dart';
import 'package:cogbot/assessment_screen.dart';
import 'package:cogbot/chatmessage.dart';
import 'package:cogbot/learning.dart';
import 'package:cogbot/login.dart'; // For the global userId variable
import 'package:flutter/material.dart';

class ChatDrawer extends StatefulWidget {
  final Function(String chatId, List<ChatMessage> messages) onChatSelected;

  const ChatDrawer({Key? key, required this.onChatSelected}) : super(key: key);

  @override
  State<ChatDrawer> createState() => _ChatDrawerState();
}

class _ChatDrawerState extends State<ChatDrawer> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _previousChats = [];

  @override
  void initState() {
    super.initState();
    _loadPreviousChats();
  }

  Future<void> _loadPreviousChats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      final chatDocs = await firestore
          .collection('users')
          .doc(userId)
          .collection('chats')
          .orderBy('updated_at', descending: true)
          .get();

      final List<Map<String, dynamic>> chats = [];

      for (var doc in chatDocs.docs) {
        final data = doc.data();
        chats.add({
          'id': doc.id,
          'title': data['title'] ?? 'Untitled Chat',
          'timestamp': data['updated_at'] ?? Timestamp.now(),
        });
      }

      setState(() {
        _previousChats = chats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading previous chats: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectChat(String chatId) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final firestore = FirebaseFirestore.instance;
      final chatDoc = await firestore
          .collection('users')
          .doc(userId)
          .collection('chats')
          .doc(chatId)
          .get();

      final data = chatDoc.data();
      if (data == null || data['messages'] == null) {
        Navigator.of(context).pop(); // Close loading dialog
        widget.onChatSelected(chatId, []); // Return empty list
        Navigator.of(context).pop(); // Close drawer
        return;
      }

      if (data['messages'] is! List) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Messages field is not a list.')),
        );
        return;
      }

      final List<ChatMessage> messages =
          (data['messages'] as List).map((message) {
        final String text = message['content'] ?? '';
        final bool isUser = message['role'] == 'user';
        return ChatMessage(text: text, isUser: isUser);
      }).toList();

      Navigator.of(context).pop(); // Close loading dialog
      widget.onChatSelected(chatId, messages);
      Navigator.of(context).pop(); // Close the drawer
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading chat: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade500, Colors.deepPurple.shade200],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Learning Chats',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _loadPreviousChats,
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text('Refresh'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.deepPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => AssessmentScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.replay_outlined, size: 20),
                        label: const Text('Retake'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple.shade100,
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _previousChats.isEmpty
                    ? const Center(
                        child: Text(
                          'No previous chats found.',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _previousChats.length,
                        itemBuilder: (context, index) {
                          final chat = _previousChats[index];
                          final DateTime timestamp = chat['timestamp'].toDate();
                          final String formattedDate =
                              '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: InkWell(
                              onTap: () => _selectChat(chat['id']),
                              borderRadius: BorderRadius.circular(16),
                              child: Material(
                                elevation: 2,
                                borderRadius: BorderRadius.circular(16),
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.chat_bubble_outline,
                                        color: Colors.deepPurple,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              chat['title'],
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              formattedDate,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: Colors.deepPurple,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
