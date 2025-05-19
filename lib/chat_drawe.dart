import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cogbot/api.dart';
import 'package:cogbot/assessment_screen.dart';
import 'package:cogbot/chatmessage.dart';
import 'package:cogbot/login.dart';
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
    setState(() => _isLoading = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final chatDocs = await firestore
          .collection('users')
          .doc(userId)
          .collection('chats')
          .orderBy('updated_at', descending: true)
          .get();

      final List<Map<String, dynamic>> chats = chatDocs.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Untitled Chat',
          'timestamp': data['updated_at'] ?? Timestamp.now(),
        };
      }).toList();

      setState(() {
        _previousChats = chats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading previous chats: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectChat(String chatId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('chats')
          .doc(chatId)
          .get();

      final data = doc.data();
      Navigator.of(context).pop();

      if (data == null || data['messages'] is! List) {
        widget.onChatSelected(chatId, []);
        Navigator.of(context).pop();
        return;
      }

      final messages = (data['messages'] as List).map((m) {
        return ChatMessage(
          text: m['content'] ?? '',
          isUser: m['role'] == 'user',
        );
      }).toList();

      widget.onChatSelected(chatId, messages);
      Navigator.of(context).pop();
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading chat: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFF8F9FD),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Chats',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF333366),
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
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.deepPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AssessmentScreen()),
                          );
                        },
                        icon: const Icon(Icons.replay),
                        label: const Text('Retake'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.indigo,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
                : _previousChats.isEmpty
                    ? const Center(
                        child: Text(
                          'No previous chats found.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        itemCount: _previousChats.length,
                        itemBuilder: (context, index) {
                          final chat = _previousChats[index];
                          final timestamp = chat['timestamp'].toDate();
                          final formattedDate =
                              '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';

                          return GestureDetector(
                            onTap: () => _selectChat(chat['id']),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                                border: Border.all(color: Colors.deepPurple.shade100),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.chat_bubble_outline,
                                      color: Colors.deepPurple),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          chat['title'],
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2A2A2A),
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
                                  const Icon(Icons.arrow_forward_ios,
                                      size: 16, color: Colors.deepPurple),
                                ],
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
