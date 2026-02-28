import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:petanque_score/models/game.dart';
import 'package:petanque_score/providers/theme_provider.dart';
import 'package:petanque_score/services/storage_service.dart';
import 'package:petanque_score/utils/colors.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.gameId, this.isActive = false});

  /// Game ID to display.
  final String? gameId;

  /// If true, loads from active games instead of history.
  final bool isActive;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Game? _game;
  bool _loading = true;
  bool _isCurrentGame = false;


  @override
  void initState() {
    super.initState();
    _loadGame();
  }

  Future<void> _loadGame() async {
    Game? game;
    if (widget.gameId != null) {
      if (widget.isActive) {
        game = await StorageService.loadActiveGame(widget.gameId!);
        _isCurrentGame = true;
      } else {
        game = await StorageService.loadGameFromHistory(widget.gameId!);
        _isCurrentGame = false;
      }
    }

    if (!mounted) return;
    setState(() {
      _game = game;
      _loading = false;
    });
  }

  /// Returns current scores as [score1, score2].
  List<int> _getCurrentScores() {
    if (_game == null || _game!.rounds.isEmpty) return [0, 0];
    return _game!.rounds.last.totalAfter;
  }

  /// Undoes the last round (only available for the current game).
  Future<void> _onUndoLastRound() async {
    if (_game == null || _game!.rounds.isEmpty || !_isCurrentGame) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Annuler la dernière mène ?',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: slate800,
          ),
        ),
        content: Text(
          'La mène ${_game!.rounds.length} sera supprimée.',
          style: const TextStyle(fontSize: 14, color: slate500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Non',
              style: TextStyle(fontWeight: FontWeight.w600, color: slate500),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Oui, annuler',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFFEF4444), // red-500
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final updatedRounds = List<Round>.from(_game!.rounds)..removeLast();
    final updatedGame = _game!.copyWith(
      rounds: updatedRounds,
      status: 'playing',
      winnerId: null,
    );

    await StorageService.saveActiveGame(updatedGame);

    if (!mounted) return;
    setState(() {
      _game = updatedGame;
    });
  }

  /// Builds the title string for the header.
  String _buildTitle() {
    if (_game == null) return 'Historique';
    if (_game!.status == 'finished') {
      return '${_game!.team1.name} vs ${_game!.team2.name}';
    }
    return 'Historique des mènes';
  }

  /// Builds the subtitle with final score.
  String? _buildSubtitle() {
    if (_game == null || _game!.rounds.isEmpty) return null;
    final scores = _getCurrentScores();
    return '${scores[0]} - ${scores[1]}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: slate50,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: slate50,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            _buildHeader(theme),

            // ── Undo button (current game only) ──
            if (_isCurrentGame && _game != null && _game!.rounds.isNotEmpty)
              _buildUndoButton(),

            // ── Round list ──
            Expanded(
              child: _game == null || _game!.rounds.isEmpty
                  ? _buildEmptyState()
                  : _buildRoundList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeProvider theme) {
    final subtitle = _buildSubtitle();
    final scores = _getCurrentScores();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(LucideIcons.arrowLeft, size: 22, color: slate800),
            tooltip: 'Retour',
          ),

          // Title area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _buildTitle(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: slate800,
                  ),
                ),
                if (subtitle != null && _game != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${scores[0]}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: parseHex(_game!.team1.color),
                          ),
                        ),
                        const Text(
                          ' - ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: slate400,
                          ),
                        ),
                        Text(
                          '${scores[1]}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: parseHex(_game!.team2.color),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Placeholder to balance the back button
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildUndoButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: GestureDetector(
        onTap: _onUndoLastRound,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.undo2, size: 15, color: Color(0xFFEF4444)),
            const SizedBox(width: 6),
            const Text(
              'Annuler la dernière mène',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFEF4444), // red-500
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.clipboardList, size: 48, color: slate300),
          const SizedBox(height: 12),
          const Text(
            'Aucune mène jouée',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: slate400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundList() {
    // Display rounds in reverse order (newest first)
    final rounds = _game!.rounds.reversed.toList();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: rounds.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final round = rounds[index];
        return _RoundCard(
          round: round,
          team1: _game!.team1,
          team2: _game!.team2,
        );
      },
    );
  }
}

/// A card widget representing a single played round.
class _RoundCard extends StatelessWidget {
  const _RoundCard({
    required this.round,
    required this.team1,
    required this.team2,
  });

  final Round round;
  final Team team1;
  final Team team2;


  @override
  Widget build(BuildContext context) {
    final winnerTeam = round.winnerId == 1 ? team1 : team2;
    final winnerColor = parseHex(winnerTeam.color);
    final hasMeasurement = round.measurement != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left column: round number and winner badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: round label + measurement icon
                Row(
                  children: [
                    Text(
                      'Mène ${round.number}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: slate800,
                      ),
                    ),
                    if (hasMeasurement) ...[
                      const SizedBox(width: 6),
                      Icon(
                        LucideIcons.camera,
                        size: 14,
                        color: slate400,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                // Winner badge and points
                Row(
                  children: [
                    // Winner pill badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: winnerColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        winnerTeam.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: winnerColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Points scored
                    Text(
                      '+${round.points} point${round.points > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: slate500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Right column: score after this round
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: slate100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${round.totalAfter[0]}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: parseHex(team1.color),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '-',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: slate400,
                    ),
                  ),
                ),
                Text(
                  '${round.totalAfter[1]}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: parseHex(team2.color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
