import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../vui/vui_theme.dart';
import '../vui/vui_state_manager.dart';
import '../vui/dialogue_engine.dart';
import '../widgets/vui_avatar.dart';
import '../widgets/waveform_visualizer.dart';
import '../widgets/chat_bubbles.dart';
import '../widgets/crisis_contacts_card.dart';
import '../widgets/exercise_progress_card.dart';

class VuiScreen extends StatefulWidget {
  const VuiScreen({super.key});

  @override
  State<VuiScreen> createState() => _VuiScreenState();
}

class _VuiScreenState extends State<VuiScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textInputController = TextEditingController();
  late VuiStateManager _manager;

  @override
  void initState() {
    super.initState();
    _manager = Provider.of<VuiStateManager>(context, listen: false);
    _manager.addListener(_scrollToBottom);
    _scrollToBottom();
  }

  @override
  void dispose() {
    _manager.removeListener(_scrollToBottom);
    _scrollController.dispose();
    _textInputController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _getHeaderTitle(VuiStateManager manager) {
    if (manager.state == VuiState.distress || manager.currentModule == VuiModule.crisis) {
      return "Help & support";
    }
    switch (manager.currentModule) {
      case VuiModule.mood:
        return "Mood check-in";
      case VuiModule.sleep:
        return "Sleep support";
      case VuiModule.breathing:
        return "Breathing exercise";
      case VuiModule.crisis:
        return "Help & support";
    }
  }

  Color _getModuleColor(VuiStateManager manager) {
    if (manager.state == VuiState.distress) return VuiTheme.crisisColor;
    if (manager.state == VuiState.listening) return VuiTheme.listeningColor;

    switch (manager.currentModule) {
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

  void _showTextFallbackSheet(BuildContext context, VuiStateManager manager) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161719),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            top: 16,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Text Input Fallback",
                style: TextStyle(
                  color: VuiTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _textInputController,
                autofocus: true,
                style: const TextStyle(color: VuiTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: "Type your response...",
                  hintStyle: const TextStyle(color: VuiTheme.textMuted),
                  filled: true,
                  fillColor: const Color(0xFF222326),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getModuleColor(manager),
                  foregroundColor: VuiTheme.background,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  final text = _textInputController.text.trim();
                  if (text.isNotEmpty) {
                    manager.submitSimulatedSpeech(text);
                    _textInputController.clear();
                    Navigator.pop(context);
                  }
                },
                child: const Text("Send Response"),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<VuiStateManager>(context);
    final themeColor = _getModuleColor(manager);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getHeaderTitle(manager),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: VuiTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: VuiTheme.textSecondary),
                    onPressed: () => manager.triggerGreeting(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- VISUAL AVATAR CORE ---
            const VuiAvatar(),

            const SizedBox(height: 12),

            // --- AUDIO WAVEFORM VISUALIZER ---
            const WaveformVisualizer(),

            const SizedBox(height: 12),

            // --- CONVERSATION VIEW (SCROLLABLE LOG) ---
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 16, top: 8),
                  itemCount: manager.chatHistory.length,
                  itemBuilder: (context, index) {
                    final message = manager.chatHistory[index];
                    return ChatBubble(
                      sender: message["sender"]!,
                      text: message["text"]!,
                      currentModule: manager.currentModule,
                      currentState: manager.state,
                    );
                  },
                ),
              ),
            ),

            // --- DYNAMIC MODULE SUB-PANELS ---
            _buildContextCard(manager),

            // --- USER ACTION QUICK CHIPS ---
            if (manager.currentNode.chips.isNotEmpty &&
                manager.state != VuiState.listening &&
                manager.state != VuiState.processing &&
                !manager.isBreathingActive)
              _buildChipsRow(manager),

            const SizedBox(height: 8),

            // --- BOTTOM CONTROL FOOTER ---
            _buildControlBar(manager, themeColor),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildContextCard(VuiStateManager manager) {
    if (manager.state == VuiState.distress && manager.currentNode.id == 'crisis_contacts') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: CrisisContactsCard(manager: manager),
      );
    }
    
    if (manager.currentModule == VuiModule.breathing && manager.isBreathingActive) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: ExerciseProgressCard(manager: manager),
      );
    }

    // Mood detected panel (Screenshot 1, right screen)
    final isEmotionNode = manager.currentNode.id == 'mood_anxious_detected' ||
        manager.currentNode.id == 'mood_happy_detected' ||
        manager.currentNode.id == 'mood_calm_detected' ||
        manager.currentNode.id == 'mood_sad_detected' ||
        manager.currentNode.id == 'mood_angry_detected' ||
        manager.currentNode.id == 'mood_distressed_detected';

    if (manager.currentModule == VuiModule.mood && 
        isEmotionNode && 
        manager.detectedEmotion.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF131118),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: VuiTheme.moodColor.withOpacity(0.12),
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "DETECTED",
                style: TextStyle(
                  color: VuiTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildDetectedChip(manager.detectedEmotion, "Emotion"),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDetectedChip(manager.detectedIntensity, "Intensity"),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDetectedChip(String val, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: VuiTheme.moodColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: VuiTheme.moodColor.withOpacity(0.2),
          width: 1.0,
        ),
      ),
      child: Column(
        children: [
          Text(
            val,
            style: const TextStyle(
              color: VuiTheme.moodColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: VuiTheme.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipsRow(VuiStateManager manager) {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: manager.currentNode.chips.length,
        itemBuilder: (context, index) {
          final chipText = manager.currentNode.chips[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              backgroundColor: const Color(0xFF1E1F22),
              side: BorderSide(
                color: _getModuleColor(manager).withOpacity(0.2),
                width: 1.0,
              ),
              label: Text(
                chipText,
                style: const TextStyle(color: VuiTheme.textPrimary, fontSize: 13),
              ),
              onPressed: () {
                manager.submitSimulatedSpeech(chipText);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlBar(VuiStateManager manager, Color themeColor) {
    IconData centerIcon = Icons.mic;
    String promptText = "Tap mic to respond";
    
    // Bottom text prompt matching designs
    if (manager.state == VuiState.listening) {
      promptText = "Release to send";
    } else if (manager.state == VuiState.distress) {
      if (manager.currentNode.id == 'crisis_contacts') {
        promptText = 'Say "call", "text" or "breathe"';
      } else {
        promptText = 'Tap mic or say "yes"';
      }
    } else if (manager.currentModule == VuiModule.breathing) {
      if (manager.isBreathingActive) {
        promptText = 'Say "pause" or "stop" anytime';
      } else if (manager.currentNode.id == 'breathing_complete') {
        promptText = "Tell Sera how you feel";
      } else {
        promptText = "Tap mic to start exercise";
      }
    } else if (manager.currentNode.id == 'sleep_screen_advice') {
      promptText = 'Say "yes" or tap mic';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // --- LEFT FOOTER BUTTON ---
              _buildSideButton(
                icon: (manager.currentModule == VuiModule.breathing && manager.isBreathingActive)
                    ? Icons.pause
                    : Icons.keyboard_alt_outlined,
                onPressed: () {
                  if (manager.currentModule == VuiModule.breathing && manager.isBreathingActive) {
                    manager.pauseBreathing();
                  } else {
                    _showTextFallbackSheet(context, manager);
                  }
                },
              ),

              // --- CENTER MIC BUTTON ---
              GestureDetector(
                onTapDown: (_) {
                  if (manager.currentModule == VuiModule.breathing) {
                    if (!manager.isBreathingActive) {
                      manager.startBreathingExercise();
                    }
                  } else {
                    manager.startListening();
                  }
                },
                onTapUp: (_) {
                  if (manager.currentModule != VuiModule.breathing) {
                    manager.stopListening();
                  }
                },
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: themeColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 1.5,
                      ),
                    ],
                  ),
                  child: Icon(
                    manager.currentModule == VuiModule.breathing && manager.isBreathingActive
                        ? Icons.air
                        : centerIcon,
                    color: VuiTheme.background,
                    size: 28,
                  ),
                ),
              ),

              // --- RIGHT FOOTER BUTTON ---
              _buildSideButton(
                icon: (manager.currentModule == VuiModule.breathing)
                    ? (manager.isBreathingActive ? Icons.stop : Icons.refresh)
                    : (manager.isMuted ? Icons.volume_off : Icons.volume_up),
                onPressed: () {
                  if (manager.currentModule == VuiModule.breathing) {
                    if (manager.isBreathingActive) {
                      manager.stopBreathing();
                    } else {
                      manager.startBreathingExercise();
                    }
                  } else {
                    manager.toggleMute();
                  }
                },
              ),
            ],
          ),
        ),
        Text(
          promptText,
          style: const TextStyle(
            color: VuiTheme.textMuted,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSideButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F22),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.04),
          width: 1.0,
        ),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        color: VuiTheme.textSecondary,
        onPressed: onPressed,
      ),
    );
  }
}
