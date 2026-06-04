import 'package:flutter/material.dart';
import '../vui/vui_theme.dart';
import '../vui/vui_state_manager.dart';

class CrisisContactsCard extends StatelessWidget {
  final VuiStateManager manager;

  const CrisisContactsCard({super.key, required this.manager});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1314), // Deep reddish dark charcoal background from screens
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: VuiTheme.crisisColor.withOpacity(0.15),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "CRISIS CONTACTS — VOICE ACTIVATED",
            style: TextStyle(
              color: VuiTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          
          // Hotline Item
          _buildContactRow(
            context: context,
            icon: Icons.phone_in_talk,
            title: "Crisis hotline",
            subtitle: "116 123 • 24/7 free",
            voiceTrigger: "call",
            onTap: () => manager.dialEmergencyHotline(),
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(color: Color(0xFF2E2224), height: 1),
          ),
          
          // Textline Item
          _buildContactRow(
            context: context,
            icon: Icons.chat_bubble_outline,
            title: "Crisis text line",
            subtitle: "Text HOME to 85258",
            voiceTrigger: "text",
            onTap: () => manager.textEmergencyLine(),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required String voiceTrigger,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: VuiTheme.crisisColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: VuiTheme.crisisColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: VuiTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: VuiTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF291E20),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: VuiTheme.crisisColor.withOpacity(0.2),
                  width: 1.0,
                ),
              ),
              child: Text(
                'Say "$voiceTrigger"',
                style: const TextStyle(
                  color: VuiTheme.crisisColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
