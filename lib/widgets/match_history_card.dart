import 'package:flutter/material.dart';
import 'package:petanque_score/models/game.dart';
import 'package:petanque_score/utils/helpers.dart';
import 'package:petanque_score/utils/colors.dart';

// ── Local constants not in centralized colors ──
const _slate600 = Color(0xFF475569);

/// Game history card widget.
///
/// Displays a summary of a completed (or in-progress) game: date, team names,
/// scores, and round count. Supports selection mode with a long-press gesture
/// (shows a check-circle icon when selected).
///
/// Port of `MatchHistory.tsx` from the React Native app.
class MatchHistoryCard extends StatelessWidget {
  const MatchHistoryCard({
    super.key,
    required this.game,
    this.selectionMode = false,
    this.selected = false,
    this.onLongPress,
    this.onPress,
  });

  final Game game;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onLongPress;
  final VoidCallback? onPress;

  @override
  Widget build(BuildContext context) {
    // Derive scores from the last round's totalAfter, or default to 0-0.
    final lastRound = game.rounds.isNotEmpty ? game.rounds.last : null;
    final score1 = lastRound != null ? lastRound.totalAfter[0] : 0;
    final score2 = lastRound != null ? lastRound.totalAfter[1] : 0;
    final winnerId = game.winnerId;

    final color1 = parseHex(game.team1.color);
    final color2 = parseHex(game.team2.color);

    return GestureDetector(
      onLongPress: onLongPress,
      onTap: onPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFEF2F2) : Colors.white, // red-50
          borderRadius: BorderRadius.circular(16),
          border: selected
              ? Border.all(color: const Color(0xFFF87171), width: 2) // red-400
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Selection icon ──
            if (selectionMode) ...[
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 24,
                color: selected
                    ? const Color(0xFFEF4444) // red-500
                    : slate300,
              ),
              const SizedBox(width: 12),
            ],

            // ── Content ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Date
                  Text(
                    formatGameDate(game.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: slate400,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Teams + Score row
                  Row(
                    children: [
                      // Team names column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _TeamNameRow(
                              name: game.team1.name,
                              isWinner: winnerId == 1,
                            ),
                            const SizedBox(height: 4),
                            _TeamNameRow(
                              name: game.team2.name,
                              isWinner: winnerId == 2,
                            ),
                          ],
                        ),
                      ),

                      // Score + rounds column
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            // Score
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '$score1',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color:
                                        winnerId == 1 ? color1 : slate400,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    '-',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: slate300,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$score2',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color:
                                        winnerId == 2 ? color2 : slate400,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Round count
                            Text(
                              '${game.rounds.length} mène${game.rounds.length > 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: slate400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

/// Internal widget that renders a single team name row with an optional trophy
/// emoji for the winner.
class _TeamNameRow extends StatelessWidget {
  const _TeamNameRow({
    required this.name,
    required this.isWinner,
  });

  final String name;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isWinner)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Text(
              '\u{1F3C6}', // 🏆
              style: TextStyle(fontSize: 14),
            ),
          ),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isWinner ? FontWeight.w700 : FontWeight.w400,
              color: isWinner ? slate800 : _slate600,
            ),
          ),
        ),
      ],
    );
  }
}
