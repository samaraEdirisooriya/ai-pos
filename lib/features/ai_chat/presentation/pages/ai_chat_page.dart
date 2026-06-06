import 'package:flutter/material.dart';
import 'package:pos_ai/features/ai_chat/presentation/widgets/ai_chat_widget.dart';

/// AI Chat page connected to the backend AI endpoints with Vectorize.
class AiChatPage extends StatelessWidget {
  const AiChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: const AiChatWidget(),
        ),
      ),
    );
  }
}
