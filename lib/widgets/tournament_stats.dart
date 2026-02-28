import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:petanque_score/models/tournament.dart';
import 'package:petanque_score/providers/theme_provider.dart';
import 'package:petanque_score/utils/colors.dart';

class TournamentStats extends StatelessWidget {
  final Tournament tournament;

  const TournamentStats({super.key, required this.tournament});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final themeColor600 = theme.colors.shade600;

    // Gather all matches (pool + bracket)
    final allPoolMatches = tournament.pools.expand((p) => p.matches).toList();
    final allBracketMatches = tournament.bracket;
    final allMatches = <_MatchInfo>[];

    for (final m in allPoolMatches) {
      if (m.score1 != null && m.score2 != null) {
        allMatches.add(_MatchInfo(
          team1Id: m.team1Id,
          team2Id: m.team2Id,
          score1: m.score1!,
          score2: m.score2!,
          winnerId: m.winnerId,
          isFanny: m.isFanny,
        ));
      }
    }
    for (final m in allBracketMatches) {
      if (m.score1 != null && m.score2 != null) {
        allMatches.add(_MatchInfo(
          team1Id: m.team1Id ?? '',
          team2Id: m.team2Id ?? '',
          score1: m.score1!,
          score2: m.score2!,
          winnerId: m.winnerId,
          isFanny: m.isFanny,
        ));
      }
    }

    final totalPoolMatches = allPoolMatches.length;
    final totalBracketMatches = allBracketMatches.length;
    final totalMatches = totalPoolMatches + totalBracketMatches;
    final playedMatches = allMatches.length;

    // Fanny count
    final fannyCount = allMatches.where((m) => m.isFanny).length;

    // Top scoring team (total points for)
    final teamPointsFor = <String, int>{};
    for (final m in allMatches) {
      teamPointsFor[m.team1Id] = (teamPointsFor[m.team1Id] ?? 0) + m.score1;
      teamPointsFor[m.team2Id] = (teamPointsFor[m.team2Id] ?? 0) + m.score2;
    }
    String? topScoringTeamId;
    int topScore = 0;
    for (final entry in teamPointsFor.entries) {
      if (entry.value > topScore) {
        topScore = entry.value;
        topScoringTeamId = entry.key;
      }
    }
    final topScoringTeam = topScoringTeamId != null
        ? tournament.teams.where((t) => t.id == topScoringTeamId).firstOrNull
        : null;

    // Biggest win (largest score difference)
    _MatchInfo? biggestWin;
    int biggestDiff = 0;
    for (final m in allMatches) {
      final diff = (m.score1 - m.score2).abs();
      if (diff > biggestDiff) {
        biggestDiff = diff;
        biggestWin = m;
      }
    }

    // Closest match (smallest score difference)
    _MatchInfo? closestMatch;
    int closestDiff = 999;
    for (final m in allMatches) {
      final diff = (m.score1 - m.score2).abs();
      if (diff < closestDiff) {
        closestDiff = diff;
        closestMatch = m;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress
        _buildStatCard(
          icon: LucideIcons.barChart3,
          iconColor: themeColor600,
          title: 'Progression',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$playedMatches / $totalMatches matchs joués',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: slate800),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: totalMatches > 0 ? playedMatches / totalMatches : 0,
                  backgroundColor: slate200,
                  valueColor: AlwaysStoppedAnimation<Color>(themeColor600),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                totalMatches > 0
                    ? '${(playedMatches / totalMatches * 100).round()}%'
                    : '0%',
                style: const TextStyle(fontSize: 12, color: slate500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Fanny count
        _buildStatCard(
          icon: LucideIcons.flame,
          iconColor: const Color(0xFFEA580C),
          title: 'Fannys',
          child: Row(
            children: [
              Text(
                '$fannyCount',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: slate800),
              ),
              const SizedBox(width: 8),
              const Text('\u{1F351}', style: TextStyle(fontSize: 24)),
              const Spacer(),
              Text(
                playedMatches > 0
                    ? '${(fannyCount / playedMatches * 100).round()}% des matchs'
                    : '',
                style: const TextStyle(fontSize: 12, color: slate500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Top scoring team
        if (topScoringTeam != null)
          _buildStatCard(
            icon: LucideIcons.trophy,
            iconColor: const Color(0xFFF59E0B),
            title: 'Meilleure attaque',
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: parseHex(topScoringTeam.color),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    topScoringTeam.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: slate800),
                  ),
                ),
                Text(
                  '$topScore pts',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: themeColor600),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),

        // Biggest win
        if (biggestWin != null)
          _buildStatCard(
            icon: LucideIcons.swords,
            iconColor: const Color(0xFFDC2626),
            title: 'Plus large victoire',
            child: _buildMatchStatRow(biggestWin, themeColor600),
          ),
        const SizedBox(height: 12),

        // Closest match
        if (closestMatch != null)
          _buildStatCard(
            icon: LucideIcons.timer,
            iconColor: const Color(0xFF2563EB),
            title: 'Match le plus serré',
            child: _buildMatchStatRow(closestMatch, themeColor600),
          ),
      ],
    );
  }

  Widget _buildMatchStatRow(_MatchInfo match, Color themeColor600) {
    final team1 = tournament.teams.where((t) => t.id == match.team1Id).firstOrNull;
    final team2 = tournament.teams.where((t) => t.id == match.team2Id).firstOrNull;
    final color1 = team1 != null ? parseHex(team1.color) : slate400;
    final color2 = team2 != null ? parseHex(team2.color) : slate400;

    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color1, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            team1?.name ?? '?',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: slate800),
          ),
        ),
        Text(
          '${match.score1}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: match.winnerId == match.team1Id ? themeColor600 : slate500,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('-', style: TextStyle(fontSize: 12, color: slate400)),
        ),
        Text(
          '${match.score2}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: match.winnerId == match.team2Id ? themeColor600 : slate500,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            team2?.name ?? '?',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: slate800),
          ),
        ),
        const SizedBox(width: 6),
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color2, shape: BoxShape.circle)),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: slate200),
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
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: slate500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MatchInfo {
  final String team1Id;
  final String team2Id;
  final int score1;
  final int score2;
  final String? winnerId;
  final bool isFanny;

  _MatchInfo({
    required this.team1Id,
    required this.team2Id,
    required this.score1,
    required this.score2,
    this.winnerId,
    required this.isFanny,
  });
}
