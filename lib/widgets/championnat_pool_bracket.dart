import 'package:flutter/material.dart';
import 'package:petanque_score/models/tournament.dart';
import 'package:petanque_score/utils/tournament_logic.dart';
import 'package:petanque_score/utils/colors.dart';

class ChampionnatPoolBracket extends StatelessWidget {
  final Pool pool;
  final List<TournamentTeam> teams;
  final Color themeColor600;
  final Function(String matchId) onMatchPress;

  const ChampionnatPoolBracket({
    super.key,
    required this.pool,
    required this.teams,
    required this.themeColor600,
    required this.onMatchPress,
  });

  TournamentTeam? _getTeam(String? teamId) {
    if (teamId == null || teamId.isEmpty) return null;
    return teams.where((t) => t.id == teamId).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    // Group matches by type
    final initials = pool.matches.where((m) => m.matchType == 'initial').toList();
    final winnersMatch = pool.matches.where((m) => m.matchType == 'winners').firstOrNull;
    final losersMatch = pool.matches.where((m) => m.matchType == 'losers').firstOrNull;
    final barrageMatch = pool.matches.where((m) => m.matchType == 'barrage').firstOrNull;

    // Simple case: pool of 2 or less, just show match list
    if (winnersMatch == null) {
      return Column(
        children: [
          for (final m in initials)
            _MatchBox(
              match: m,
              team1: _getTeam(m.team1Id),
              team2: _getTeam(m.team2Id),
              label: 'Match',
              playable: true,
              themeColor600: themeColor600,
              onTap: () => onMatchPress(m.id),
            ),
        ],
      );
    }

    final qualifiedIds = getChampionnatQualifiedTeamIds(pool);

    // 3-column layout: Tour 1 | Tour 2 | Barrage
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row of columns
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Column 1: Tour 1
              Expanded(
                child: Column(
                  children: [
                    Text('Tour 1', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: themeColor600)),
                    const SizedBox(height: 6),
                    for (var i = 0; i < initials.length; i++) ...[
                      _MatchBox(
                        match: initials[i],
                        team1: _getTeam(initials[i].team1Id),
                        team2: _getTeam(initials[i].team2Id),
                        label: null,
                        playable: initials[i].team1Id.isNotEmpty && initials[i].team2Id.isNotEmpty && initials[i].winnerId == null,
                        themeColor600: themeColor600,
                        onTap: () => onMatchPress(initials[i].id),
                        isBye: initials[i].team2Id.isEmpty,
                      ),
                      if (i < initials.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Column 2: Gagnants + Perdants
              Expanded(
                child: Column(
                  children: [
                    Text('Tour 2', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: themeColor600)),
                    const SizedBox(height: 6),
                    _MatchBox(
                      match: winnersMatch,
                      team1: _getTeam(winnersMatch.team1Id),
                      team2: _getTeam(winnersMatch.team2Id),
                      label: 'Gagnants',
                      playable: isChampionnatMatchPlayable(winnersMatch, pool) && winnersMatch.winnerId == null,
                      themeColor600: themeColor600,
                      onTap: () => onMatchPress(winnersMatch.id),
                      qualifiedTeamId: winnersMatch.winnerId,
                    ),
                    const SizedBox(height: 8),
                    if (losersMatch != null)
                      _MatchBox(
                        match: losersMatch,
                        team1: _getTeam(losersMatch.team1Id),
                        team2: _getTeam(losersMatch.team2Id),
                        label: 'Perdants',
                        playable: isChampionnatMatchPlayable(losersMatch, pool) && losersMatch.winnerId == null,
                        themeColor600: themeColor600,
                        onTap: () => onMatchPress(losersMatch.id),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Column 3: Barrage
              Expanded(
                child: Column(
                  children: [
                    Text('Barrage', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: themeColor600)),
                    const SizedBox(height: 6),
                    if (barrageMatch != null)
                      _MatchBox(
                        match: barrageMatch,
                        team1: _getTeam(barrageMatch.team1Id),
                        team2: _getTeam(barrageMatch.team2Id),
                        label: null,
                        playable: isChampionnatMatchPlayable(barrageMatch, pool) && barrageMatch.winnerId == null,
                        themeColor600: themeColor600,
                        onTap: () => onMatchPress(barrageMatch.id),
                        qualifiedTeamId: barrageMatch.winnerId,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Qualified teams summary
        if (qualifiedIds.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < qualifiedIds.length; i++)
                _QualifiedBadge(
                  team: _getTeam(qualifiedIds[i]),
                  rank: i + 1,
                  themeColor600: themeColor600,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MatchBox extends StatelessWidget {
  final PoolMatch match;
  final TournamentTeam? team1;
  final TournamentTeam? team2;
  final String? label;
  final bool playable;
  final Color themeColor600;
  final VoidCallback onTap;
  final bool isBye;
  final String? qualifiedTeamId;

  const _MatchBox({
    required this.match,
    required this.team1,
    required this.team2,
    this.label,
    required this.playable,
    required this.themeColor600,
    required this.onTap,
    this.isBye = false,
    this.qualifiedTeamId,
  });

  @override
  Widget build(BuildContext context) {
    final isPlayed = match.score1 != null && match.score2 != null;
    final hasTeams = team1 != null && team2 != null;
    final opacity = (!hasTeams && !isBye && !isPlayed) ? 0.4 : 1.0;

    return GestureDetector(
      onTap: (hasTeams || isPlayed) ? onTap : null,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isPlayed
                  ? themeColor600.withValues(alpha: 0.4)
                  : playable && hasTeams
                      ? themeColor600.withValues(alpha: 0.2)
                      : slate200,
              width: isPlayed ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                  decoration: BoxDecoration(
                    color: themeColor600.withValues(alpha: 0.06),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                  ),
                  child: Text(
                    label!,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: themeColor600),
                  ),
                ),
              _buildTeamRow(team1, match.score1, match.winnerId == match.team1Id && isPlayed, isTop: true),
              Container(height: 0.5, color: slate100),
              _buildTeamRow(team2, match.score2, match.winnerId == match.team2Id && isPlayed, isTop: false),
              if (isBye)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                  child: const Text('Bye', style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: slate400)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamRow(TournamentTeam? team, int? score, bool isWinner, {required bool isTop}) {
    final color = team != null ? parseHex(team.color) : slate400;
    final isQualified = qualifiedTeamId != null && team != null &&
        ((isTop && match.team1Id == qualifiedTeamId) || (!isTop && match.team2Id == qualifiedTeamId));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: isQualified
          ? BoxDecoration(color: themeColor600.withValues(alpha: 0.06))
          : null,
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              team?.name ?? '...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
                color: team != null ? slate800 : slate400,
              ),
            ),
          ),
          if (score != null)
            Text(
              '$score',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isWinner ? themeColor600 : slate500,
              ),
            ),
          if (isQualified) ...[
            const SizedBox(width: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: themeColor600,
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text('Q', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }
}

class _QualifiedBadge extends StatelessWidget {
  final TournamentTeam? team;
  final int rank;
  final Color themeColor600;

  const _QualifiedBadge({required this.team, required this.rank, required this.themeColor600});

  @override
  Widget build(BuildContext context) {
    if (team == null) return const SizedBox.shrink();
    final color = parseHex(team!.color);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: themeColor600.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeColor600.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: themeColor600,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('Q$rank', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          const SizedBox(width: 6),
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(team!.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: slate800)),
        ],
      ),
    );
  }
}
