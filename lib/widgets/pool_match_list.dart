import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:petanque_score/models/tournament.dart';
import 'package:petanque_score/providers/theme_provider.dart';
import 'package:petanque_score/utils/colors.dart';

class PoolMatchList extends StatelessWidget {
  final Pool pool;
  final List<TournamentTeam> teams;
  final Function(String matchId) onMatchPress;

  const PoolMatchList({
    super.key,
    required this.pool,
    required this.teams,
    required this.onMatchPress,
  });

  TournamentTeam? _getTeam(String teamId) {
    return teams.where((t) => t.id == teamId).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final themeColor600 = theme.colors.shade600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final match in pool.matches) ...[
          _buildMatchItem(match, themeColor600),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildMatchItem(PoolMatch match, Color themeColor600) {
    final team1 = _getTeam(match.team1Id);
    final team2 = _getTeam(match.team2Id);
    final isPlayed = match.score1 != null && match.score2 != null;
    final color1 = team1 != null ? parseHex(team1.color) : slate400;
    final color2 = team2 != null ? parseHex(team2.color) : slate400;

    return GestureDetector(
      onTap: () => onMatchPress(match.id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: isPlayed
              ? Border.all(color: slate200, width: 1)
              : Border.all(
                  color: slate400,
                  width: 1,
                  style: BorderStyle.solid,
                ),
          boxShadow: isPlayed
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Team 1
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color1, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      team1?.name ?? '?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: match.winnerId == match.team1Id ? FontWeight.w700 : FontWeight.w500,
                        color: slate800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Score or VS
            if (isPlayed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: slate100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${match.score1}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: match.winnerId == match.team1Id ? themeColor600 : slate500,
                      ),
                    ),
                    const Text(
                      ' - ',
                      style: TextStyle(fontSize: 12, color: slate400),
                    ),
                    Text(
                      '${match.score2}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: match.winnerId == match.team2Id ? themeColor600 : slate500,
                      ),
                    ),
                    if (match.isFanny) ...[
                      const SizedBox(width: 6),
                      const Text('\u{1F351}', style: TextStyle(fontSize: 12)), // peach emoji
                    ],
                  ],
                ),
              )
            else
              const Text(
                'vs',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: slate400),
              ),

            // Team 2
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      team2?.name ?? '?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: match.winnerId == match.team2Id ? FontWeight.w700 : FontWeight.w500,
                        color: slate800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color2, shape: BoxShape.circle),
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
