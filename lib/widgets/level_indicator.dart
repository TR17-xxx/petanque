import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

const double _tolerance = 0.07; // ~4° tolerance

class LevelIndicator extends StatefulWidget {
  final ValueChanged<bool>? onLevelChange;

  const LevelIndicator({super.key, this.onLevelChange});

  @override
  State<LevelIndicator> createState() => _LevelIndicatorState();
}

class _LevelIndicatorState extends State<LevelIndicator> {
  double _x = 0;
  double _y = 0;
  bool _isLevel = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((event) {
      if (!mounted) return;
      // Normalize: event.x and event.y are in m/s², gravity ~ 9.8
      // For a flat phone: x ≈ 0, y ≈ 0, z ≈ 9.8
      final nx = event.x / 9.8;
      final ny = event.y / 9.8;
      final level = nx.abs() < _tolerance && ny.abs() < _tolerance;
      setState(() {
        _x = nx;
        _y = ny;
        _isLevel = level;
      });
      widget.onLevelChange?.call(level);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Bubble position (clamped to -1..1), scaled to 30px
    final bubbleX = _x.clamp(-1.0, 1.0) * 30;
    final bubbleY = (-_y).clamp(-1.0, 1.0) * 30;

    final bgColor = _isLevel
        ? const Color(0x4D22C55E) // green 30%
        : const Color(0x4DEF4444); // red 30%
    final borderColor =
        _isLevel ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final bubbleColor =
        _isLevel ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bubble level circle
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Cross lines
              Container(
                width: 1,
                height: 40,
                color: borderColor.withValues(alpha: 0.4),
              ),
              Container(
                width: 40,
                height: 1,
                color: borderColor.withValues(alpha: 0.4),
              ),
              // Bubble
              Transform.translate(
                offset: Offset(bubbleX, bubbleY),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: bubbleColor.withValues(alpha: 0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isLevel ? 'Niveau OK' : 'Mettez à plat',
          style: TextStyle(
            color: _isLevel
                ? const Color(0xFF22C55E)
                : const Color(0xFFFBBF24),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
