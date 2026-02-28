import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:petanque_score/models/game.dart';
import 'package:petanque_score/providers/theme_provider.dart';
import 'package:petanque_score/services/storage_service.dart';
import 'package:petanque_score/widgets/score_display.dart';
import 'package:petanque_score/widgets/round_input.dart';
import 'package:petanque_score/utils/colors.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.gameId});

  final String gameId;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  Game? _game;
  bool _loading = true;

  // Victory animation
  late AnimationController _trophyAnimController;
  late Animation<double> _trophyScaleAnim;

  // Points-added animation
  AnimationController? _pointsAnimController;
  String? _pointsAnimText;
  Color? _pointsAnimColor;

  // Key to control the RoundInput pre-fill from measure result
  int? _prefillWinnerId;
  int? _prefillPoints;



  @override
  void initState() {
    super.initState();
    _trophyAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _trophyScaleAnim = CurvedAnimation(
      parent: _trophyAnimController,
      curve: Curves.elasticOut,
    );
    _loadGame();
  }

  @override
  void dispose() {
    _trophyAnimController.dispose();
    _pointsAnimController?.dispose();
    super.dispose();
  }

  Future<void> _loadGame() async {
    final game = await StorageService.loadActiveGame(widget.gameId);
    if (!mounted) return;
    if (game == null) {
      context.go('/');
      return;
    }
    setState(() {
      _game = game;
      _loading = false;
    });
    // Check for pending measure result
    await _checkMeasureResult();
  }

  Future<void> _checkMeasureResult() async {
    final result = await StorageService.loadMeasureResult();
    if (result != null && mounted) {
      await StorageService.clearMeasureResult();

      final winnerName = result.closestTeamId == 1
          ? _game?.team1.name ?? 'Éq. 1'
          : _game?.team2.name ?? 'Éq. 2';
      final winnerColor = result.closestTeamId == 1
          ? const Color(0xFF2563EB)
          : const Color(0xFFDC2626);
      final pts = result.pointsScored;

      // Apply the round directly without a second validation
      await _onValidateRound(
        result.closestTeamId,
        pts,
        measurement: result,
      );

      // Show points animation
      _showPointsAnimation(
        '$winnerName  +$pts point${pts > 1 ? 's' : ''}',
        winnerColor,
      );
    }
  }

  void _showPointsAnimation(String text, Color color) {
    _pointsAnimController?.dispose();
    _pointsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    setState(() {
      _pointsAnimText = text;
      _pointsAnimColor = color;
    });
    _pointsAnimController!.forward().then((_) {
      if (mounted) {
        setState(() {
          _pointsAnimText = null;
          _pointsAnimColor = null;
        });
      }
    });
  }

  /// Returns current scores as [score1, score2].
  List<int> _getCurrentScores() {
    if (_game == null || _game!.rounds.isEmpty) return [0, 0];
    return _game!.rounds.last.totalAfter;
  }

  /// Validates a round and updates the game state.
  Future<void> _onValidateRound(int winnerId, int points,
      {MeasureResult? measurement}) async {
    if (_game == null || points <= 0) return;

    final currentScores = _getCurrentScores();
    final newScores = [
      currentScores[0] + (winnerId == 1 ? points : 0),
      currentScores[1] + (winnerId == 2 ? points : 0),
    ];

    final round = Round(
      number: _game!.rounds.length + 1,
      winnerId: winnerId,
      points: points,
      totalAfter: newScores,
      measurement: measurement,
    );

    final isVictory =
        newScores[0] >= _game!.targetScore || newScores[1] >= _game!.targetScore;
    final winnerTeamId = newScores[0] >= _game!.targetScore
        ? 1
        : newScores[1] >= _game!.targetScore
            ? 2
            : null;

    final updatedGame = _game!.copyWith(
      rounds: [..._game!.rounds, round],
      status: isVictory ? 'finished' : 'playing',
      winnerId: winnerTeamId,
    );

    if (isVictory) {
      await StorageService.addGameToHistory(updatedGame);
      await StorageService.removeActiveGame(updatedGame.id);
    } else {
      await StorageService.saveActiveGame(updatedGame);
    }

    if (!mounted) return;

    setState(() {
      _game = updatedGame;
      _prefillWinnerId = null;
      _prefillPoints = null;
    });

    if (isVictory) {
      _showVictoryDialog();
    }
  }

  /// Undoes the last round.
  Future<void> _onUndoLastRound() async {
    if (_game == null || _game!.rounds.isEmpty) return;

    final wasFinished = _game!.status == 'finished';

    final updatedRounds = List<Round>.from(_game!.rounds)..removeLast();
    final updatedGame = _game!.copyWith(
      rounds: updatedRounds,
      status: 'playing',
      winnerId: null,
    );

    // Re-add to active games (was removed on victory)
    await StorageService.saveActiveGame(updatedGame);
    // Remove from history if it was there
    if (wasFinished) {
      await StorageService.removeGamesFromHistory([updatedGame.id]);
    }

    if (!mounted) return;
    setState(() {
      _game = updatedGame;
    });
  }

  /// Shows the victory dialog with animated trophy.
  void _showVictoryDialog() {
    if (_game == null) return;
    _trophyAnimController.reset();
    _trophyAnimController.forward();

    final theme = context.read<ThemeProvider>();
    final themeColor = theme.colors.shade600;
    final scores = _getCurrentScores();
    final winner = _game!.winnerId == 1 ? _game!.team1 : _game!.team2;
    final winnerColor = parseHex(winner.color);
    final color1 = parseHex(_game!.team1.color);
    final color2 = parseHex(_game!.team2.color);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated trophy
                ScaleTransition(
                  scale: _trophyScaleAnim,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7), // amber-100
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.trophy,
                      size: 40,
                      color: Color(0xFFF59E0B), // amber-500
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Winner name
                Text(
                  winner.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: winnerColor,
                  ),
                ),
                const SizedBox(height: 4),

                // "remporte la partie !"
                Text(
                  'remporte la partie !',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: themeColor,
                  ),
                ),
                const SizedBox(height: 24),

                // Final scores
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${scores[0]}',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: color1,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '-',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w300,
                          color: slate400,
                        ),
                      ),
                    ),
                    Text(
                      '${scores[1]}',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: color2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Round count
                Text(
                  '${_game!.rounds.length} mène${_game!.rounds.length > 1 ? 's' : ''} jouée${_game!.rounds.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: slate500,
                  ),
                ),
                const SizedBox(height: 20),

                // Undo link
                GestureDetector(
                  onTap: () {
                    Navigator.of(dialogCtx).pop();
                    _onUndoLastRound();
                  },
                  child: Text(
                    'Annuler dernière mène (erreur)',
                    style: TextStyle(
                      fontSize: 13,
                      color: slate400,
                      decoration: TextDecoration.underline,
                      decorationColor: slate400,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // New game button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(dialogCtx).pop();
                      context.go('/setup');
                    },
                    icon: const Icon(LucideIcons.plus, size: 20),
                    label: const Text(
                      'Nouvelle partie',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
                const SizedBox(height: 12),

                // Home button
                GestureDetector(
                  onTap: () {
                    Navigator.of(dialogCtx).pop();
                    context.go('/');
                  },
                  child: Text(
                    'Retour à l\'accueil',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: slate500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Handles the back / "Retour" button press.
  /// Simply navigates home – the game stays saved in active games.
  void _onBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: slate50,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_game == null) {
      return const Scaffold(
        backgroundColor: slate50,
        body: Center(child: Text('Aucune partie en cours')),
      );
    }

    final theme = context.watch<ThemeProvider>();
    final themeColor = theme.colors.shade600;
    final scores = _getCurrentScores();

    return Scaffold(
        backgroundColor: slate50,
        body: SafeArea(
          child: Stack(
            children: [
          Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Retour button
                    GestureDetector(
                      onTap: _onBack,
                      child: Row(
                        children: [
                          Icon(LucideIcons.arrowLeft, size: 20, color: themeColor),
                          const SizedBox(width: 4),
                          Text(
                            'Retour',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: themeColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right icons
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => context.push('/history?gameId=${widget.gameId}&active=true'),
                          icon: Icon(
                            LucideIcons.clipboardList,
                            color: slate500,
                            size: 22,
                          ),
                          tooltip: 'Historique des mènes',
                        ),
                        IconButton(
                          onPressed: () => context.push('/settings'),
                          icon: Icon(
                            LucideIcons.settings,
                            color: slate500,
                            size: 22,
                          ),
                          tooltip: 'Paramètres',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Scrollable content ──
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    children: [
                      const SizedBox(height: 4),

                      // Score display
                      ScoreDisplay(
                        team1: _game!.team1,
                        team2: _game!.team2,
                        score1: scores[0],
                        score2: scores[1],
                        targetScore: _game!.targetScore,
                      ),
                      const SizedBox(height: 10),

                      // Measure button (compact)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GestureDetector(
                          onTap: () async {
                            await context.push('/measure?gameId=${widget.gameId}');
                            if (mounted) await _checkMeasureResult();
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  LucideIcons.camera,
                                  size: 22,
                                  color: themeColor,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Mesurer les distances',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: themeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Round input
                      if (_game!.status == 'playing')
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: RoundInput(
                            roundNumber: _game!.rounds.length + 1,
                            team1: _game!.team1,
                            team2: _game!.team2,
                            preselectedWinner: _prefillWinnerId,
                            preselectedPoints: _prefillPoints,
                            onValidate: (winnerId, points) {
                              _onValidateRound(winnerId, points);
                            },
                          ),
                        ),

                      // Undo button
                      if (_game!.rounds.isNotEmpty &&
                          _game!.status == 'playing')
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: GestureDetector(
                            onTap: _onUndoLastRound,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  LucideIcons.undo2,
                                  size: 16,
                                  color: slate400,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Annuler la dernière mène',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: slate400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Points-added animation overlay
          if (_pointsAnimText != null && _pointsAnimController != null)
            _buildPointsOverlay(),
            ],
          ),
        ),
    );
  }

  Widget _buildPointsOverlay() {
    final controller = _pointsAnimController!;
    // 0.0-0.15: scale in, 0.15-0.75: hold, 0.75-1.0: fade out
    final scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 30),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.1), weight: 20),
    ]).animate(controller);

    final opacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
    ]).animate(controller);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: opacityAnim.value,
              child: Center(
                child: Transform.scale(
                  scale: scaleAnim.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                    decoration: BoxDecoration(
                      color: _pointsAnimColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (_pointsAnimColor ?? Colors.black).withValues(alpha: 0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Text(
                      _pointsAnimText ?? '',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
