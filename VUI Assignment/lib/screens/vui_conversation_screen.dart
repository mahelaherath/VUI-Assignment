import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../vui/vui_theme.dart';
import '../vui/vui_state_manager.dart';
import '../vui/dialogue_engine.dart';
import '../widgets/vui_avatar.dart';
import '../widgets/waveform_visualizer.dart';
import '../widgets/chat_bubbles.dart';

/// Full-screen VUI conversation screen.
/// Accepts [initialContext] to select the opening prompt:
///   "mood_checkin"  → mood flow
///   "sleep_routine" → sleep flow
///   "breathing"     → breathing flow
///   "crisis_calm"   → crisis calm / breathing flow
class VUIConversationScreen extends StatefulWidget {
  final String initialContext;

  const VUIConversationScreen({
    super.key,
    required this.initialContext,
  });

  @override
  State<VUIConversationScreen> createState() =>
      _VUIConversationScreenState();
}

class _VUIConversationScreenState
    extends State<VUIConversationScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController =
      TextEditingController();

  late VuiStateManager _manager;

  @override
  void initState() {
    super.initState();
    _manager =
        Provider.of<VuiStateManager>(context, listen: false);
    _manager.addListener(_scrollToBottom);

    // Transition to the appropriate module based on context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startFromContext(widget.initialContext);
    });
  }

  @override
  void dispose() {
    _manager.removeListener(_scrollToBottom);
    _scrollController.dispose();
    _textController.dispose();
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

  void _startFromContext(String ctx) {
    switch (ctx) {
      case 'mood_checkin':
        _manager.transitionToModule(VuiModule.mood);
        break;
      case 'sleep_routine':
        _manager.transitionToModule(VuiModule.sleep);
        break;
      case 'breathing':
        _manager.transitionToModule(VuiModule.breathing);
        break;
      case 'crisis_calm':
        _manager.transitionToModule(VuiModule.breathing);
        break;
      default:
        _manager.transitionToModule(VuiModule.mood);
    }
  }

  String _headerTitle() {
    switch (widget.initialContext) {
      case 'mood_checkin':
        return 'Mood check-in';
      case 'sleep_routine':
        return 'Sleep support';
      case 'breathing':
        return 'Breathing exercise';
      case 'crisis_calm':
        return 'Calm with Sera';
      default:
        return 'Talk to Sera';
    }
  }

  Color _accentColor(VuiStateManager m) {
    if (m.state == VuiState.distress) return VuiTheme.crisisColor;
    if (m.state == VuiState.listening) return VuiTheme.listeningColor;
    switch (m.currentModule) {
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

  void _showTextFallback(VuiStateManager m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161719),
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 16,
          left: 16,
          right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Type your response',
              style: GoogleFonts.dmSans(
                color: VuiTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              autofocus: true,
              style: GoogleFonts.dmSans(
                  color: VuiTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Type your response...',
                hintStyle: GoogleFonts.dmSans(
                    color: VuiTheme.textMuted),
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
                backgroundColor: _accentColor(m),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final text = _textController.text.trim();
                if (text.isNotEmpty) {
                  m.submitSimulatedSpeech(text);
                  _textController.clear();
                  Navigator.pop(context);
                }
              },
              child: Text(
                'Send response',
                style: GoogleFonts.dmSans(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<VuiStateManager>(context);
    final accent = _accentColor(manager);

    return Scaffold(
      backgroundColor: VuiTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0x0DFFFFFF),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0x1AFFFFFF)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white54, size: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _headerTitle(),
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Sera is with you',
                          style: GoogleFonts.dmSans(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Mute button
                  GestureDetector(
                    onTap: () => manager.toggleMute(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0x0DFFFFFF),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0x1AFFFFFF)),
                      ),
                      child: Icon(
                        manager.isMuted
                            ? Icons.volume_off
                            : Icons.volume_up,
                        color: Colors.white54,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Avatar orb ─────────────────────────────────────────
            const VuiAvatar(),
            const SizedBox(height: 8),

            // ── Waveform ───────────────────────────────────────────
            const WaveformVisualizer(),
            const SizedBox(height: 8),

            // ── Chat bubbles ───────────────────────────────────────
            Expanded(
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(
                      bottom: 16, top: 8),
                  itemCount: manager.chatHistory.length,
                  itemBuilder: (context, index) {
                    final msg = manager.chatHistory[index];
                    return ChatBubble(
                      sender: msg['sender']!,
                      text: msg['text']!,
                      currentModule: manager.currentModule,
                      currentState: manager.state,
                    );
                  },
                ),
              ),
            ),

            // ── Quick chip suggestions ─────────────────────────────
            if (manager.currentNode.chips.isNotEmpty &&
                manager.state != VuiState.listening &&
                manager.state != VuiState.processing &&
                !manager.isBreathingActive)
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16),
                  itemCount:
                      manager.currentNode.chips.length,
                  itemBuilder: (context, i) {
                    final chip =
                        manager.currentNode.chips[i];
                    return Padding(
                      padding:
                          const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        backgroundColor:
                            const Color(0xFF1E1F22),
                        side: BorderSide(
                            color: accent.withOpacity(0.2),
                            width: 1),
                        label: Text(
                          chip,
                          style: GoogleFonts.dmSans(
                            color: VuiTheme.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () =>
                            manager.submitSimulatedSpeech(
                                chip),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 8),

            // ── Control bar ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceEvenly,
                children: [
                  // Keyboard fallback / pause
                  _SideButton(
                    icon: (manager.currentModule ==
                                VuiModule.breathing &&
                            manager.isBreathingActive)
                        ? Icons.pause
                        : Icons.keyboard_alt_outlined,
                    onTap: () {
                      if (manager.currentModule ==
                              VuiModule.breathing &&
                          manager.isBreathingActive) {
                        manager.pauseBreathing();
                      } else {
                        _showTextFallback(manager);
                      }
                    },
                  ),

                  // Central mic / breathing trigger
                  GestureDetector(
                    onTapDown: (_) {
                      if (manager.currentModule ==
                          VuiModule.breathing) {
                        if (!manager.isBreathingActive) {
                          if (manager.breathingCycle <= manager.maxCycles) {
                            manager.resumeBreathingExercise();
                          } else {
                            manager.startBreathingExercise();
                          }
                        }
                      } else {
                        manager.startListening();
                      }
                    },
                    onTapUp: (_) {
                      if (manager.currentModule !=
                          VuiModule.breathing) {
                        manager.stopListening();
                      }
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withOpacity(0.35),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        manager.currentModule ==
                                    VuiModule.breathing &&
                                manager.isBreathingActive
                            ? Icons.air
                            : Icons.mic,
                        color: VuiTheme.background,
                        size: 28,
                      ),
                    ),
                  ),

                  // Mute / stop
                  _SideButton(
                    icon: manager.currentModule ==
                            VuiModule.breathing
                        ? (manager.isBreathingActive
                            ? Icons.stop
                            : Icons.refresh)
                        : (manager.isMuted
                            ? Icons.volume_off
                            : Icons.volume_up),
                    onTap: () {
                      if (manager.currentModule ==
                          VuiModule.breathing) {
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

            // ── Status prompt ──────────────────────────────────────
            Text(
              _promptText(manager),
              style: GoogleFonts.dmSans(
                color: VuiTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _promptText(VuiStateManager m) {
    if (m.state == VuiState.listening) {
      return 'Release to send';
    } else if (m.currentModule == VuiModule.breathing) {
      if (m.isBreathingActive) {
        return 'Say "pause" or "stop" anytime';
      }
      return 'Tap mic to start exercise';
    } else if (m.state == VuiState.distress) {
      return 'Say "call", "text" or "breathe"';
    }
    return 'Tap mic to respond';
  }
}

// ─── SIDE BUTTON ─────────────────────────────────────────────────────────────

class _SideButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SideButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1F22),
          shape: BoxShape.circle,
          border: Border.all(
              color: Colors.white.withOpacity(0.05), width: 1),
        ),
        child: Icon(icon, size: 20, color: VuiTheme.textSecondary),
      ),
    );
  }
}
