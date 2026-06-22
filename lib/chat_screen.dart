import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'groq_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GroqService _groqService = GroqService();
  
  String? _sessionId;
  bool _isTyping = false;
  bool _isSessionClosed = false;
  
  // Local state for UI
  final List<Map<String, String>> _messages = [];

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  Future<void> _startSession() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final userId = user?.id ?? 'anonymous';
      
      String userDept = 'Desconocido';
      if (userId != 'anonymous') {
        final userRes = await Supabase.instance.client.schema('calmwork').from('employees').select('department').eq('id', userId).maybeSingle();
        if (userRes != null && userRes['department'] != null) {
          userDept = userRes['department'];
        }
      }

      final res = await Supabase.instance.client
          .schema('calmwork')
          .from('chatbot_sessions')
          .insert({'status': 'active', 'department': userDept})
          .select('id')
          .single();
      
      if (mounted) {
        setState(() {
          _sessionId = res['id'].toString();
        });
      }
      
      // Add initial greeting from bot
      await _addMessage('assistant', 'Hola, soy tu asistente de apoyo confidencial. Estoy aquí para escucharte y apoyarte con cualquier situación laboral o personal que estés atravesando. ¿Cómo te sientes hoy?');
      
    } catch (e) {
      debugPrint('Error starting session: $e');
    }
  }

  Future<void> _addMessage(String role, String content) async {
    if (mounted) {
      setState(() {
        _messages.add({'role': role, 'content': content});
      });
      _scrollToBottom();
    }
    
    // Save to DB in background
    if (_sessionId != null) {
      try {
        await Supabase.instance.client
            .schema('calmwork')
            .from('chatbot_messages')
            .insert({
              'session_id': _sessionId,
              'role': role,
              'content': content,
            });
      } catch (e) {
        debugPrint('Error saving message: $e');
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isTyping) return;
    
    _messageController.clear();
    await _addMessage('user', text);
    
    if (mounted) {
      setState(() {
        _isTyping = true;
      });
      _scrollToBottom();
    }
    
    // Call Groq
    final history = _messages.map((m) => {'role': m['role']!, 'content': m['content']!}).toList();
    final response = await _groqService.sendMessage(history);
    
    if (mounted) {
      setState(() {
        _isTyping = false;
      });
    }
    
    await _addMessage('assistant', response);
  }

  Future<void> _analyzeAndCloseSession() async {
    if (_sessionId == null || _messages.length <= 1) {
      Navigator.of(context).pop();
      return;
    }
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      // Analyze conversation
      final history = _messages.map((m) => {'role': m['role']!, 'content': m['content']!}).toList();
      final insights = await _groqService.analyzeConversation(history);
      
      // Save insights
      await Supabase.instance.client
          .schema('calmwork')
          .from('chatbot_insights')
          .insert({
            'session_id': _sessionId,
            'topic': insights['tema'],
            'urgency': insights['urgencia'],
          });
          
      // Update session status
      await Supabase.instance.client
          .schema('calmwork')
          .from('chatbot_sessions')
          .update({'status': 'closed'})
          .eq('id', _sessionId as Object);
          
      _isSessionClosed = true;
          
    } catch (e) {
      debugPrint('Error saving insights: $e');
    }
    
    if (mounted) {
      Navigator.of(context).pop(); // dismiss dialog
      setState(() {
        _messages.clear();
        _sessionId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesión finalizada y guardada de forma anónima.')),
      );
      _startSession(); // Start a new fresh session
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    if (_sessionId != null && _messages.length > 1 && !_isSessionClosed) {
      // Fire and forget analysis if user leaves the tab
      final history = List<Map<String, String>>.from(_messages);
      final currentSessionId = _sessionId;
      _groqService.analyzeConversation(history).then((insights) {
        Supabase.instance.client.schema('calmwork').from('chatbot_insights').insert({
          'session_id': currentSessionId,
          'topic_detected': insights['tema'],
          'ai_summary': insights['resumen'], // Guardamos el resumen generado
          'urgency_level': insights['urgencia'],
          'recommendations': insights['recomendaciones'], // Guardamos el array como JSONB en Supabase
        });
        Supabase.instance.client.schema('calmwork').from('chatbot_sessions').update({'status': 'closed'}).eq('id', currentSessionId as Object);
      }).catchError((e) => debugPrint('Error background insights: $e'));
    }
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      body: Stack(
        children: [
          // Header Gradient
          Container(
            height: MediaQuery.of(context).size.height * 0.25,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF246672), Color(0xFF4BA5B5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 10, left: 16, right: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Asistente\nConfidencial', style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: _analyzeAndCloseSession,
                      style: TextButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                      child: const Text('Finalizar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            ),
          ),
          // Decorative circles
          Positioned(top: -50, right: -50, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1)))),
          
          // Main Content Card (Chat Area)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 80, left: 0, right: 0, bottom: 0),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
                ),
                child: PopScope(
                  canPop: false,
                  onPopInvoked: (didPop) async {
                    if (didPop) return;
                    await _analyzeAndCloseSession();
                  },
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isUser = message['role'] == 'user';
                            return _buildMessageBubble(message['content']!, isUser);
                          },
                        ),
                      ),
                      if (_isTyping)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Escribiendo...', style: TextStyle(color: Colors.black54, fontStyle: FontStyle.italic)),
                          ),
                        ),
                      _buildInputArea(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF246672) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 20),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
          ],
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF1F2937),
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF6AB2BB), // primaryLight
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
