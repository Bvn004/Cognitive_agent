import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;

  const ChatMessage({super.key, required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Column( // Use Column to position the avatar and icon
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.deepPurple.shade800,
                  child: Icon(Icons.psychology, color: Colors.white), // AI avatar with icon
                ),
                const SizedBox(height: 5),
              ],
            ),
          const SizedBox(width: 10),
          Flexible( // ✅ Constrain width of message bubble
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isUser
                      ? [Colors.deepPurple.shade200, Colors.deepPurple.shade400]
                      : [Colors.white, Colors.grey.shade200],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: MarkdownBody( // ✅ Use only Markdown for consistency
                data: text,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    fontSize: 16,
                    color: isUser ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (isUser)
            CircleAvatar(
              backgroundColor: Colors.deepPurple.shade800,
              child: Icon(Icons.person, color: Colors.white),
            ),
        ],
      ),
    );
  }
}
