import 'package:flutter/material.dart';
import '../vui/vui_theme.dart';
import '../vui/dialogue_engine.dart';

class ChatBubble extends StatelessWidget {
  final String sender;
  final String text;
  final VuiModule currentModule;
  final VuiState currentState;

  const ChatBubble({
    super.key,
    required this.sender,
    required this.text,
    required this.currentModule,
    required this.currentState,
  });

  Color _getSenderColor() {
    if (currentState == VuiState.distress) return VuiTheme.crisisColor;
    
    switch (currentModule) {
      case VuiModule.mood:
        return VuiTheme.moodColor;
      case VuiModule.sleep:
        return VuiTheme.sleepColor;
      case VuiModule.breathing:
        return VuiTheme.breathingColor;
      case VuiModule.crisis:
        return VuiTheme.crisisColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSera = sender == "Sera";
    final senderColor = _getSenderColor();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Align(
        alignment: isSera ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSera ? VuiTheme.chatBubbleSera : VuiTheme.chatBubbleYou,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isSera ? const Radius.circular(4) : const Radius.circular(16),
              bottomRight: isSera ? const Radius.circular(16) : const Radius.circular(4),
            ),
            border: Border.all(
              color: isSera 
                  ? senderColor.withOpacity(0.1) 
                  : Colors.white.withOpacity(0.04),
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sender,
                style: TextStyle(
                  color: isSera ? senderColor : VuiTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: const TextStyle(
                  color: VuiTheme.textPrimary,
                  fontSize: 14.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
