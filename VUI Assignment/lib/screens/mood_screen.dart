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
  static const _emojis = ['😊', '😌', '😢', '😤', '😭'];

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
                final sel = mgr.selectedEmojiIndex == i;
                return GestureDetector(
                  onTap: () {
                    mgr.selectEmoji(i);
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
              values: mgr.weekValues,
              days: mgr.weekDays,
              color: VuiTheme.moodColor,
              highlightIndex: mgr.highlightIndex,
            ),

            const SizedBox(height: 16),

            // ── Weekly mood analysis breakdown ───────────────────
            _WeeklyAnalysisCard(
              counts: mgr.weeklyMoodCounts,
              moodLabels: VuiStateManager.moodLabels,
              emojis: _emojis,
            ),

            const SizedBox(height: 20),

            // ── Reset weekly data button ──────────────────────────
            Center(
              child: TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF16181E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Text(
                        'Reset weekly data?',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      content: Text(
                        'This will delete all logged mood entries for this week and reset your analytics. This action cannot be undone.',
                        style: GoogleFonts.dmSans(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.dmSans(color: Colors.white38),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            mgr.resetWeeklyData();
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Reset',
                            style: GoogleFonts.dmSans(color: VuiTheme.crisisColor),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: VuiTheme.crisisColor,
                  size: 18,
                ),
                label: Text(
                  'Reset weekly data',
                  style: GoogleFonts.dmSans(
                    color: VuiTheme.crisisColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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

// ─── WEEKLY MOOD ANALYSIS Breakdown ─────────────────────────────────────────

class _WeeklyAnalysisCard extends StatelessWidget {
  final Map<String, int> counts;
  final List<String> moodLabels;
  final List<String> emojis;

  const _WeeklyAnalysisCard({
    required this.counts,
    required this.moodLabels,
    required this.emojis,
  });

  Color _getMoodColor(String mood) {
    switch (mood) {
      case 'Happy':
        return const Color(0xFFFBBF24); // Amber
      case 'Calm':
        return const Color(0xFF34D399); // Teal
      case 'Sad':
        return const Color(0xFF60A5FA); // Blue
      case 'Angry':
        return const Color(0xFFF87171); // Red
      case 'Distressed':
        return const Color(0xFFF472B6); // Pink
      default:
        return VuiTheme.moodColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold<int>(0, (sum, val) => sum + val);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16181E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly analysis',
                style: GoogleFonts.dmSans(
                  color: Colors.white60,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$total logs',
                style: GoogleFonts.dmSans(
                  color: Colors.white30,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: List.generate(moodLabels.length, (i) {
              final mood = moodLabels[i];
              final emoji = emojis[i];
              final count = counts[mood] ?? 0;
              final percent = total > 0 ? (count / total) : 0.0;
              final moodColor = _getMoodColor(mood);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$emoji $mood',
                          style: GoogleFonts.dmSans(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          count == 1 ? '1 log' : '$count logs',
                          style: GoogleFonts.dmSans(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Stack(
                      children: [
                        Container(
                          height: 6,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2D3A),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: percent,
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: moodColor,
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [
                                BoxShadow(
                                  color: moodColor.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
