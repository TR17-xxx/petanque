import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:petanque_score/models/tournament.dart';
import 'package:petanque_score/providers/theme_provider.dart';
import 'package:petanque_score/utils/colors.dart';

class PoolTable extends StatelessWidget {
  final Pool pool;
  final List<TournamentTeam> teams;

  const PoolTable({super.key, required this.pool, required this.teams});

  TournamentTeam? _getTeam(String teamId) {
    return teams.where((t) => t.id == teamId).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final themeColor50 = theme.colors.shade50;
    final themeColor600 = theme.colors.shade600;

    final standings = pool.standings.toList()..sort((a, b) => a.rank - b.rank);

    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Table(
          columnWidths: const {
            0: FixedColumnWidth(32),   // #
            1: FlexColumnWidth(),       // Equipe
            2: FixedColumnWidth(28),    // J
            3: FixedColumnWidth(28),    // V
            4: FixedColumnWidth(28),    // D
            5: FixedColumnWidth(32),    // PF
            6: FixedColumnWidth(32),    // PC
            7: FixedColumnWidth(36),    // Diff
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            // Header row
            TableRow(
              decoration: BoxDecoration(color: slate100),
              children: [
                _headerCell('#'),
                _headerCell('Equipe', align: TextAlign.left),
                _headerCell('J'),
                _headerCell('V'),
                _headerCell('D'),
                _headerCell('PF'),
                _headerCell('PC'),
                _headerCell('Diff'),
              ],
            ),
            // Data rows
            for (final standing in standings)
              _buildRow(standing, themeColor50, themeColor600),
          ],
        ),
      ),
    );
  }

  TableRow _buildRow(PoolStanding standing, Color themeColor50, Color themeColor600) {
    final team = _getTeam(standing.teamId);
    final teamColor = team != null ? parseHex(team.color) : slate400;
    final teamName = team?.name ?? '?';
    final isQualified = standing.qualified;

    return TableRow(
      decoration: BoxDecoration(
        color: isQualified ? themeColor50 : Colors.white,
        border: const Border(bottom: BorderSide(color: slate100, width: 0.5)),
      ),
      children: [
        // Rank
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Text(
              '${standing.rank}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isQualified ? themeColor600 : slate500,
              ),
            ),
          ),
        ),
        // Team name + color dot
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: teamColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  teamName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: slate800),
                ),
              ),
            ],
          ),
        ),
        _dataCell('${standing.played}'),
        _dataCell('${standing.wins}'),
        _dataCell('${standing.losses}'),
        _dataCell('${standing.pointsFor}'),
        _dataCell('${standing.pointsAgainst}'),
        _dataCell(standing.diff >= 0 ? '+${standing.diff}' : '${standing.diff}',
            color: standing.diff > 0
                ? const Color(0xFF16A34A)
                : standing.diff < 0
                    ? const Color(0xFFDC2626)
                    : slate500),
      ],
    );
  }

  Widget _headerCell(String text, {TextAlign align = TextAlign.center}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: slate500),
      ),
    );
  }

  Widget _dataCell(String text, {Color color = slate700}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
        ),
      ),
    );
  }
}
