import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../vui/vui_theme.dart';
import '../vui/vui_state_manager.dart';
import '../vui/dialogue_engine.dart';

class WaveformVisualizer extends StatefulWidget {
  const WaveformVisualizer({super.key});

  @override
  State<WaveformVisualizer> createState() => _WaveformVisualizerState();
}

class _WaveformVisualizerState extends State<WaveformVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final List<double> _baseAmplitudes = [0.3, 0.6, 1.0, 0.7, 1.0, 0.6, 0.3];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color _getWaveformColor(VuiStateManager manager) {
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

  bool _isActive(VuiState state) {
    return state == VuiState.listening || state == VuiState.speaking || state == VuiState.guiding;
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<VuiStateManager>(context);
    final active = _isActive(manager.state);
    final color = _getWaveformColor(manager);

    return SizedBox(
      height: 24,
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_baseAmplitudes.length, (index) {
              double multiplier = active 
                  ? (0.4 + 0.6 * _random.nextDouble()) 
                  : 0.15; // Muted flat line when idle/processing
              
              // Scale the wave height
              double currentHeight = 4.0 + (20.0 * _baseAmplitudes[index] * multiplier);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                width: 3.5,
                height: currentHeight,
                margin: const EdgeInsets.symmetric(horizontal: 2.0),
                decoration: BoxDecoration(
                  color: color.withOpacity(active ? 0.85 : 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
