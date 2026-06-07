import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../vui/vui_theme.dart';
import '../vui/vui_state_manager.dart';
import '../vui/dialogue_engine.dart';
import '../widgets/sera_orb.dart';

// ─── HELP / EMERGENCY SCREEN ─────────────────────────────────────────────────

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  // ── Phone / URL launchers ──────────────────────────────────────────────────

  static Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  static Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mgr = Provider.of<VuiStateManager>(context);
    final color = VuiTheme.crisisColor;
    final isActive = mgr.state == VuiState.listening ||
        mgr.state == VuiState.speaking ||
        mgr.state == VuiState.distress;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────
            _ScreenHeader(
              icon: Icons.warning_amber_rounded,
              color: color,
              title: 'Emergency contacts',
            ),

            const SizedBox(height: 20),

            // ── Crisis detected banner ───────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.30), width: 1.2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(Icons.warning_amber_rounded,
                        color: color, size: 17),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Crisis detected in your voice',
                          style: GoogleFonts.dmSans(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "You don't have to go through this alone. "
                          'Help is available right now.',
                          style: GoogleFonts.dmSans(
                            color: Colors.white54,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Contact rows ─────────────────────────────────────
            _ContactRow(
              icon: Icons.phone_rounded,
              iconColor: VuiTheme.crisisColor,
              title: 'Emergency Services',
              subtitle: 'Immediate danger',
              badge: '119',
              badgeColor: VuiTheme.crisisColor,
              onTap: () {
                _call('119');
              },
            ),
            const SizedBox(height: 10),
            _ContactRow(
              icon: Icons.local_hospital_rounded,
              iconColor: VuiTheme.moodColor,
              title: 'Mental Health Hotline',
              subtitle: '24/7 crisis support',
              badge: '1926',
              badgeColor: VuiTheme.moodColor,
              onTap: () {
                _call('1926');
              },
            ),
            const SizedBox(height: 10),
            _ContactRow(
              icon: Icons.chat_bubble_outline_rounded,
              iconColor: VuiTheme.breathingColor,
              title: 'Online Counselling',
              subtitle: 'Chat with a professional',
              badge: null,
              badgeColor: VuiTheme.breathingColor,
              trailingIcon: Icons.open_in_new_rounded,
              onTap: () {
                _open('https://www.nimhsl.lk/');
              },
            ),

            const SizedBox(height: 32),

            // ── VUI orb ─────────────────────────────────────────
            Center(
              child: SeraOrb(
                color: color,
                orbSize: 68,
                icon: Icons.mic_rounded,
                isActive: isActive,
                onTapDown: (_) => mgr.startListening(),
                onTapUp: (_) => mgr.stopListening(),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '"Say \'call hotline\' to connect"',
                style: GoogleFonts.dmSans(
                  color: Colors.white38,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CONTACT ROW ─────────────────────────────────────────────────────────────

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final Color badgeColor;
  final IconData? trailingIcon;
  final VoidCallback onTap;

  const _ContactRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF16181E),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Trailing: number badge or icon
            if (badge != null)
              Text(
                badge!,
                style: GoogleFonts.dmSans(
                  color: badgeColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              )
            else if (trailingIcon != null)
              Icon(trailingIcon, color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── SHARED SCREEN HEADER ────────────────────────────────────────────────────

class _ScreenHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;

  const _ScreenHeader({
    required this.icon,
    required this.color,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.55), width: 1.5),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
