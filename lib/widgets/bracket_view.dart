import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:petanque_score/models/tournament.dart';
import 'package:petanque_score/utils/tournament_logic.dart';
import 'package:petanque_score/providers/theme_provider.dart';
import 'package:petanque_score/utils/colors.dart';

// ── Layout constants ──
const double _boxWidth = 160.0;
const double _boxHeight = 70.0;
const double _poolBoxWidth = 170.0;
const double _poolTeamRowH = 24.0;
const double _poolHeaderH = 30.0;
const double _poolPadding = 10.0;
const double _columnGap = 40.0;
const double _rowGap = 20.0;
const double _padding = 16.0;
const double _labelHeight = 28.0;

class BracketView extends StatelessWidget {
  final List<BracketMatch> bracket;
  final List<TournamentTeam> teams;
  final List<Pool> pools;
  final bool isChampionnat;
  final Function(String matchId) onMatchPress;
  final Function(String poolId)? onPoolPress;

  const BracketView({
    super.key,
    required this.bracket,
    required this.teams,
    this.pools = const [],
    this.isChampionnat = false,
    required this.onMatchPress,
    this.onPoolPress,
  });

  TournamentTeam? _getTeam(String? teamId) {
    if (teamId == null) return null;
    return teams.where((t) => t.id == teamId).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    if (bracket.isEmpty && pools.isEmpty) {
      return const Center(
        child: Text('Aucun bracket', style: TextStyle(fontSize: 16, color: slate400)),
      );
    }

    final theme = context.watch<ThemeProvider>();
    final themeColor600 = theme.colors.shade600;
    final themeColor50 = theme.colors.shade50;

    // Separate bracket matches
    final mainMatches = bracket.where((m) => !m.isThirdPlace).toList();
    final thirdPlaceMatch = bracket.where((m) => m.isThirdPlace).firstOrNull;

    final maxRound = mainMatches.isNotEmpty
        ? mainMatches.map((m) => m.round).reduce(max)
        : -1;
    final totalRounds = maxRound + 1;

    final hasPools = pools.isNotEmpty;
    final poolColumnOffset = hasPools ? _poolBoxWidth + _columnGap : 0.0;

    // ── Calculate pool box positions & sizes ──
    final poolPositions = <String, Offset>{};
    final poolSizes = <String, Size>{};
    double poolColumnHeight = _padding + _labelHeight;

    for (var i = 0; i < pools.length; i++) {
      final pool = pools[i];
      final teamCount = pool.teamIds.length;
      final boxH = _poolHeaderH + teamCount * _poolTeamRowH + _poolPadding * 2;
      final x = _padding;
      final y = poolColumnHeight;

      poolPositions[pool.id] = Offset(x, y);
      poolSizes[pool.id] = Size(_poolBoxWidth, boxH);

      poolColumnHeight += boxH + _rowGap;
    }

    // ── Calculate bracket match positions ──
    final positions = <String, Offset>{};

    for (var round = 0; round <= maxRound; round++) {
      final matchesInRound = mainMatches.where((m) => m.round == round).toList()
        ..sort((a, b) => a.position - b.position);

      for (var i = 0; i < matchesInRound.length; i++) {
        final m = matchesInRound[i];
        final x = _padding + poolColumnOffset + round * (_boxWidth + _columnGap);

        double y;
        if (round == 0) {
          // Distribute R0 matches evenly across the pool column height
          final totalR0 = matchesInRound.length;
          final availableH = max(poolColumnHeight - _padding - _labelHeight, totalR0 * (_boxHeight + _rowGap));
          final spacing = availableH / totalR0;
          y = _padding + _labelHeight + i * spacing + (spacing - _boxHeight) / 2;
        } else {
          final src1 = m.sourceMatch1Id != null ? positions[m.sourceMatch1Id] : null;
          final src2 = m.sourceMatch2Id != null ? positions[m.sourceMatch2Id] : null;

          if (src1 != null && src2 != null) {
            y = (src1.dy + src2.dy) / 2;
          } else if (src1 != null) {
            y = src1.dy;
          } else if (src2 != null) {
            y = src2.dy;
          } else {
            y = _padding + _labelHeight + i * (_boxHeight + _rowGap);
          }
        }

        positions[m.id] = Offset(x, y);
      }
    }

    // ── Calculate total canvas size ──
    double totalWidth = _padding * 2 + poolColumnOffset + totalRounds * (_boxWidth + _columnGap);
    if (totalRounds > 0) totalWidth -= _columnGap; // remove trailing gap
    totalWidth = max(totalWidth, _padding * 2 + _poolBoxWidth);

    double totalHeight = _padding * 2 + _labelHeight;
    for (final pos in positions.values) {
      totalHeight = max(totalHeight, pos.dy + _boxHeight + _padding);
    }
    totalHeight = max(totalHeight, poolColumnHeight + _padding);

    if (thirdPlaceMatch != null) {
      totalHeight += _boxHeight + _rowGap + 32;
    }

    return InteractiveViewer(
      minScale: 0.3,
      maxScale: 3.0,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      constrained: false,
      child: SizedBox(
        width: totalWidth,
        height: totalHeight,
        child: Stack(
          children: [
            // ── Connector lines (bracket) ──
            if (mainMatches.isNotEmpty)
              CustomPaint(
                size: Size(totalWidth, totalHeight),
                painter: _BracketConnectorPainter(
                  bracket: mainMatches,
                  positions: positions,
                  boxWidth: _boxWidth,
                  boxHeight: _boxHeight,
                ),
              ),

            // ── Pool → R0 connector lines ──
            if (hasPools && mainMatches.isNotEmpty)
              CustomPaint(
                size: Size(totalWidth, totalHeight),
                painter: _PoolConnectorPainter(
                  pools: pools,
                  poolPositions: poolPositions,
                  poolSizes: poolSizes,
                  bracket: mainMatches,
                  bracketPositions: positions,
                  teams: teams,
                  boxHeight: _boxHeight,
                ),
              ),

            // ── Pool column label ──
            if (hasPools)
              Positioned(
                left: _padding,
                top: _padding,
                child: SizedBox(
                  width: _poolBoxWidth,
                  child: Text(
                    'Poules',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: themeColor600),
                  ),
                ),
              ),

            // ── Pool boxes ──
            for (final pool in pools)
              if (poolPositions.containsKey(pool.id))
                Positioned(
                  left: poolPositions[pool.id]!.dx,
                  top: poolPositions[pool.id]!.dy,
                  child: _PoolBox(
                    pool: pool,
                    teams: teams,
                    isChampionnat: isChampionnat,
                    themeColor600: themeColor600,
                    themeColor50: themeColor50,
                    onTap: onPoolPress != null ? () => onPoolPress!(pool.id) : null,
                  ),
                ),

            // ── Round labels (bracket) ──
            for (var round = 0; round <= maxRound; round++)
              Positioned(
                left: _padding + poolColumnOffset + round * (_boxWidth + _columnGap),
                top: _padding,
                child: SizedBox(
                  width: _boxWidth,
                  child: Text(
                    getRoundLabel(round, totalRounds),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: themeColor600),
                  ),
                ),
              ),

            // ── Match boxes ──
            for (final m in mainMatches)
              if (positions.containsKey(m.id))
                Positioned(
                  left: positions[m.id]!.dx,
                  top: positions[m.id]!.dy,
                  child: _BracketBox(
                    match: m,
                    team1: _getTeam(m.team1Id),
                    team2: _getTeam(m.team2Id),
                    themeColor600: themeColor600,
                    onTap: () => onMatchPress(m.id),
                  ),
                ),

            // ── Third place match ──
            if (thirdPlaceMatch != null) ...[
              Positioned(
                left: _padding + poolColumnOffset + (totalRounds - 1) * (_boxWidth + _columnGap),
                top: totalHeight - _boxHeight - _padding - 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: _boxWidth,
                      child: Text(
                        'Match 3ème place',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: themeColor600),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _BracketBox(
                      match: thirdPlaceMatch,
                      team1: _getTeam(thirdPlaceMatch.team1Id),
                      team2: _getTeam(thirdPlaceMatch.team2Id),
                      themeColor600: themeColor600,
                      onTap: () => onMatchPress(thirdPlaceMatch.id),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Pool Box - compact pool display
// ────────────────────────────────────────────────────────────────────────────

class _PoolBox extends StatelessWidget {
  final Pool pool;
  final List<TournamentTeam> teams;
  final bool isChampionnat;
  final Color themeColor600;
  final Color themeColor50;
  final VoidCallback? onTap;

  const _PoolBox({
    required this.pool,
    required this.teams,
    this.isChampionnat = false,
    required this.themeColor600,
    required this.themeColor50,
    this.onTap,
  });

  TournamentTeam? _getTeam(String teamId) {
    return teams.where((t) => t.id == teamId).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final standings = pool.standings.toList()..sort((a, b) => a.rank - b.rank);
    final completed = pool.completed;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _poolBoxWidth,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: completed ? themeColor600.withValues(alpha: 0.4) : slate200,
            width: completed ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: themeColor600.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
              ),
              child: Row(
                children: [
                  Text(
                    pool.name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: themeColor600,
                    ),
                  ),
                  const Spacer(),
                  if (completed)
                    Icon(Icons.check_circle, size: 14, color: themeColor600),
                ],
              ),
            ),
            // Team rows
            for (var i = 0; i < standings.length; i++)
              _buildTeamRow(standings[i], i),
            // If no standings yet, show team names
            if (standings.isEmpty)
              for (final teamId in pool.teamIds)
                _buildSimpleTeamRow(teamId),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamRow(PoolStanding s, int index) {
    final team = _getTeam(s.teamId);
    final teamColor = team != null ? parseHex(team.color) : slate400;
    final isQualified = s.qualified;

    return Container(
      height: _poolTeamRowH,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isQualified ? themeColor50 : Colors.transparent,
        border: Border(bottom: BorderSide(color: slate100, width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: Text(
              '${s.rank}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isQualified ? themeColor600 : slate400,
              ),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: teamColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              team?.name ?? '?',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isQualified ? FontWeight.w700 : FontWeight.w500,
                color: slate800,
              ),
            ),
          ),
          if (isChampionnat && isQualified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: themeColor600,
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text('Q', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white)),
            )
          else
            Text(
              '${s.wins}V ${s.losses}D',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: slate500),
            ),
        ],
      ),
    );
  }

