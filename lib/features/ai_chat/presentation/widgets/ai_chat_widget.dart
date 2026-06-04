import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:pos_ai/core/theme/app_colors.dart';

class AiChatWidget extends StatefulWidget {
  final String apiBase;

  const AiChatWidget({
    Key? key,
    this.apiBase = 'https://pos-backend.posai.workers.dev',
  }) : super(key: key);

  @override
  State<AiChatWidget> createState() => _AiChatWidgetState();
}

class _AiChatWidgetState extends State<AiChatWidget>
    with SingleTickerProviderStateMixin {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  final Dio _dio = Dio();
  late final AnimationController _dotAnimationController;
  int? _selectedMessageIndex;

  @override
  void initState() {
    super.initState();
    _dotAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    // seed welcome message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _messages.add(ChatMessage(
          text:
              'Welcome to Lanka AI Super POS. How can I assist you today? Do you need help with inventory, sales, customer information, or business insights?',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    _dotAnimationController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: query.trim(), isUser: true, timestamp: DateTime.now()));
      _isLoading = true;
    });

    _queryController.clear();
    _scrollToBottom();

    try {
      final response = await _dio.post(
        '${widget.apiBase}/api/ai/chat',
        data: {'query': query},
        options: Options(receiveTimeout: const Duration(seconds: 30)),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['success'] == true) {
          final aiResponse = data['response']?.toString() ?? 'No response';
          setState(() {
            _messages.add(ChatMessage(text: aiResponse, isUser: false, timestamp: DateTime.now()));
          });
          _scrollToBottom();
        } else {
          _showError('API Error: ${data['error'] ?? 'Unknown error'}');
        }
      } else {
        _showError('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Connection error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String message) {
    setState(() {
      _messages.add(ChatMessage(text: 'Error: $message', isUser: false, timestamp: DateTime.now(), isError: true));
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Messages list: transparent so parent background shows
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        color: AppColors.textSecondary.withOpacity(0.28),
                        size: 56,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Ask me about your business',
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Stock • Sales • Profit • Customers',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _isLoading) return _buildLoadingDots();
                    final message = _messages[index];
                    return _buildMessageBubble(message, index);
                  },
                ),
        ),

        // Input area (glassmorphism, translucent)
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.10),
                border: Border(
                  top: BorderSide(color: AppColors.border.withOpacity(0.12)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      enabled: !_isLoading,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ask about your business...',
                        hintStyle: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.18)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.18)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white, width: 1.2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onSubmitted: _isLoading ? null : _sendMessage,
                    ),
                  ),

                  const SizedBox(width: 10),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.20),
                          border: Border.all(color: Colors.white.withOpacity(0.18)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: _isLoading
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.9)),
                                  ),
                                )
                              : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                          onPressed: _isLoading ? null : () => _sendMessage(_queryController.text),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingDots() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.14),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    return AnimatedBuilder(
                      animation: _dotAnimationController,
                      builder: (context, child) {
                        final animValue = _dotAnimationController.value;
                        final delay = index * 0.2;
                        final v = (sin((animValue - delay) * pi * 2) + 1) / 2; // 0..1
                        final opacity = 0.3 + v * 0.7;

                        return Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(opacity),
                          ),
                        );
                      },
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, int? index) {
    final isUser = message.isUser;
    final selected = index != null && _selectedMessageIndex == index;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GestureDetector(
          onTap: () {
            if (index != null) {
              setState(() {
                if (_selectedMessageIndex == index) _selectedMessageIndex = null;
                else _selectedMessageIndex = index;
              });
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser
                      ? AppColors.secondary.withOpacity(0.46)
                      : (message.isError ? AppColors.error.withOpacity(0.12) : Colors.white.withOpacity(0.06)),
                  border: Border.all(color: selected ? Colors.white.withOpacity(0.95) : Colors.white.withOpacity(0.06), width: selected ? 1.4 : 1.0),
                  borderRadius: BorderRadius.circular(12),
                ),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                child: Column(
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.text,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(message.timestamp),
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) => '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({required this.text, required this.isUser, required this.timestamp, this.isError = false});
}
