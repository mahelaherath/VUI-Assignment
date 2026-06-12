import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../vui/vui_theme.dart';
import '../vui/vui_state_manager.dart';
import '../vui/dialogue_engine.dart';
import '../widgets/sera_orb.dart';

// ─── SLEEP SCREEN ────────────────────────────────────────────────────────────

class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key});

  static const _tips = [
    _SleepTipData(
      icon: Icons.phone_android_outlined,
      title: 'No screens 1hr before bed',
      subtitle: 'Blue light affects melatonin production',
    ),
    _SleepTipData(
      icon: Icons.device_thermostat_outlined,
      title: 'Keep room cool (18–20°C)',
      subtitle: 'For deep sleep cycles',
    ),
    _SleepTipData(
      icon: Icons.access_time_rounded,
      title: 'Consistent wake time',
      subtitle: 'Even on weekends',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final mgr = Provider.of<VuiStateManager>(context);
    final color = VuiTheme.sleepColor;
    final isActive =
        mgr.state == VuiState.listening || mgr.state == VuiState.speaking;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────
            _ScreenHeader(
              icon: Icons.bedtime_rounded,
              color: color,
              title: 'Sleep hygiene',
            ),

            const SizedBox(height: 28),

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
                '"Ask about your sleep routine"',
                style: GoogleFonts.dmSans(
                  color: Colors.white54,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Tonight's routine card ───────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16181E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Tonight's routine",
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(_tips.length, (i) {
                    return Column(
                      children: [
                        _SleepTipRow(tip: _tips[i], color: color, index: i),
                        if (i < _tips.length - 1)
                          Divider(
                            color: Colors.white.withValues(alpha: 0.05),
                            height: 1,
                            thickness: 1,
                          ),
                      ],
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Last night stats ─────────────────────────────────
            GestureDetector(
              onTap: () async {
                int currentHours = mgr.sleepHours;
                int currentMinutes = mgr.sleepMinutes;
                await showDialog(
                  context: context,
                  builder: (context) {
                    return _SleepDurationDialog(
                      initialHours: currentHours,
                      initialMinutes: currentMinutes,
                      color: color,
                      onSave: (h, m) {
                        mgr.updateSleepTime(h, m);
                      },
                    );
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF16181E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last night',
                          style: GoogleFonts.dmSans(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${mgr.sleepHours}h\n${mgr.sleepMinutes}m',
                          style: GoogleFonts.dmSans(
                            color: color,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Quality',
                          style: GoogleFonts.dmSans(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          mgr.sleepQuality,
                          style: GoogleFonts.dmSans(
                            color: mgr.sleepQualityColor,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── DATA CLASS ──────────────────────────────────────────────────────────────

class _SleepTipData {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SleepTipData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

// ─── INTERACTIVE CHECKLIST ROW ───────────────────────────────────────────────

class _SleepTipRow extends StatelessWidget {
  final _SleepTipData tip;
  final Color color;
  final int index;

  const _SleepTipRow({
    required this.tip,
    required this.color,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final mgr = Provider.of<VuiStateManager>(context);
    final done = mgr.routineChecklist[index];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Checkbox
          GestureDetector(
            onTap: () => mgr.toggleChecklistItem(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: done ? color.withValues(alpha: 0.15) : Colors.transparent,
                border: Border.all(
                  color: done ? color : Colors.white24,
                  width: 1.5,
                ),
              ),
              child: done
                  ? Icon(Icons.check_rounded, color: color, size: 16)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.title,
                  style: GoogleFonts.dmSans(
                    color: done ? Colors.white38 : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.white38,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  tip.subtitle,
                  style: GoogleFonts.dmSans(
                    color: Colors.white38,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
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
            border: Border.all(color: color.withValues(alpha: 0.55), width: 1.5),
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

// ─── SLEEP DURATION DIALOG ───────────────────────────────────────────────────

class _SleepDurationDialog extends StatefulWidget {
  final int initialHours;
  final int initialMinutes;
  final Color color;
  final Function(int, int) onSave;

  const _SleepDurationDialog({
    required this.initialHours,
    required this.initialMinutes,
    required this.color,
    required this.onSave,
  });

  @override
  State<_SleepDurationDialog> createState() => _SleepDurationDialogState();
}

class _SleepDurationDialogState extends State<_SleepDurationDialog> {
  late int _hours;
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _hours = widget.initialHours;
    _minutes = widget.initialMinutes;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF16181E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        'Log Sleep Time',
        style: GoogleFonts.dmSans(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hours dropdown
          DropdownButton<int>(
            dropdownColor: const Color(0xFF1E1F22),
            value: _hours,
            style: GoogleFonts.dmSans(color: Colors.white, fontSize: 18),
            items: List.generate(25, (i) {
              return DropdownMenuItem<int>(
                value: i,
                child: Text('$i hrs'),
              );
            }),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _hours = val;
                });
              }
            },
          ),
          const SizedBox(width: 20),
          // Minutes dropdown
          DropdownButton<int>(
            dropdownColor: const Color(0xFF1E1F22),
            value: _minutes,
            style: GoogleFonts.dmSans(color: Colors.white, fontSize: 18),
            items: List.generate(60, (i) {
              return DropdownMenuItem<int>(
                value: i,
                child: Text('$i mins'),
              );
            }),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _minutes = val;
                });
              }
            },
          ),
        ],
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
            widget.onSave(_hours, _minutes);
            Navigator.pop(context);
          },
          child: Text(
            'Save',
            style: GoogleFonts.dmSans(color: widget.color),
          ),
        ),
      ],
    );
  }
}
