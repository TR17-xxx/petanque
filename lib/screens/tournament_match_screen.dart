import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:petanque_score/models/tournament.dart';
import 'package:petanque_score/services/tournament_storage.dart';
import 'package:petanque_score/utils/tournament_logic.dart';
import 'package:petanque_score/providers/theme_provider.dart';
import 'package:petanque_score/utils/colors.dart';

class TournamentMatchScreen extends StatefulWidget {
  final String matchId;
  final String tournamentId;

  const TournamentMatchScreen({
    super.key,
    required this.matchId,
    required this.tournamentId,
  });

  @override
  State<TournamentMatchScreen> createState() => _TournamentMatchScreenState();
}

class _TournamentMatchScreenState extends State<TournamentMatchScreen> {
  Tournament? _tournament;
  bool _loading = true;
  bool _isPoolMatch = false;

  final _score1Controller = TextEditingController();
  final _score2Controller = TextEditingController();

  String? _team1Id;
  String? _team2Id;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _score1Controller.dispose();
    _score2Controller.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final tournament = await TournamentStorage.loadTournament(widget.tournamentId);
    if (!mounted || tournament == null) {
      setState(() => _loading = false);
      return;
    }

    // Find the match
    PoolMatch? poolMatch;
    BracketMatch? bracketMatch;

    for (final pool in tournament.pools) {
      for (final m in pool.matches) {
        if (m.id == widget.matchId) {
          poolMatch = m;
          break;
        }
      }
      if (poolMatch != null) break;
    }

    if (poolMatch == null) {
      bracketMatch = tournament.bracket.where((m) => m.id == widget.matchId).firstOrNull;
    }

    String? t1Id, t2Id;
    int? s1, s2;

    if (poolMatch != null) {
      _isPoolMatch = true;
      t1Id = poolMatch.team1Id;
      t2Id = poolMatch.team2Id;
      s1 = poolMatch.score1;
      s2 = poolMatch.score2;
    } else if (bracketMatch != null) {
      _isPoolMatch = false;
      t1Id = bracketMatch.team1Id;
      t2Id = bracketMatch.team2Id;
      s1 = bracketMatch.score1;
      s2 = bracketMatch.score2;
    }

