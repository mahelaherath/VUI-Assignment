import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../vui/vui_theme.dart';
import '../vui/vui_state_manager.dart';
import '../vui/dialogue_engine.dart';
import '../widgets/sera_orb.dart';

// ─── MOOD SCREEN ─────────────────────────────────────────────────────────────

class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  int _selectedEmoji = 0;

  static const _emojis = ['😊', '😌', '😢', '😤', '😭'];
  static const _moodLabels = ['Happy', 'Calm', 'Sad', 'Angry', 'Distressed'];

  // Weekly mood values (0.0–1.0); Thursday = index 3 is peak
  static const _weekValues = [0.40, 0.70, 0.60, 1.0, 0.50, 0.20, 0.10];
  static const _weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final mgr = Provider.of<VuiStateManager>(context);
    final isActive = mgr.state == VuiState.listening ||
        mgr.state == VuiState.speaking;

    // Find last Sera message to display
    final seraMessages =
        mgr.chatHistory.where((m) => m['sender'] == 'Sera').toList();
    final responseText = seraMessages.isNotEmpty
        ? (seraMessages.last['text'] ?? '')
        : 'I hear you feel anxious today…';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Screen header ───────────────────────────────────
            _ScreenHeader(
              icon: Icons.mood_rounded,
              color: VuiTheme.moodColor,
              title: 'Mood tracking',
            ),

            const SizedBox(height: 28),

            // ── VUI orb ─────────────────────────────────────────
            Center(
              child: SeraOrb(
                color: VuiTheme.moodColor,
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
                '"Tell me how you\'re feeling"',
                style: GoogleFonts.dmSans(
                  color: Colors.white54,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Emoji picker ─────────────────────────────────────
            Text(
              'Or pick your mood',
              style: GoogleFonts.dmSans(
                color: Colors.white60,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_emojis.length, (i) {
                final sel = _selectedEmoji == i;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedEmoji = i);
                    mgr.submitSimulatedSpeech(_moodLabels[i]);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sel
                          ? VuiTheme.moodColor.withOpacity(0.16)
                          : const Color(0xFF16181E),
                      border: Border.all(
                        color: sel
                            ? VuiTheme.moodColor
                            : const Color(0xFF2A2D3A),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _emojis[i],
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),

            // ── Voice response card ──────────────────────────────
            _VoiceResponseCard(
              text: responseText,
              color: VuiTheme.moodColor,
            ),

            const SizedBox(height: 16),

            // ── Weekly mood chart ────────────────────────────────
            _WeeklyMoodCard(
              values: _weekValues,
              days: _weekDays,
              color: VuiTheme.moodColor,
              highlightIndex: 3, // Thursday
            ),
          ],
        ),
      ),
    );
  }
}

// ─── VOICE RESPONSE CARD ─────────────────────────────────────────────────────

class _VoiceResponseCard extends StatelessWidget {
  final String text;
  final Color color;

  const _VoiceResponseCard({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    const barHeights = [12.0, 22.0, 30.0, 22.0, 30.0, 14.0];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16181E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Voice response',
            style: GoogleFonts.dmSans(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Waveform bars
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(barHeights.length, (i) {
                  return Container(
                    width: 3,
                    height: barHeights[i],
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '"$text"',
                  style: GoogleFonts.dmSans(
                    color: Colors.white70,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── WEEKLY MOOD CHART ───────────────────────────────────────────────────────

class _WeeklyMoodCard extends StatelessWidget {
  final List<double> values;
  final List<String> days;
  final Color color;
  final int highlightIndex;

  const _WeeklyMoodCard({
    required this.values,
    required this.days,
    required this.color,
    required this.highlightIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16181E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly mood',
            style: GoogleFonts.dmSans(
              color: Colors.white60,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 90,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(values.length, (i) {
                final isHigh = i == highlightIndex;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: values[i].clamp(0.06, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isHigh
                                      ? color
                                      : color.withOpacity(0.32),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          days[i],
                          style: GoogleFonts.dmSans(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
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
