import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:petanque_score/models/game.dart';
import 'package:petanque_score/providers/theme_provider.dart';
import 'package:petanque_score/utils/colors.dart';

// ────────────────────────────────────────────────────────────────────────────
// TeamButton – selectable team button with animated scale on press
// ────────────────────────────────────────────────────────────────────────────

class _TeamButton extends StatefulWidget {
  const _TeamButton({
    required this.team,
    required this.selected,
    required this.onPress,
    required this.isFirst,
  });

  final Team team;
  final bool selected;
  final VoidCallback onPress;
  final bool isFirst; // true for team1 (add right margin), false for team2

  @override
  State<_TeamButton> createState() => _TeamButtonState();
}

class _TeamButtonState extends State<_TeamButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamColor = parseHex(widget.team.color);

    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(
          right: widget.isFirst ? 8 : 0,
          left: widget.isFirst ? 0 : 8,
        ),
        child: GestureDetector(
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) {
            _controller.reverse();
            widget.onPress();
          },
          onTapCancel: () => _controller.reverse(),
          child: AnimatedBuilder(
            animation: _scaleAnim,
            builder: (context, child) => Transform.scale(
              scale: _scaleAnim.value,
              child: child,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: widget.selected ? teamColor : slate100,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                widget.team.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: widget.selected ? Colors.white : slate700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// PointButton – square-ish button for selecting points 1-6
// ────────────────────────────────────────────────────────────────────────────

class _PointButton extends StatefulWidget {
  const _PointButton({
    required this.point,
    required this.selected,
    required this.disabled,
    required this.teamColor,
    required this.onPress,
  });

  final int point;
  final bool selected;
  final bool disabled;
  final Color teamColor;
  final VoidCallback onPress;

  @override
  State<_PointButton> createState() => _PointButtonState();
}

class _PointButtonState extends State<_PointButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.disabled ? null : (_) => _controller.forward(),
      onTapUp: widget.disabled
          ? null
          : (_) {
              _controller.reverse();
              widget.onPress();
            },
      onTapCancel: widget.disabled ? null : () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: widget.disabled ? 0.4 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: widget.selected ? widget.teamColor : slate100,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              '${widget.point}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: widget.selected ? Colors.white : slate700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// RoundInput – main widget
// ────────────────────────────────────────────────────────────────────────────

/// Team selector + point grid card for recording a round ("mène").
///
/// Port of `RoundInput.tsx` from the React Native app.
class RoundInput extends StatefulWidget {
  const RoundInput({
    super.key,
    required this.roundNumber,
    required this.team1,
    required this.team2,
    this.preselectedWinner,
    this.preselectedPoints,
    required this.onValidate,
  });

  final int roundNumber;
  final Team team1;
  final Team team2;
  final int? preselectedWinner;
  final int? preselectedPoints;
  final void Function(int winnerId, int points) onValidate;

  @override
  State<RoundInput> createState() => _RoundInputState();
}

class _RoundInputState extends State<RoundInput> {
  int? _selectedTeam;
  int? _selectedPoints;

  @override
  void initState() {
    super.initState();
    _selectedTeam = widget.preselectedWinner;
    _selectedPoints = widget.preselectedPoints;
  }

  @override
  void didUpdateWidget(covariant RoundInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.preselectedWinner != oldWidget.preselectedWinner &&
        widget.preselectedWinner != null) {
      setState(() => _selectedTeam = widget.preselectedWinner);
    }
    if (widget.preselectedPoints != oldWidget.preselectedPoints &&
        widget.preselectedPoints != null) {
      setState(() => _selectedPoints = widget.preselectedPoints);
    }
  }

  bool get _canValidate => _selectedTeam != null && _selectedPoints != null;

  Color get _activeColor {
    if (_selectedTeam == 1) return parseHex(widget.team1.color);
    if (_selectedTeam == 2) return parseHex(widget.team2.color);
    return slate400;
  }

  void _handleValidate() {
    if (_canValidate) {
      widget.onValidate(_selectedTeam!, _selectedPoints!);
      setState(() {
        _selectedTeam = null;
        _selectedPoints = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = context.watch<ThemeProvider>().colors;

    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Title + team selector on same row ──
            Row(
              children: [
                Text(
                  'Mène ${widget.roundNumber}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: slate800,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Qui marque ?',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: slate400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _TeamButton(
                  team: widget.team1,
                  selected: _selectedTeam == 1,
                  onPress: () => setState(() => _selectedTeam = 1),
                  isFirst: true,
                ),
                _TeamButton(
                  team: widget.team2,
                  selected: _selectedTeam == 2,
                  onPress: () => setState(() => _selectedTeam = 2),
                  isFirst: false,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Points: 6 buttons in a single row ──
            const Text(
              'Combien de points ?',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: slate400,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: List.generate(6, (i) {
                final point = i + 1;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: _PointButton(
                        point: point,
                        selected: _selectedPoints == point,
                        disabled: _selectedTeam == null,
                        teamColor: _activeColor,
                        onPress: () =>
                            setState(() => _selectedPoints = point),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),

            // ── Validate button ──
            GestureDetector(
              onTap: _canValidate ? _handleValidate : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _canValidate ? themeColors.shade600 : slate200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check,
                      size: 20,
                      color: _canValidate ? Colors.white : slate400,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Valider la mène',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _canValidate ? Colors.white : slate400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
    );
  }
}
