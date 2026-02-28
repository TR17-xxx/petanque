import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:petanque_score/models/tournament.dart';
import 'package:petanque_score/providers/theme_provider.dart';
import 'package:petanque_score/utils/colors.dart';

class MatchCard extends StatelessWidget {
  /// Can be either a [PoolMatch] or a [BracketMatch].
  final dynamic match;
  final List<TournamentTeam> teams;
  final String? label;
  final VoidCallback onPress;

  const MatchCard({
    super.key,
    required this.match,
    required this.teams,
    this.label,
    required this.onPress,
  });

  TournamentTeam? _getTeam(String? teamId) {
    if (teamId == null) return null;
    return teams.where((t) => t.id == teamId).firstOrNull;
  }

  String? get _team1Id {
    if (match is PoolMatch) return (match as PoolMatch).team1Id;
    if (match is BracketMatch) return (match as BracketMatch).team1Id;
    return null;
  }

  String? get _team2Id {
    if (match is PoolMatch) return (match as PoolMatch).team2Id;
    if (match is BracketMatch) return (match as BracketMatch).team2Id;
    return null;
  }

  int? get _score1 {
    if (match is PoolMatch) return (match as PoolMatch).score1;
    if (match is BracketMatch) return (match as BracketMatch).score1;
    return null;
  }

  int? get _score2 {
    if (match is PoolMatch) return (match as PoolMatch).score2;
    if (match is BracketMatch) return (match as BracketMatch).score2;
    return null;
  }

  String? get _winnerId {
    if (match is PoolMatch) return (match as PoolMatch).winnerId;
    if (match is BracketMatch) return (match as BracketMatch).winnerId;
    return null;
  }

  bool get _isFanny {
    if (match is PoolMatch) return (match as PoolMatch).isFanny;
    if (match is BracketMatch) return (match as BracketMatch).isFanny;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final themeColor600 = theme.colors.shade600;

    final team1 = _getTeam(_team1Id);
    final team2 = _getTeam(_team2Id);
    final isPlayed = _score1 != null && _score2 != null;
    final color1 = team1 != null ? parseHex(team1.color) : slate400;
    final color2 = team2 != null ? parseHex(team2.color) : slate400;

    return GestureDetector(
      onTap: onPress,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isPlayed
              ? Border.all(color: slate200, width: 1)
              : Border.all(color: slate400, width: 1, style: BorderStyle.solid),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label
            if (label != null) ...[
              Text(
                label!,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: slate500),
              ),
              const SizedBox(height: 6),
            ],

            Row(
              children: [
                // Team 1
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: color1, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          team1?.name ?? 'À déterminer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _winnerId == _team1Id ? FontWeight.w700 : FontWeight.w500,
                            color: slate800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Score or vs
                if (isPlayed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: slate100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_score1',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _winnerId == _team1Id ? themeColor600 : slate500,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text('-', style: TextStyle(fontSize: 12, color: slate400)),
                        ),
                        Text(
                          '$_score2',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _winnerId == _team2Id ? themeColor600 : slate500,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('vs', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: slate400)),
                  ),

                // Team 2
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          team2?.name ?? 'À déterminer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _winnerId == _team2Id ? FontWeight.w700 : FontWeight.w500,
                            color: slate800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: color2, shape: BoxShape.circle),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Fanny badge
            if (_isFanny) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED), // orange-50
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Fanny ! \u{1F351}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFEA580C)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
