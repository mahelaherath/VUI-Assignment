import 'package:flutter/material.dart';

/// Reusable pulsing VUI orb widget used on every screen.
/// Pass [isActive] = true when the mic is listening or speaking.
class SeraOrb extends StatefulWidget {
  final Color color;
  final double orbSize;
  final IconData icon;
  final bool isActive;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final VoidCallback? onTap;

  const SeraOrb({
    super.key,
    required this.color,
    this.orbSize = 74,
    this.icon = Icons.mic_rounded,
    this.isActive = false,
    this.onTapDown,
    this.onTapUp,
    this.onTap,
  });

  @override
  State<SeraOrb> createState() => _SeraOrbState();
}

class _SeraOrbState extends State<SeraOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = widget.orbSize;
    return GestureDetector(
      onTapDown: widget.onTapDown,
      onTapUp: widget.onTapUp,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) {
          // Outer ring fades and expands
          final outerOpacity = widget.isActive
              ? (1 - _pulse.value) * 0.45
              : (1 - _pulse.value) * 0.18;
          final outerSize = sz + 36 + (_pulse.value * 14);

          return SizedBox(
            width: sz + 60,
            height: sz + 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer pulsing ring
                Container(
                  width: outerSize,
                  height: outerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.color.withOpacity(outerOpacity),
                      width: 1,
                    ),
                  ),
                ),
                // Static inner ring
                Container(
                  width: sz + 16,
                  height: sz + 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.color
                          .withOpacity(widget.isActive ? 0.48 : 0.28),
                      width: 1.5,
                    ),
                  ),
                ),
                // Core button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  width: sz,
                  height: sz,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color
                        .withOpacity(widget.isActive ? 0.20 : 0.10),
                    border: Border.all(
                      color: widget.color,
                      width: widget.isActive ? 2.4 : 1.8,
                    ),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.color,
                    size: sz * 0.36,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
