import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:petanque_score/models/game.dart';
import 'package:petanque_score/providers/theme_provider.dart';
import 'package:petanque_score/utils/colors.dart';

class DistanceResults extends StatelessWidget {
  final MeasureResult result;
  final String team1Name;
  final String team2Name;
  final VoidCallback onApply;

  const DistanceResults({
    super.key,
    required this.result,
    required this.team1Name,
    required this.team2Name,
    required this.onApply,
  });

  // Team colors (not in centralized palette)
  static const _blue600 = Color(0xFF2563EB);
  static const _red600 = Color(0xFFDC2626);
  static const _red500 = Color(0xFFEF4444);
  static const _red50 = Color(0xFFFEF2F2);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final themeColor = theme.colors.shade600;
    final themeColor500 = theme.colors.shade500;
    final themeColor50 = theme.colors.shade50;

    final winnerName = result.closestTeamId == 1 ? team1Name : team2Name;
    final winnerBgColor = result.closestTeamId == 1 ? _blue600 : _red600;

    final distances = result.distances ?? [];
    final scoringCount = result.pointsScored;

    return Container(
      color: slate50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Summary banner ---
          Container(
            color: winnerBgColor,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Text(
              '$winnerName marque ${result.pointsScored} point${result.pointsScored > 1 ? 's' : ''} !',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),

          // --- AI analysis section ---
          if (result.aiAnalysis != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Analyse IA',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: slate500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.aiAnalysis!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: slate700,
                      ),
                    ),

                    // Confidence indicator
                    if (result.confidence != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _confidenceColor(
                                result.confidence!,
                                themeColor500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Confiance : ${_confidenceLabel(result.confidence!)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: slate400,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Low confidence warning
                    if (result.confidence == 'low') ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _red50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Confiance faible. Vérifiez le résultat ou utilisez le mode manuel.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _red600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          // --- Boule ranking table ---
          if (distances.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Classement des boules',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: slate500,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Cochonnet reference row
                    _buildCochonnetRow(),

                    // Boule rows
                    for (int i = 0; i < distances.length; i++) ...[
                      _buildBouleRow(
                        distances[i],
                        i,
                        scoringCount,
                        themeColor,
                        themeColor50,
                      ),

                      // Separator "Ligne de point" between scoring and non-scoring
                      if (i == scoringCount - 1 &&
                          i < distances.length - 1)
                        _buildSeparator(),
                    ],
                  ],
                ),
              ),
            ),

            // --- Method explanation ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(LucideIcons.info, size: 16, color: slate400),
                        const SizedBox(width: 8),
                        const Text(
                          'Comment lire ces résultats',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: slate500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Le cochonnet est le point de référence (0). '
                      'Chaque valeur indique la distance du bord de la boule '
                      '(tangente) au centre du cochonnet. '
                      'Plus le nombre est petit, plus la boule est proche.',
                      style: TextStyle(
                        fontSize: 12,
                        color: slate400,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // --- Apply button ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onApply,
                icon: const Icon(LucideIcons.check, size: 20),
                label: const Text(
                  'Appliquer au score',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCochonnetRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FEE7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Ref icon
          const SizedBox(
            width: 24,
            child: Icon(Icons.adjust, size: 16, color: Color(0xFF84CC16)),
          ),

          // Cochonnet dot
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.only(right: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF84CC16),
              shape: BoxShape.circle,
            ),
          ),

          // Label
          const Expanded(
            child: Text(
              'Cochonnet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF65A30D),
              ),
            ),
          ),

          // Zero reference
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Réf. 0',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF059669),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBouleRow(
    BouleDistance d,
    int index,
    int scoringCount,
    Color themeColor,
    Color themeColor50,
  ) {
    final isScoring =
        d.teamId == result.closestTeamId && index < scoringCount;
    final teamName = d.teamId == 1 ? team1Name : team2Name;
    final dotColor = d.teamId == 1 ? _blue600 : _red600;

    // Distance from cochonnet (normalized × 1000 for readability)
    final distVal = (d.distancePixels * 1000).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isScoring ? themeColor50 : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 24,
            child: Text(
              '#${d.rank}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: slate400,
              ),
            ),
          ),

          // Team color dot
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),

          // Team name
          Expanded(
            child: Text(
              teamName,
              style: const TextStyle(
                fontSize: 14,
                color: slate700,
              ),
            ),
          ),

          // Distance value
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              distVal,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: slate700,
              ),
            ),
          ),

          // POINT label for scoring boules
          if (isScoring) ...[
            const SizedBox(width: 8),
            Text(
              'POINT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: themeColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(
            child: Divider(color: slate200, height: 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Ligne de point',
              style: const TextStyle(
                fontSize: 12,
                color: slate400,
              ),
            ),
          ),
          const Expanded(
            child: Divider(color: slate200, height: 1),
          ),
        ],
      ),
    );
  }

  Color _confidenceColor(String confidence, Color themeColor) {
    switch (confidence) {
      case 'high':
        return themeColor;
      case 'medium':
        return amber500;
      case 'low':
        return _red500;
      default:
        return slate400;
    }
  }

  String _confidenceLabel(String confidence) {
    switch (confidence) {
      case 'high':
        return 'Élevée';
      case 'medium':
        return 'Moyenne';
      case 'low':
        return 'Faible';
      default:
        return confidence;
    }
  }
}
