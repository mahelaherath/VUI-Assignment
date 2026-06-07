import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../vui/vui_theme.dart';
import '../vui/vui_state_manager.dart';
import '../vui/dialogue_engine.dart';
import '../vui/navigation_notifier.dart';
import '../widgets/sera_orb.dart';

// ─── HOME SCREEN ─────────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mgr = Provider.of<VuiStateManager>(context);
    final isActive = mgr.state == VuiState.listening ||
        mgr.state == VuiState.speaking;

    return SafeArea(
      child: Column(
        children: [
          // ── App title ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                'Sera',
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Greeting ─────────────────────────────────────
                  Text(
                    'Good morning',
                    style: GoogleFonts.dmSans(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'How are you feeling today?',
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 34),

                  // ── VUI orb ──────────────────────────────────────
                  Center(
                    child: SeraOrb(
                      color: VuiTheme.moodColor,
                      orbSize: 74,
                      icon: Icons.mic_rounded,
                      isActive: isActive,
                      onTapDown: (_) => mgr.startListening(),
                      onTapUp: (_) => mgr.stopListening(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      _orbLabel(mgr.state),
                      style: GoogleFonts.dmSans(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 34),

                  // ── 2×2 module grid ──────────────────────────────
                  Row(children: [
                    Expanded(
                      child: _ModuleCard(
                        icon: Icons.mood_rounded,
                        color: VuiTheme.moodColor,
                        title: 'Mood check-in',
                        subtitle: 'How are you today?',
                        navIndex: 1,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ModuleCard(
                        icon: Icons.air_rounded,
                        color: VuiTheme.breathingColor,
                        title: 'Breathing',
                        subtitle: 'Guided exercise',
                        navIndex: 2,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: _ModuleCard(
                        icon: Icons.bedtime_rounded,
                        color: VuiTheme.sleepColor,
                        title: 'Sleep hygiene',
                        subtitle: 'Bedtime tips',
                        navIndex: 3,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ModuleCard(
                        icon: Icons.emergency_outlined,
                        color: VuiTheme.crisisColor,
                        title: 'Emergency',
                        subtitle: 'Crisis contacts',
                        navIndex: 4,
                      ),
                    ),
                  ]),

                  const SizedBox(height: 12),

                  // ── Streak card ──────────────────────────────────
                  _StreakCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _orbLabel(VuiState state) {
    switch (state) {
      case VuiState.listening:
        return 'Listening...';
      case VuiState.speaking:
        return 'Sera is speaking...';
      case VuiState.processing:
        return 'Processing...';
      default:
        return 'Tap to speak';
    }
  }
}

// ─── MODULE CARD ─────────────────────────────────────────────────────────────

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final int navIndex;

  const _ModuleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.navIndex,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Provider.of<NavigationNotifier>(context, listen: false)
          .navigateTo(navIndex),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF16181E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon box (bordered outline)
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: color.withOpacity(0.55),
                  width: 1.5,
                ),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
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
    );
  }
}

// ─── STREAK CARD ─────────────────────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF16181E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: VuiTheme.moodColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: VuiTheme.moodColor.withOpacity(0.3),
                width: 1.2,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.local_fire_department_rounded,
                color: Color(0xFFFFB74D),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Streak',
                style: GoogleFonts.dmSans(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    '4 days in a row',
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('🔥', style: TextStyle(fontSize: 16)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