  Widget _buildSimpleTeamRow(String teamId) {
    final team = _getTeam(teamId);
    final teamColor = team != null ? parseHex(team.color) : slate400;

    return Container(
      height: _poolTeamRowH,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: slate100, width: 0.5)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: teamColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              team?.name ?? '?',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: slate800),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Bracket Box - match display
// ────────────────────────────────────────────────────────────────────────────

class _BracketBox extends StatelessWidget {
  final BracketMatch match;
  final TournamentTeam? team1;
  final TournamentTeam? team2;
  final Color themeColor600;
  final VoidCallback onTap;

  const _BracketBox({
    required this.match,
    required this.team1,
    required this.team2,
    required this.themeColor600,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPlayed = match.score1 != null && match.score2 != null;
    final color1 = team1 != null ? parseHex(team1!.color) : slate400;
    final color2 = team2 != null ? parseHex(team2!.color) : slate400;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _boxWidth,
        height: _boxHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPlayed ? themeColor600.withValues(alpha: 0.3) : slate200,
            width: isPlayed ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: slate100, width: 1)),
                ),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color1, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        team1?.name ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: match.winnerId == match.team1Id ? FontWeight.w700 : FontWeight.w500,
                          color: team1 != null ? slate800 : slate400,
                        ),
                      ),
                    ),
                    if (isPlayed)
                      Text(
                        '${match.score1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: match.winnerId == match.team1Id ? themeColor600 : slate500,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color2, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        team2?.name ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: match.winnerId == match.team2Id ? FontWeight.w700 : FontWeight.w500,
                          color: team2 != null ? slate800 : slate400,
                        ),
                      ),
                    ),
                    if (isPlayed)
                      Text(
                        '${match.score2}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: match.winnerId == match.team2Id ? themeColor600 : slate500,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Bracket Connector Painter
// ────────────────────────────────────────────────────────────────────────────

class _BracketConnectorPainter extends CustomPainter {
  final List<BracketMatch> bracket;
  final Map<String, Offset> positions;
  final double boxWidth;
  final double boxHeight;

  _BracketConnectorPainter({
    required this.bracket,
    required this.positions,
    required this.boxWidth,
    required this.boxHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = slate200
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final match in bracket) {
      if (match.sourceMatch1Id != null && positions.containsKey(match.sourceMatch1Id) && positions.containsKey(match.id)) {
        _drawConnector(canvas, paint, positions[match.sourceMatch1Id]!, positions[match.id]!);
      }
      if (match.sourceMatch2Id != null && positions.containsKey(match.sourceMatch2Id) && positions.containsKey(match.id)) {
        _drawConnector(canvas, paint, positions[match.sourceMatch2Id]!, positions[match.id]!);
      }
    }
  }

  void _drawConnector(Canvas canvas, Paint paint, Offset from, Offset to) {
    final startX = from.dx + boxWidth;
    final startY = from.dy + boxHeight / 2;
    final endX = to.dx;
    final endY = to.dy + boxHeight / 2;
    final midX = (startX + endX) / 2;

    final path = Path()
      ..moveTo(startX, startY)
      ..lineTo(midX, startY)
      ..lineTo(midX, endY)
      ..lineTo(endX, endY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ────────────────────────────────────────────────────────────────────────────
// Pool → Bracket Connector Painter
// ────────────────────────────────────────────────────────────────────────────

class _PoolConnectorPainter extends CustomPainter {
  final List<Pool> pools;
  final Map<String, Offset> poolPositions;
  final Map<String, Size> poolSizes;
  final List<BracketMatch> bracket;
  final Map<String, Offset> bracketPositions;
  final List<TournamentTeam> teams;
  final double boxHeight;

  _PoolConnectorPainter({
    required this.pools,
    required this.poolPositions,
    required this.poolSizes,
    required this.bracket,
    required this.bracketPositions,
    required this.teams,
    required this.boxHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = slate200
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // For each R0 bracket match, find which pool(s) feed into it
    final r0Matches = bracket.where((m) => m.round == 0).toList();

    for (final match in r0Matches) {
      if (!bracketPositions.containsKey(match.id)) continue;

      // Find which pool contains team1 and team2
      for (final teamId in [match.team1Id, match.team2Id]) {
        if (teamId == null) continue;

        for (final pool in pools) {
          if (!pool.teamIds.contains(teamId)) continue;
          if (!poolPositions.containsKey(pool.id)) continue;

          final poolPos = poolPositions[pool.id]!;
          final poolSize = poolSizes[pool.id]!;
          final matchPos = bracketPositions[match.id]!;

          final startX = poolPos.dx + poolSize.width;
          final startY = poolPos.dy + poolSize.height / 2;
          final endX = matchPos.dx;
          final endY = matchPos.dy + boxHeight / 2;
          final midX = (startX + endX) / 2;

          final path = Path()
            ..moveTo(startX, startY)
            ..lineTo(midX, startY)
            ..lineTo(midX, endY)
            ..lineTo(endX, endY);

          canvas.drawPath(path, paint);
          break; // One pool per team
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