    setState(() {
      _tournament = tournament;
      _team1Id = t1Id;
      _team2Id = t2Id;
      _loading = false;
      if (s1 != null) _score1Controller.text = '$s1';
      if (s2 != null) _score2Controller.text = '$s2';
    });
  }

  TournamentTeam? _getTeam(String? teamId) {
    if (teamId == null || _tournament == null) return null;
    return _tournament!.teams.where((t) => t.id == teamId).firstOrNull;
  }

  int _effectiveTarget() {
    if (_tournament == null) return 13;
    if (_isPoolMatch) {
      return _tournament!.targetScore;
    } else {
      return _tournament!.bracketTargetScore ?? _tournament!.targetScore;
    }
  }

  void _clampScore(TextEditingController controller) {
    final val = int.tryParse(controller.text);
    if (val == null) return;
    final target = _effectiveTarget();
    if (val > target) {
      controller.text = '$target';
      controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
    }
  }

  bool _canValidate() {
    final s1 = int.tryParse(_score1Controller.text);
    final s2 = int.tryParse(_score2Controller.text);
    if (s1 == null || s2 == null) return false;
    if (s1 == s2) return false;
    final target = _effectiveTarget();
    return (s1 == target && s2 < target) || (s2 == target && s1 < target);
  }

  void _setFanny(String teamId) {
    final team1 = _getTeam(_team1Id);
    final team2 = _getTeam(_team2Id);
    if (team1 == null || team2 == null) return;

    final target = _effectiveTarget();
    if (teamId == _team1Id) {
      _score1Controller.text = '$target';
      _score2Controller.text = '0';
    } else {
      _score1Controller.text = '0';
      _score2Controller.text = '$target';
    }
    setState(() {});
  }

  Future<void> _validateScore() async {
    if (!_canValidate() || _tournament == null) return;

    final s1 = int.parse(_score1Controller.text);
    final s2 = int.parse(_score2Controller.text);
    final winnerId = s1 > s2 ? _team1Id! : _team2Id!;
    final loserId = s1 > s2 ? _team2Id! : _team1Id!;
    final target = _effectiveTarget();
    final isFanny = (s1 == target && s2 == 0) || (s2 == target && s1 == 0);
    final now = DateTime.now().toIso8601String();

    final t = _tournament!;

    if (_isPoolMatch) {
      // Update pool match
      for (final pool in t.pools) {
        for (final m in pool.matches) {
          if (m.id == widget.matchId) {
            m.score1 = s1;
            m.score2 = s2;
            m.winnerId = winnerId;
            m.isFanny = isFanny;
            m.playedAt = now;

            // Championnat mode: propagate within pool
            if (t.mode == 'championnat') {
              propagateChampionnatPoolWinner(pool, m.id, winnerId, loserId);
            }
            break;
          }
        }
      }
      // Recalculate standings
      if (t.mode == 'championnat') {
        for (final pool in t.pools) {
          pool.standings = calculateChampionnatStandings(pool);
          pool.completed = isChampionnatPoolComplete(pool);
        }
      } else {
        final qualifiedPerPool = getQualifiedPerPool(t.pools);
        for (final pool in t.pools) {
          pool.standings = calculatePoolStandings(pool, qualifiedCount: qualifiedPerPool);
          pool.completed = isPoolComplete(pool);
        }
      }
    } else {
      // Update bracket match
      for (final m in t.bracket) {
        if (m.id == widget.matchId) {
          m.score1 = s1;
          m.score2 = s2;
          m.winnerId = winnerId;
          m.isFanny = isFanny;
          m.playedAt = now;
          break;
        }
      }
      // Propagate winner
      t.bracket = propagateWinner(t.bracket, widget.matchId, winnerId, loserId);
      // Re-apply the score we just set (propagateWinner deep-copies)
      for (final m in t.bracket) {
        if (m.id == widget.matchId) {
          m.score1 = s1;
          m.score2 = s2;
          m.winnerId = winnerId;
          m.isFanny = isFanny;
          m.playedAt = now;
          break;
        }
      }
    }

    await TournamentStorage.saveTournament(t);

    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final themeColor600 = theme.colors.shade600;

    if (_loading) {
      return const Scaffold(
        backgroundColor: slate50,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final team1 = _getTeam(_team1Id);
    final team2 = _getTeam(_team2Id);

    // If not ready
    if (team1 == null || team2 == null) {
      return Scaffold(
        backgroundColor: slate50,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        }
                      },
                      icon: const Icon(LucideIcons.arrowLeft, size: 22, color: slate800),
                    ),
                    const Expanded(
                      child: Text(
                        'Match',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: slate800),
                      ),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.clock, size: 48, color: slate200),
                      SizedBox(height: 12),
                      Text(
                        'En attente des équipes',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: slate400),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Les matchs précédents doivent être terminés',
                        style: TextStyle(fontSize: 13, color: slate400),
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

    final color1 = parseHex(team1.color);
    final color2 = parseHex(team2.color);
    final canValidate = _canValidate();

    return Scaffold(
      backgroundColor: slate50,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(LucideIcons.arrowLeft, size: 22, color: slate800),
                    tooltip: 'Retour',
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Score du match',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: slate800),
                        ),
                        Text(
                          _isPoolMatch ? 'Poule — ${_effectiveTarget()} pts' : 'Bracket — ${_effectiveTarget()} pts',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: themeColor600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Score display: split screen with team colors
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Row(
                          children: [
                            // Team 1 side
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 32),
                                color: color1,
                                child: Column(
                                  children: [
                                    Text(
                                      team1.name,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: 80,
                                      child: TextField(
                                        controller: _score1Controller,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 48,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: '0',
                                          hintStyle: TextStyle(
                                            fontSize: 48,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white.withValues(alpha: 0.4),
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onChanged: (_) {
                                          _clampScore(_score1Controller);
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // VS separator
                            Container(
                              width: 2,
                              height: 160,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),

                            // Team 2 side
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 32),
                                color: color2,
                                child: Column(
                                  children: [
                                    Text(
                                      team2.name,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: 80,
                                      child: TextField(
                                        controller: _score2Controller,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 48,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: '0',
                                          hintStyle: TextStyle(
                                            fontSize: 48,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white.withValues(alpha: 0.4),
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onChanged: (_) {
                                          _clampScore(_score2Controller);
                                          setState(() {});
                                        },
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
                    const SizedBox(height: 24),

                    // Fanny buttons
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _setFanny(_team1Id!),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: color1.withValues(alpha: 0.3)),
                              ),
                              child: Center(
                                child: Text(
                                  'Fanny ${team1.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color1),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _setFanny(_team2Id!),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: color2.withValues(alpha: 0.3)),
                              ),
                              child: Center(
                                child: Text(
                                  'Fanny ${team2.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Validate button
                    GestureDetector(
                      onTap: canValidate ? _validateScore : null,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: canValidate ? themeColor600 : slate200,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: canValidate
                              ? [
                                  BoxShadow(
                                    color: themeColor600.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              LucideIcons.check,
                              size: 20,
                              color: canValidate ? Colors.white : slate400,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Valider le score',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: canValidate ? Colors.white : slate400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Hint text
                    if (!canValidate) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Les deux scores doivent être remplis, différents, et un doit atteindre ${_effectiveTarget()}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: slate400),
                      ),
                    ],
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
