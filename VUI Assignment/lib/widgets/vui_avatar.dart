import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../vui/vui_theme.dart';
import '../vui/vui_state_manager.dart';
import '../vui/dialogue_engine.dart';

class VuiAvatar extends StatefulWidget {
  const VuiAvatar({super.key});

  @override
  State<VuiAvatar> createState() => _VuiAvatarState();
}

class _VuiAvatarState extends State<VuiAvatar> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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

  IconData _getIconData(VuiStateManager manager) {
    if (manager.state == VuiState.listening) {
      return Icons.hearing; // Ear icon from screens
    }
    
    switch (manager.currentModule) {
      case VuiModule.mood:
        return Icons.mic;
      case VuiModule.sleep:
        return Icons.nightlight_round; // Crescent Moon icon
      case VuiModule.breathing:
        return Icons.air; // Breathing wind icon
      case VuiModule.crisis:
        return Icons.favorite; // Heart icon
    }
  }

  double _getAvatarScale(VuiStateManager manager) {
    if (manager.currentModule == VuiModule.breathing && manager.isBreathingActive) {
      // 4-7-8 pacing scale (more dramatic breathing scaling)
      if (manager.breathingPhase == "Inhale") {
        return 1.4; // Expanding larger
      } else if (manager.breathingPhase == "Hold") {
        return 1.6; // Maintained full size
      } else {
        return 0.9; // Contracting smaller
      }
    }
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<VuiStateManager>(context);
    final accentColor = _getModuleColor(manager);
    final centerIcon = _getIconData(manager);
    final targetScale = _getAvatarScale(manager);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dynamic floating animation wrapper
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            // Larger vertical oscillation when active (speaking/listening)
            final amplitude = (manager.state == VuiState.speaking || 
                               manager.state == VuiState.listening || 
                               manager.state == VuiState.guiding ||
                               manager.state == VuiState.distress) 
                ? 14.0 
                : 5.0;
            final offsetY = math.sin(_pulseController.value * 2 * math.pi) * amplitude;

            return Transform.translate(
              offset: Offset(0, offsetY),
              child: AnimatedScale(
                scale: targetScale,
                duration: manager.currentModule == VuiModule.breathing && manager.isBreathingActive
                    ? Duration(
                        seconds: manager.breathingPhase == "Inhale"
                            ? 4
                            : manager.breathingPhase == "Hold"
                                ? 0
                                : 8)
                    : const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulsing ripple effect rings
                    Stack(
                      alignment: Alignment.center,
                      children: List.generate(3, (index) {
                        final progress = (_pulseController.value + (index / 3)) % 1.0;
                        final size = 90.0 + (progress * 110.0); // Expand wider
                        final opacity = (1.0 - progress) * 0.45;

                        return Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accentColor.withOpacity(
                                manager.state == VuiState.listening || manager.state == VuiState.speaking
                                    ? opacity
                                    : 0.08,
                              ),
                              width: 1.5,
                            ),
                          ),
                        );
                      }),
                    ),
                    // Inner structural ring
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accentColor.withOpacity(0.3),
                          width: 2.0,
                        ),
                      ),
                    ),
                    // Core Avatar Button
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor,
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        centerIcon,
                        size: 36,
                        color: VuiTheme.background,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        
        // Status indicator capsule/pill
        _buildStatusTag(manager),
      ],
    );
  }

  Widget _buildStatusTag(VuiStateManager manager) {
    String text = "";
    Color bg = Colors.transparent;
    Color border = Colors.transparent;

    if (manager.state == VuiState.distress) {
      text = "Distress detected";
      bg = VuiTheme.crisisColor.withOpacity(0.15);
      border = VuiTheme.crisisColor.withOpacity(0.3);
    } else if (manager.state == VuiState.listening) {
      text = "Listening...";
      bg = VuiTheme.listeningColor.withOpacity(0.15);
      border = VuiTheme.listeningColor.withOpacity(0.3);
    } else if (manager.state == VuiState.processing) {
      text = "Processing...";
      bg = Colors.white.withOpacity(0.05);
      border = Colors.white.withOpacity(0.15);
    } else if (manager.state == VuiState.speaking) {
      text = "Sera is speaking";
      bg = VuiTheme.listeningColor.withOpacity(0.12);
      border = VuiTheme.listeningColor.withOpacity(0.24);
    } else if (manager.state == VuiState.guiding) {
      text = "Sera is guiding";
      bg = VuiTheme.breathingColor.withOpacity(0.12);
      border = VuiTheme.breathingColor.withOpacity(0.24);
    } else if (manager.currentNode.id == 'breathing_complete') {
      text = "Exercise complete";
      bg = Colors.white.withOpacity(0.05);
      border = Colors.white.withOpacity(0.15);
    } else {
      return const SizedBox(height: 28);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1.0),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: manager.state == VuiState.distress
              ? VuiTheme.crisisColor
              : manager.state == VuiState.listening
                  ? VuiTheme.listeningColor
                  : VuiTheme.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
