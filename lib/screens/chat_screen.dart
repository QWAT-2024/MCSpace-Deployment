import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  GenerativeModel? _model;
  bool _isLoading = false;

  Future<void> _initGemini() async {
    final systemInstruction = Content.system(
      'You are the AI Assistant for "MC Space". '
      'You are an expert in mechanical engineering, industrial machines, heavy equipment, and spare parts. '
      'Your goal is to assist users with technical questions about machine maintenance, part specifications, troubleshooting, and assembly. '
      'If a user asks about something unrelated to machines or mechanics, politely inform them that you only answer questions related to MC Space machines.'
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedKey = prefs.getString('cached_gemini_api_key');

      if (cachedKey != null && cachedKey.isNotEmpty) {
        _model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: cachedKey,
          systemInstruction: systemInstruction,
        );
        return;
      }

      final doc = await FirebaseFirestore.instance.collection('Gemini').doc('API').get();
      if (doc.exists) {
        final encodedKey = doc.data()?['API_KEY'] as String?;
        if (encodedKey != null) {
          final decodedBytes = base64.decode(encodedKey);
          final decodedApiKey = utf8.decode(decodedBytes);

          await prefs.setString('cached_gemini_api_key', decodedApiKey);

          _model = GenerativeModel(
            model: 'gemini-2.5-flash',
            apiKey: decodedApiKey,
            systemInstruction: systemInstruction,
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching Gemini API key: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to initialize AI Assistant')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initGemini();

    // Initial Message
    setState(() {
      _messages.add(ChatMessage(
        text: "Hello! I am the MC Space AI. Ask me anything about machines, maintenance, or mechanical parts.",
        isUser: false,
      ));
    });
  }

  void _sendMessage() async {
    final text = _messageController.text;
    if (text.isEmpty) return;

    if (_model == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI assistant is not ready yet. Please try again.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _messages.add(ChatMessage(text: text, isUser: true));
      _messageController.clear();
    });

    try {
      final content = [Content.text(text)];
      final response = await _model!.generateContent(content);
      
      setState(() {
        _messages.add(
            ChatMessage(text: response.text ?? 'I could not generate a response.', isUser: false));
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: 'Error: Please check your internet connection or API key.', isUser: false));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper method for Times New Roman style
  TextStyle _timesNewRomanStyle({
    Color? color, 
    double? fontSize, 
    FontWeight? fontWeight
  }) {
    return TextStyle(
      fontFamily: 'Times New Roman',
      // Fallback to generic 'serif' if Times New Roman isn't installed (common on Android)
      fontFamilyFallback: const ['serif'], 
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 2, 24, 90),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'MC Space Assistant',
          style: _timesNewRomanStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 22,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment:
                      message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        vertical: 4.0, horizontal: 8.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: message.isUser
                          ? const Color.fromARGB(255, 2, 24, 90)
                          : const Color(0xFFF5F5F5), 
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16.0),
                        topRight: const Radius.circular(16.0),
                        bottomLeft: message.isUser
                            ? const Radius.circular(16.0)
                            : const Radius.circular(0.0),
                        bottomRight: message.isUser
                            ? const Radius.circular(0.0)
                            : const Radius.circular(16.0),
                      ),
                      border: message.isUser ? null : Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      message.text,
                      style: _timesNewRomanStyle(
                        color: message.isUser ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: const Color.fromARGB(255, 2, 24, 90),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Consulting Manuals...",
                    style: _timesNewRomanStyle(
                      color: Colors.grey[600], 
                      fontSize: 14,
                      fontWeight: FontWeight.w500
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onSubmitted: (_) => _sendMessage(),
                    style: _timesNewRomanStyle(fontSize: 16), // Input text style
                    decoration: InputDecoration(
                      hintText: 'Ask about parts, gears, motors...',
                      hintStyle: _timesNewRomanStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: const BorderSide(color: Color.fromARGB(255, 2, 24, 90)),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 12.0),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                Material(
                  color: const Color.fromARGB(255, 2, 24, 90),
                  borderRadius: BorderRadius.circular(50.0),
                  child: InkWell(
                    onTap: _sendMessage,
                    borderRadius: BorderRadius.circular(50.0),
                    child: const Padding(
                      padding: EdgeInsets.all(14.0),
                      child: Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}