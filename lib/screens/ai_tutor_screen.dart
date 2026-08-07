import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

class AiTutorScreen extends StatefulWidget {
  const AiTutorScreen({Key? key}) : super(key: key);

  @override
  _AiTutorScreenState createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends State<AiTutorScreen> {
  final ApiClient _apiClient = ApiClient();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<Map<String, String>> _messages = [
    {
      'role': 'assistant',
      'content': 'Hi there! I am your AI Homework Assistant. What can I help you learn today?'
    }
  ];
  
  bool _isTyping = false;

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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isTyping = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final chatHistory = _messages.where((m) => m['role'] != 'system').toList();
      
      final response = await _apiClient.post('/student/ai/ask', {
        'prompt': text,
        'chat_history': chatHistory.take(chatHistory.length - 1).toList(), // Exclude the just-added prompt
      });

      if (response['response'] != null) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': response['response']});
        });
      } else {
        throw Exception('Invalid response from server');
      }
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': 'Sorry, I am having trouble connecting to my brain right now! Please try again later.'
        });
      });
    } finally {
      setState(() {
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.auto_awesome, color: Colors.amber),
            SizedBox(width: 8),
            Text('AI Tutor'),
          ],
        ),
        backgroundColor: const Color(0xFF242B31),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return _buildTypingIndicator();
                }
                
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                
                return _buildMessageBubble(msg['content']!, isUser);
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF3B82F6) : Colors.white,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(20),
            bottomLeft: !isUser ? const Radius.circular(0) : const Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF1F2937),
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomLeft: const Radius.circular(0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text(
              'Thinking...',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 10,
          )
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Ask a homework question...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                onPressed: _isTyping ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
