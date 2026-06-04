import 'package:flutter/material.dart';
import '../vui/vui_theme.dart';
import '../vui/vui_state_manager.dart';

class ExerciseProgressCard extends StatelessWidget {
  final VuiStateManager manager;

  const ExerciseProgressCard({super.key, required this.manager});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1512), // Deep green tinted charcoal background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: VuiTheme.breathingColor.withOpacity(0.12),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "EXERCISE PROGRESS",
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
              // Technique Box
              Expanded(
                child: _buildProgressMetric(
                  value: "4-7-8",
                  label: "Technique",
                ),
              ),
              const SizedBox(width: 8),
              // Cycle Box
              Expanded(
                child: _buildProgressMetric(
                  value: "${manager.breathingCycle}/${manager.maxCycles}",
                  label: "Cycle",
                ),
              ),
              const SizedBox(width: 8),
              // Phase Box
              Expanded(
                child: _buildProgressMetric(
                  value: manager.breathingPhase,
                  label: "Phase",
                  highlighted: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressMetric({
    required String value,
    required String label,
    bool highlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: highlighted 
            ? VuiTheme.breathingColor.withOpacity(0.08) 
            : const Color(0xFF161E1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlighted 
              ? VuiTheme.breathingColor.withOpacity(0.24) 
              : Colors.transparent,
          width: 1.0,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: highlighted ? VuiTheme.breathingColor : VuiTheme.textPrimary,
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
}
