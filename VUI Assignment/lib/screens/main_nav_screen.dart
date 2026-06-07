import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../vui/vui_theme.dart';
import '../vui/vui_state_manager.dart';
import '../vui/dialogue_engine.dart';
import '../vui/navigation_notifier.dart';
import 'home_screen.dart';
import 'mood_screen.dart';
import 'breathe_screen.dart';
import 'sleep_screen.dart';
import 'help_screen.dart';
import '../widgets/sera_orb.dart';

// ─── MAIN NAV SCREEN ─────────────────────────────────────────────────────────

/// Root scaffold. Houses the IndexedStack of all 5 tabs and the bottom nav.
class MainNavScreen extends StatelessWidget {
  const MainNavScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationNotifier>(
      builder: (context, nav, _) {
        return Scaffold(
          backgroundColor: VuiTheme.background,
          body: Stack(
            children: [
              IndexedStack(
                index: nav.currentIndex,
                children: const [
                  HomeScreen(),
                  MoodScreen(),
                  BreatheScreen(),
                  SleepScreen(),
                  HelpScreen(),
                ],
              ),
              // Speech Overlay
              Consumer<VuiStateManager>(
                builder: (context, mgr, _) {
                  if (mgr.state == VuiState.idle || mgr.state == VuiState.guiding) {
                    return const SizedBox.shrink();
                  }
                  
                  String displayText = '';
                  if (mgr.state == VuiState.listening) {
                    displayText = mgr.speechText.isEmpty ? 'Listening...' : mgr.speechText;
                  } else if (mgr.state == VuiState.speaking) {
                    // Show Sera's last chat message
                    if (mgr.chatHistory.isNotEmpty) {
                      displayText = mgr.chatHistory.last['text'] ?? '';
                    } else {
                      displayText = 'Speaking...';
                    }
                  } else if (mgr.state == VuiState.processing) {
                    displayText = 'Processing: "${mgr.speechText}"';
                  }

                  return Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: displayText.isNotEmpty ? 1.0 : 0.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1F22).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: VuiTheme.moodColor.withValues(alpha: 0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Text(
                          displayText,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          bottomNavigationBar: _BottomNav(
            currentIndex: nav.currentIndex,
            onTap: (i) {
              nav.navigateTo(i);
              _onTabChange(context, i);
            },
          ),
        );
      },
    );
  }

  /// Transition the VUI module when switching tabs so Sera greets
  /// the user with the right context.
  void _onTabChange(BuildContext context, int index) {
    final mgr = Provider.of<VuiStateManager>(context, listen: false);
    switch (index) {
      case 1:
        mgr.transitionToModule(VuiModule.mood);
        break;
      case 2:
        mgr.transitionToModule(VuiModule.breathing);
        break;
      case 3:
        mgr.transitionToModule(VuiModule.sleep);
        break;
      // 0 (Home) and 4 (Help) keep their current module state
    }
  }
}

// ─── BOTTOM NAV ──────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Tab definitions: icon, label, active colour
    final tabs = [
      _Tab(Icons.home_rounded, 'Home', VuiTheme.moodColor),
      _Tab(Icons.mood_rounded, 'Mood', VuiTheme.moodColor),
      _Tab(Icons.air_rounded, 'Breathe', VuiTheme.breathingColor),
      _Tab(Icons.bedtime_rounded, 'Sleep', VuiTheme.sleepColor),
      _Tab(Icons.health_and_safety_outlined, 'Help', VuiTheme.crisisColor),
    ];

    return Container(
      decoration: BoxDecoration(
        color: VuiTheme.background,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 0.8,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTab(tabs[0], 0, currentIndex == 0),
              _buildTab(tabs[1], 1, currentIndex == 1),
              _buildTab(tabs[2], 2, currentIndex == 2),
              _buildTab(tabs[3], 3, currentIndex == 3),
              _buildTab(tabs[4], 4, currentIndex == 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(_Tab t, int index, bool selected) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              t.icon,
              size: 22,
              color: selected ? t.color : Colors.white.withValues(alpha: 0.28),
            ),
            const SizedBox(height: 4),
            Text(
              t.label,
              style: GoogleFonts.dmSans(
                color: selected ? t.color : Colors.white.withValues(alpha: 0.28),
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab {
  final IconData icon;
  final String label;
  final Color color;
  const _Tab(this.icon, this.label, this.color);
}
