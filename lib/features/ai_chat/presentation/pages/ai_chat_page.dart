import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AI Chat page designed to work inside the gradient bottom panel.
class AiChatPage extends StatelessWidget {
  const AiChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 200) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Assistant',
                style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
            const SizedBox(height: 4),
            Text('Ask Lanka AI anything about your POS system',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        children: [
                          _bubble(context,
                              'Hello Admin! I am Lanka AI. How can I assist you with your POS system today?',
                              true),
                          _bubble(context,
                              'Can you show me the sales prediction for next week?',
                              false),
                          _bubble(context,
                              'Based on historical data and current trends, next week\'s sales are predicted to increase by 15%. I have generated a detailed chart in your analytics dashboard.',
                              true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInput(),
                  ],
                ),
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _bubble(BuildContext context, String text, bool isAi) {
    return Align(
      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.45),
        decoration: BoxDecoration(
          color: isAi
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomLeft: isAi ? const Radius.circular(4) : const Radius.circular(20),
            bottomRight: !isAi ? const Radius.circular(4) : const Radius.circular(20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAi) ...[
              const Icon(Icons.smart_toy, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(text,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: Colors.white, height: 1.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_file, color: Colors.white54, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ask Lanka AI...',
                hintStyle:
                    GoogleFonts.inter(fontSize: 13, color: Colors.white38),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.send, color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }
}
