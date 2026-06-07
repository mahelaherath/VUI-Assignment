import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../vui/vui_theme.dart';
import '../vui/vui_state_manager.dart';
import '../widgets/sera_orb.dart';

// ─── BREATHING SCREEN ────────────────────────────────────────────────────────

enum _Phase { ready, inhale, hold, exhale }

enum _Technique { t478, box, belly }

class BreatheScreen extends StatefulWidget {
  const BreatheScreen({super.key});

  @override
  State<BreatheScreen> createState() => _BreatheScreenState();
}

class _BreatheScreenState extends State<BreatheScreen>
    with SingleTickerProviderStateMixin {
  _Technique _tech = _Technique.t478;
  _Phase _phase = _Phase.ready;
  bool _running = false;
  int _countdownVal = 4;
  int _cycle = 0;
  static const _totalCycles = 3;
  Timer? _timer;

  late final AnimationController _circle;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _circle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(parent: _circle, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _circle.dispose();
    super.dispose();
  }

  // ── Timing per technique ─────────────────────────────────────────────────

  int get _inhaleS {
    switch (_tech) {
      case _Technique.t478:
        return 4;
      case _Technique.box:
        return 4;
      case _Technique.belly:
        return 5;
    }
  }

  int get _holdS {
    switch (_tech) {
      case _Technique.t478:
        return 7;
      case _Technique.box:
        return 4;
      case _Technique.belly:
        return 0;
    }
  }

  int get _exhaleS {
    switch (_tech) {
      case _Technique.t478:
        return 8;
      case _Technique.box:
        return 4;
      case _Technique.belly:
        return 5;
    }
  }

  // ── Control ──────────────────────────────────────────────────────────────

  void _start() {
    if (_cycle == 0) {
      setState(() {
        _running = true;
        _cycle = 1;
      });
    } else {
      setState(() => _running = true);
    }
    _doInhale();
    Provider.of<VuiStateManager>(context, listen: false)
        .startBreathingExercise();
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _running = false);
    Provider.of<VuiStateManager>(context, listen: false).pauseBreathing();
  }

  void _reset() {
    _timer?.cancel();
    _circle.reverse();
    setState(() {
      _running = false;
      _phase = _Phase.ready;
      _cycle = 0;
      _countdownVal = _inhaleS;
    });
    Provider.of<VuiStateManager>(context, listen: false).stopBreathing();
  }

  void _changeTech(_Technique t) {
    _reset();
    setState(() => _tech = t);
  }

  // ── Phase runners ─────────────────────────────────────────────────────────

  void _doInhale() {
    _circle.duration = Duration(seconds: _inhaleS);
    _circle.forward(from: 0.0);
    setState(() {
      _phase = _Phase.inhale;
      _countdownVal = _inhaleS;
    });
    _runCountdown(_inhaleS, _holdS > 0 ? _doHold : _doExhale);
  }

  void _doHold() {
    setState(() {
      _phase = _Phase.hold;
      _countdownVal = _holdS;
    });
    _runCountdown(_holdS, _doExhale);
  }

  void _doExhale() {
    _circle.duration = Duration(seconds: _exhaleS);
    _circle.reverse(from: 1.0);
    setState(() {
      _phase = _Phase.exhale;
      _countdownVal = _exhaleS;
    });
    _runCountdown(_exhaleS, () {
      if (!_running) return;
      if (_cycle < _totalCycles) {
        setState(() => _cycle++);
        _doInhale();
      } else {
        _reset();
      }
    });
  }

  void _runCountdown(int secs, VoidCallback onDone) {
    _timer?.cancel();
    int remaining = secs;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _countdownVal = remaining);
      remaining--;
      if (remaining < 0) {
        t.cancel();
        if (_running) onDone();
      }
    });
  }

  // ── Labels ────────────────────────────────────────────────────────────────

  String get _phaseLabel {
    switch (_phase) {
      case _Phase.ready:
        return 'Ready';
      case _Phase.inhale:
        return 'Inhale';
      case _Phase.hold:
        return 'Hold';
      case _Phase.exhale:
        return 'Exhale';
    }
  }

  String get _instruction {
    switch (_phase) {
      case _Phase.ready:
        return 'Tap the button below to begin';
      case _Phase.inhale:
        return 'Breathe in through your nose';
      case _Phase.hold:
        return 'Hold your breath gently';
      case _Phase.exhale:
        return 'Slowly breathe out through your mouth';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final color = VuiTheme.breathingColor;

    // Dots: 3 phases. For belly (no hold) middle dot is dim.
    final phases = [_Phase.inhale, _Phase.hold, _Phase.exhale];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────
            _ScreenHeader(
              icon: Icons.air_rounded,
              color: color,
              title: 'Breathing exercise',
            ),

            const SizedBox(height: 24),

            // ── Technique tabs ───────────────────────────────────
            Row(
              children: [
                _TechTab(
                  label: '4-7-8',
                  selected: _tech == _Technique.t478,
                  color: color,
                  onTap: () => _changeTech(_Technique.t478),
                ),
                const SizedBox(width: 10),
                _TechTab(
                  label: 'Box',
                  selected: _tech == _Technique.box,
                  color: color,
                  onTap: () => _changeTech(_Technique.box),
                ),
                const SizedBox(width: 10),
                _TechTab(
                  label: 'Belly',
                  selected: _tech == _Technique.belly,
                  color: color,
                  onTap: () => _changeTech(_Technique.belly),
                ),
              ],
            ),

            const SizedBox(height: 36),

            // ── Breathing circle ─────────────────────────────────
            Center(
              child: AnimatedBuilder(
                animation: _scale,
                builder: (_, __) {
                  return Transform.scale(
                    scale: _running ? _scale.value : 0.80,
                    child: Container(
                      width: 165,
                      height: 165,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(0.07),
                        border: Border.all(color: color, width: 2.2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _phaseLabel,
                            style: GoogleFonts.dmSans(
                              color: color,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _running ? '$_countdownVal' : '–',
                            style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 18),

            Center(
              child: Text(
                _instruction,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
            ),

            const SizedBox(height: 18),

            // ── Phase dots ───────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final ph = phases[i];
                final active = _phase == ph;
                final irrelevant =
                    _tech == _Technique.belly && ph == _Phase.hold;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: active ? 10 : 8,
                  height: active ? 10 : 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: irrelevant
                        ? color.withOpacity(0.10)
                        : active
                            ? color
                            : color.withOpacity(0.28),
                  ),
                );
              }),
            ),

            const SizedBox(height: 28),

            // ── Orb (play / pause) ───────────────────────────────
            Center(
              child: SeraOrb(
                color: color,
                orbSize: 60,
                icon: _running
                    ? Icons.pause_rounded
                    : (_phase == _Phase.ready
                        ? Icons.play_arrow_rounded
                        : Icons.play_arrow_rounded),
                isActive: _running,
                onTap: () {
                  if (_phase == _Phase.ready) {
                    _start();
                  } else if (_running) {
                    _pause();
                  } else {
                    _start();
                  }
                },
              ),
            ),

            const SizedBox(height: 10),

            Center(
              child: Text(
                _running
                    ? 'Voice-guided, tap to pause'
                    : _phase == _Phase.ready
                        ? 'Tap to start'
                        : 'Paused — tap to resume',
                style: GoogleFonts.dmSans(
                  color: Colors.white38,
                  fontSize: 13,
                ),
              ),
            ),

            const SizedBox(height: 22),

            // ── Session progress ─────────────────────────────────
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
                    'Session progress',
                    style: GoogleFonts.dmSans(
                      color: Colors.white54,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _cycle == 0
                          ? 0.0
                          : _cycle / _totalCycles,
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _cycle == 0
                        ? 'Ready to begin'
                        : 'Cycle $_cycle of $_totalCycles · ~${(_totalCycles - _cycle + 1)} min remaining',
                    style: GoogleFonts.dmSans(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── TECHNIQUE TAB ───────────────────────────────────────────────────────────

class _TechTab extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TechTab({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            color: selected ? color : Colors.white38,
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ─── SHARED SCREEN HEADER (defined locally for this file) ────────────────────

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
