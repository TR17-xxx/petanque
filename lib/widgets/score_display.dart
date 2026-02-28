import 'package:flutter/material.dart';
import 'package:petanque_score/models/game.dart';
import 'package:petanque_score/utils/colors.dart';

/// Darkens a color by the given [amount] (0.0 – 1.0).
Color _darken(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
      .toColor();
}

/// Lightens a color by the given [amount] (0.0 – 1.0).
Color _lighten(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
      .toColor();
}

// ────────────────────────────────────────────────────────────────────────────
// Diagonal clip for team panels
// ────────────────────────────────────────────────────────────────────────────

class _LeftDiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final skew = size.height * 0.15;
    final mid = size.width / 2;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(mid + skew, 0)
      ..lineTo(mid - skew, size.height)
      ..lineTo(0, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _RightDiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final skew = size.height * 0.15;
    final mid = size.width / 2;
    final path = Path()
      ..moveTo(mid + skew, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(mid - skew, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ────────────────────────────────────────────────────────────────────────────
// Animated score text
// ────────────────────────────────────────────────────────────────────────────

class _AnimatedScore extends StatefulWidget {
  const _AnimatedScore({required this.score, required this.color});

  final int score;
  final Color color;

  @override
  State<_AnimatedScore> createState() => _AnimatedScoreState();
}

class _AnimatedScoreState extends State<_AnimatedScore>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.95), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant _AnimatedScore old) {
    super.didUpdateWidget(old);
    if (widget.score != old.score) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnim.value,
        child: child,
      ),
      child: Text(
        '${widget.score}',
        style: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1.0,
          shadows: [
            Shadow(
              color: _darken(widget.color, 0.3).withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// ScoreDisplay – main widget
// ────────────────────────────────────────────────────────────────────────────

class ScoreDisplay extends StatelessWidget {
  const ScoreDisplay({
    super.key,
    required this.team1,
    required this.team2,
    required this.score1,
    required this.score2,
    this.targetScore = 13,
  });

  final Team team1;
  final Team team2;
  final int score1;
  final int score2;
  final int targetScore;

  @override
  Widget build(BuildContext context) {
    final color1 = parseHex(team1.color);
    final color2 = parseHex(team2.color);
    final progress1 = (score1 / targetScore).clamp(0.0, 1.0);
    final progress2 = (score2 / targetScore).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _darken(color1, 0.2).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(-4, 8),
            ),
            BoxShadow(
              color: _darken(color2, 0.2).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(4, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 250,
          child: Stack(
            children: [
              // ── Team 1 background (left, with diagonal cut) ──
              Positioned.fill(
                child: ClipPath(
                  clipper: _LeftDiagonalClipper(),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _lighten(color1, 0.08),
                          color1,
                          _darken(color1, 0.12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Team 2 background (right, with diagonal cut) ──
              Positioned.fill(
                child: ClipPath(
                  clipper: _RightDiagonalClipper(),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          _lighten(color2, 0.08),
                          color2,
                          _darken(color2, 0.12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Content overlay ──
              Row(
                children: [
                  // Team 1
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            team1.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.85),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _AnimatedScore(score: score1, color: color1),
                          const SizedBox(height: 10),
                          // Progress bar
                          _ProgressBar(
                            progress: progress1,
                            color: Colors.white,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Team 2
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 24, right: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            team2.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.85),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _AnimatedScore(score: score2, color: color2),
                          const SizedBox(height: 10),
                          _ProgressBar(
                            progress: progress2,
                            color: Colors.white,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ── Center "VS" badge ──
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'VS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Target score chip (top center) ──
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Objectif : $targetScore pts',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.8),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Small progress bar
// ────────────────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  final double progress;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      width: 80,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
