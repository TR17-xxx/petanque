import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:petanque_score/models/tournament.dart';
import 'package:petanque_score/services/tournament_storage.dart';
import 'package:petanque_score/utils/tournament_logic.dart';
import 'package:petanque_score/providers/theme_provider.dart';
import 'package:petanque_score/providers/purchase_provider.dart';
import 'package:petanque_score/services/firebase_tournament_service.dart';
import 'package:petanque_score/utils/colors.dart';
import 'package:petanque_score/widgets/pool_table.dart';
import 'package:petanque_score/widgets/share_code_dialog.dart';
import 'package:petanque_score/widgets/live_badge.dart';
import 'package:petanque_score/widgets/pool_match_list.dart';
import 'package:petanque_score/widgets/bracket_view.dart';
import 'package:petanque_score/widgets/match_card.dart';
import 'package:petanque_score/widgets/championnat_pool_bracket.dart';
import 'package:petanque_score/widgets/tournament_stats.dart';
import 'package:petanque_score/widgets/registration_list.dart';
import 'package:petanque_score/models/registration.dart';
import 'package:petanque_score/utils/tournament_logic.dart' show generatePools, generateChampionnatPools;
import 'package:petanque_score/utils/helpers.dart';

class TournamentDashboardScreen extends StatefulWidget {
  final String id;
  const TournamentDashboardScreen({super.key, required this.id});

  @override
  State<TournamentDashboardScreen> createState() => _TournamentDashboardScreenState();
}

class _TournamentDashboardScreenState extends State<TournamentDashboardScreen>
    with SingleTickerProviderStateMixin {
  Tournament? _tournament;
  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTournament();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTournament() async {
    var tournament = await TournamentStorage.loadTournament(widget.id);
    if (tournament == null || !mounted) {
      setState(() => _loading = false);
      return;
    }

    // Auto-recalculate standings
    if (tournament.mode == 'championnat') {
      for (final pool in tournament.pools) {
        pool.standings = calculateChampionnatStandings(pool);
        pool.completed = isChampionnatPoolComplete(pool);
      }
    } else {
      final qualifiedPerPool = getQualifiedPerPool(tournament.pools);
      for (final pool in tournament.pools) {
        pool.standings = calculatePoolStandings(pool, qualifiedCount: qualifiedPerPool);
        pool.completed = isPoolComplete(pool);
      }
    }

    // Auto-transition: pools -> bracket
    if (tournament.phase == 'pools' && tournament.pools.every((p) => p.completed)) {
      // For championnat mode, set qualified flags from match results
      if (tournament.mode == 'championnat') {
        for (final pool in tournament.pools) {
          final qualifiedIds = getChampionnatQualifiedTeamIds(pool);
          for (final s in pool.standings) {
            s.qualified = qualifiedIds.contains(s.teamId);
          }
        }
      }
      if (tournament.bracket.isEmpty) {
        tournament.bracket = generateBracket(tournament.pools, tournament.hasThirdPlace);
      } else {
        tournament.bracket = populateBracketFromPools(tournament.bracket, tournament.pools);
      }
      tournament.phase = 'bracket';
    }

    // Auto-populate bracket if in bracket phase
    if (tournament.phase == 'bracket' && tournament.bracket.isNotEmpty) {
      // Check if bracket is complete
      if (isBracketComplete(tournament.bracket)) {
        final nonThirdPlace = tournament.bracket.where((b) => !b.isThirdPlace);
        final maxRound = nonThirdPlace.map((b) => b.round).reduce(max);
        final finale = nonThirdPlace.where((m) => m.round == maxRound).firstOrNull;
        if (finale?.winnerId != null) {
          tournament.winnerId = finale!.winnerId;
          // Check third place match too
          final thirdPlace = tournament.bracket.where((m) => m.isThirdPlace).firstOrNull;
          if (thirdPlace == null || thirdPlace.winnerId != null) {
            tournament.phase = 'finished';
          }
        }
      }
    }

    await TournamentStorage.saveTournament(tournament);

    // Push to Firestore if shared
    if (tournament.isShared) {
      FirebaseTournamentService.pushTournamentUpdate(tournament).catchError((_) {});
    }

    if (!mounted) return;
    setState(() {
      _tournament = tournament;
      _loading = false;
    });
  }

  Future<void> _toggleSharing(Tournament t) async {
    if (t.isShared) {
      _showShareCodeDialog(t);
    } else {
      try {
        await FirebaseTournamentService.shareTournament(t);
        await TournamentStorage.saveTournament(t);
        if (mounted) {
          setState(() {});
          _showShareCodeDialog(t);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur de partage : $e')),
          );
        }
      }
    }
  }

  void _showShareCodeDialog(Tournament t) {
    showDialog(
      context: context,
      builder: (ctx) => ShareCodeDialog(
        shareCode: t.shareCode!,
        onStopSharing: () async {
          try {
            await FirebaseTournamentService.stopSharing(t);
            await TournamentStorage.saveTournament(t);
            if (mounted) setState(() {});
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur : $e')),
              );
            }
          }
        },
      ),
    );
  }

  String _phaseLabel(String phase) {
    switch (phase) {
      case 'registration':
        return 'Inscription';
      case 'pools':
        return 'Poules';
      case 'bracket':
        return 'Bracket';
      case 'finished':
        return 'Terminé';
      default:
        return phase;
    }
  }

  Color _phaseColor(String phase, Color themeColor) {
    switch (phase) {
      case 'registration':
        return const Color(0xFFEA580C);
      case 'pools':
        return const Color(0xFF2563EB);
      case 'bracket':
        return const Color(0xFF9333EA);
      case 'finished':
        return themeColor;
      default:
        return slate500;
    }
  }

  Color _phaseBgColor(String phase, Color themeColor50) {
    switch (phase) {
      case 'registration':
        return const Color(0xFFFFF7ED);
      case 'pools':
        return const Color(0xFFEFF6FF);
      case 'bracket':
        return const Color(0xFFFAF5FF);
      case 'finished':
        return themeColor50;
      default:
        return slate100;
    }
  }

  double _progressPercent() {
    if (_tournament == null) return 0;
    int played = 0;
    int total = 0;

    for (final pool in _tournament!.pools) {
      total += pool.matches.length;
      played += pool.matches.where((m) => m.score1 != null).length;
    }
    total += _tournament!.bracket.length;
    played += _tournament!.bracket.where((m) => m.score1 != null).length;

    return total == 0 ? 0 : played / total;
  }

  TournamentTeam? _getTeam(String? teamId) {
    if (teamId == null || _tournament == null) return null;
    return _tournament!.teams.where((t) => t.id == teamId).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final themeColor600 = theme.colors.shade600;
    final themeColor50 = theme.colors.shade50;

    if (_loading) {
      return const Scaffold(
        backgroundColor: slate50,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_tournament == null) {
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
                    const Text('Tournoi introuvable', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: slate800)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final t = _tournament!;
    final phaseCol = _phaseColor(t.phase, themeColor600);
    final phaseBg = _phaseBgColor(t.phase, themeColor50);
    final progress = _progressPercent();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        }
      },
      child: Scaffold(
        backgroundColor: slate50,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              _buildHeader(t, phaseCol, phaseBg, progress, themeColor600),

              // ── Winner banner ──
            if (t.phase == 'finished' && t.winnerId != null)
              _buildWinnerBanner(t, themeColor600),

            // ── Registration phase ──
            if (t.phase == 'registration')
              Expanded(child: _buildRegistrationPhase(t, themeColor600, themeColor50))
            else ...[
            // ── Tabs ──
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: slate200, width: 1)),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: themeColor600,
                unselectedLabelColor: slate500,
                indicatorColor: themeColor600,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'Poules'),
                  Tab(text: 'Bracket'),
                  Tab(text: 'Matchs'),
                  Tab(text: 'Stats'),
                ],
              ),
            ),

            // ── Tab content ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPoolsTab(t, themeColor600, themeColor50),
                  _buildBracketTab(t, themeColor600),
                  _buildMatchsTab(t, themeColor600),
                  _buildStatsTab(t),
                ],
              ),
            ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  // ── Registration Phase (organizer view) ──
  Widget _buildRegistrationPhase(Tournament t, Color themeColor600, Color themeColor50) {
    return StreamBuilder<List<Registration>>(
      stream: FirebaseTournamentService.streamRegistrations(t.id),
      builder: (context, snapshot) {
        final registrations = snapshot.data ?? [];
        final approved = registrations.where((r) => r.status == 'approved').toList();
        final pending = registrations.where((r) => r.status == 'pending').toList();

        return Column(
          children: [
            // Share code banner
            if (t.shareCode != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: themeColor50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: themeColor600.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.qrCode, size: 20, color: themeColor600),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Code de partage', style: TextStyle(fontSize: 12, color: slate500)),
                          Text(
                            t.shareCode!,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: themeColor600, letterSpacing: 2),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showShareCodeDialog(t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: slate200),
                        ),
                        child: Icon(LucideIcons.share2, size: 18, color: themeColor600),
                      ),
                    ),
                  ],
                ),
              ),

            // Counter
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(LucideIcons.users, size: 20, color: themeColor600),
                  const SizedBox(width: 8),
                  Text(
                    '${approved.length + t.teams.length} inscrits',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: slate800),
                  ),
                  if (t.maxTeams != null) ...[
                    Text(
                      ' / ${t.maxTeams}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: slate500),
                    ),
                  ],
                  if (pending.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${pending.length} en attente',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B)),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Registration list
            Expanded(
              child: RegistrationList(
                registrations: registrations,
                isManualApproval: !t.autoApprove,
                themeColor600: themeColor600,
                onApprove: (regId) async {
                  final currentApproved = approved.length + t.teams.length;
                  // Warn if approving beyond maxTeams
                  if (t.maxTeams != null && currentApproved >= t.maxTeams!) {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Dépasser la limite ?'),
                        content: Text(
                          'Le nombre maximum d\'équipes est de ${t.maxTeams}. '
                          'Vous avez déjà $currentApproved inscrits.\n\n'
                          'Voulez-vous quand même valider cette inscription ?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Annuler'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Valider quand même'),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                  }
                  await FirebaseTournamentService.approveRegistration(regId);
                },
                onReject: (regId) async {
                  await FirebaseTournamentService.rejectRegistration(regId);
                },
                onDelete: (regId) async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Supprimer l\'inscription ?'),
                      content: const Text('Cette action est irréversible.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Annuler'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Supprimer', style: TextStyle(color: Color(0xFFEF4444))),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true) return;
                  await FirebaseTournamentService.deleteRegistration(regId);
                },
                onRevoke: (regId) async {
                  await FirebaseTournamentService.revokeRegistration(regId);
                },
              ),
            ),

            // Launch button
            Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: (approved.length + t.teams.length) >= 3
                    ? () => _closeRegistrationAndLaunch(t, approved)
                    : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: (approved.length + t.teams.length) >= 3 ? themeColor600 : slate200,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: (approved.length + t.teams.length) >= 3
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
                      Icon(LucideIcons.rocket, size: 20,
                          color: (approved.length + t.teams.length) >= 3 ? Colors.white : slate400),
                      const SizedBox(width: 10),
                      Text(
                        'Fermer les inscriptions et lancer',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: (approved.length + t.teams.length) >= 3 ? Colors.white : slate400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _closeRegistrationAndLaunch(Tournament t, List<Registration> approved) async {
    // Convert approved registrations to teams
    final newTeams = <TournamentTeam>[];
    for (final reg in approved) {
      newTeams.add(TournamentTeam(
        id: generateId(),
        name: reg.type == 'team' && reg.teamName.isNotEmpty
            ? reg.teamName
            : reg.players.isNotEmpty
                ? reg.players.first
                : 'Équipe ${t.teams.length + newTeams.length + 1}',
        players: reg.players,
        color: reg.color.isNotEmpty ? reg.color : '#2563EB',
      ));
    }

    // Merge with any pre-added teams
    t.teams.addAll(newTeams);

    final teamCount = t.teams.length;
    if (teamCount < 3) return;

    // Use user's pool config, fallback to auto-calculate
    int effectivePoolCount = t.poolCount ?? _autoCalculatePoolCount(teamCount);

    // Validate pool config and warn user
    final conflict = _validatePoolConfig(teamCount, effectivePoolCount, t.mode);
    if (conflict != null) {
      if (!mounted) return;
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Configuration des poules'),
          content: Text(
            '$conflict\n\nQue souhaitez-vous faire ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'auto'),
              child: const Text('Recalculer automatiquement'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'force'),
              child: const Text('Lancer quand même'),
            ),
          ],
        ),
      );
      if (action == null || action == 'cancel') {
        // Remove added teams (revert)
        t.teams.removeRange(t.teams.length - newTeams.length, t.teams.length);
        return;
      }
      if (action == 'auto') {
        effectivePoolCount = _autoCalculatePoolCount(teamCount);
      }
      // 'force' keeps the user's config
    }

    // Generate pools
    final List<Pool> pools;
    if (t.mode == 'championnat') {
      pools = generateChampionnatPools(t.teams, poolCount: effectivePoolCount, targetScore: t.targetScore);
    } else {
      pools = generatePools(t.teams, poolCount: effectivePoolCount);
    }
    t.pools = pools;
    t.phase = 'pools';

    await TournamentStorage.saveTournament(t);

    // Push to Firestore
    if (t.isShared) {
      FirebaseTournamentService.pushTournamentUpdate(t).catchError((_) {});
    }

    if (mounted) {
      setState(() {
        _tournament = t;
      });
    }
  }

  int _autoCalculatePoolCount(int teamCount) {
    if (teamCount <= 4) return 1;
    if (teamCount <= 8) return 2;
    if (teamCount <= 12) return 3;
    if (teamCount <= 16) return 4;
    return (teamCount / 4).ceil();
  }

  /// Returns an error message if pool config is incompatible, null if OK.
  String? _validatePoolConfig(int teamCount, int poolCount, String mode) {
    if (poolCount > teamCount) {
      return 'Il y a plus de poules ($poolCount) que d\'équipes ($teamCount).';
    }
    final minPerPool = teamCount ~/ poolCount;
    if (minPerPool < 2) {
      final maxPools = teamCount ~/ 2;
      return 'Certaines poules n\'auraient qu\'1 équipe avec $poolCount poules pour $teamCount équipes. '
          'Maximum $maxPools poules possible.';
    }
    if (mode == 'championnat') {
      final maxPerPool = (teamCount / poolCount).ceil();
      if (maxPerPool > 4) {
        final minPools = (teamCount / 4).ceil();
        return 'En mode championnat, maximum 4 équipes par poule. '
            'Il faut au moins $minPools poules pour $teamCount équipes.';
      }
    }
    return null;
  }

  Widget _buildHeader(Tournament t, Color phaseCol, Color phaseBg, double progress, Color themeColor600) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        children: [
          Row(
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
                tooltip: 'Retour',
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: slate800),
                    ),
                    if (t.date.isNotEmpty || t.location.isNotEmpty)
                      Text(
                        [t.date, if (t.location.isNotEmpty) t.location].join(' — '),
                        style: const TextStyle(fontSize: 12, color: slate500),
                      ),
                  ],
                ),
              ),
              if (t.isShared) const LiveBadge(),
              if (t.isShared || context.read<PurchaseProvider>().isPro)
                IconButton(
                  onPressed: () => _toggleSharing(t),
                  icon: Icon(
                    t.isShared ? LucideIcons.wifi : LucideIcons.share2,
                    size: 20,
                    color: t.isShared ? const Color(0xFF10B981) : slate400,
                  ),
                  tooltip: t.isShared ? 'Partage actif' : 'Partager',
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: phaseBg, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  _phaseLabel(t.phase),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: phaseCol),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: slate200,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: themeColor600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWinnerBanner(Tournament t, Color themeColor600) {
    final winner = _getTeam(t.winnerId);
    if (winner == null) return const SizedBox.shrink();
    final winnerColor = parseHex(winner.color);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [amber500, themeColor600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: amber500.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.trophy, size: 32, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vainqueur',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white70),
                ),
                const SizedBox(height: 2),
                Text(
                  winner.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ],
            ),
          ),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: winnerColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ],
      ),
    );
  }

  // ── Poules Tab ──
  Widget _buildPoolsTab(Tournament t, Color themeColor600, Color themeColor50) {
    if (t.pools.isEmpty) {
      return const Center(
        child: Text('Aucune poule', style: TextStyle(fontSize: 16, color: slate400)),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final pool in t.pools) ...[
          Text(pool.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: themeColor600)),
          const SizedBox(height: 8),
          if (t.mode == 'championnat')
            ChampionnatPoolBracket(
              pool: pool,
              teams: t.teams,
              themeColor600: themeColor600,
              onMatchPress: (matchId) async {
                await context.push('/tournament/match/$matchId?tournamentId=${t.id}');
                if (mounted) _loadTournament();
              },
            )
          else ...[
            PoolTable(pool: pool, teams: t.teams),
            const SizedBox(height: 12),
            PoolMatchList(
              pool: pool,
              teams: t.teams,
              onMatchPress: (matchId) async {
                await context.push('/tournament/match/$matchId?tournamentId=${t.id}');
                if (mounted) _loadTournament();
              },
            ),
          ],
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  // ── Bracket Tab ──
  Widget _buildBracketTab(Tournament t, Color themeColor600) {
    final allPoolsComplete = t.pools.every((p) => p.completed);

    if (!allPoolsComplete && t.bracket.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.gitBranch, size: 48, color: slate200),
            const SizedBox(height: 12),
            const Text(
              'Terminez la phase de poules',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: slate400),
            ),
            const SizedBox(height: 4),
            const Text(
              'Le bracket sera généré automatiquement',
              style: TextStyle(fontSize: 13, color: slate400),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: BracketView(
            bracket: t.bracket,
            teams: t.teams,
            pools: t.pools,
            isChampionnat: t.mode == 'championnat',
            onMatchPress: (matchId) async {
              await context.push('/tournament/match/$matchId?tournamentId=${t.id}');
              if (mounted) _loadTournament();
            },
            onPoolPress: (poolId) {
              // Switch to Poules tab
              _tabController.animateTo(0);
            },
          ),
        ),
        // Full screen button
        Padding(
          padding: const EdgeInsets.all(16),
          child: GestureDetector(
            onTap: () async {
              await context.push('/tournament/bracket/${t.id}');
              if (mounted) _loadTournament();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: slate200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.maximize2, size: 18, color: themeColor600),
                  const SizedBox(width: 8),
                  Text(
                    'Voir en plein écran',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: themeColor600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Matchs Tab ──
  Widget _buildMatchsTab(Tournament t, Color themeColor600) {
    // Collect all matches
    final poolMatches = t.pools.expand((p) => p.matches).toList();
    final bracketMatches = t.bracket;

    final unplayed = <dynamic>[
      ...poolMatches.where((m) => m.score1 == null && m.team1Id.isNotEmpty && m.team2Id.isNotEmpty),
      ...bracketMatches.where((m) => m.score1 == null && m.team1Id != null && m.team2Id != null),
    ];

    final played = <dynamic>[
      ...poolMatches.where((m) => m.score1 != null && m.team1Id.isNotEmpty && m.team2Id.isNotEmpty),
      ...bracketMatches.where((m) => m.score1 != null),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Unplayed
        Text(
          'À jouer (${unplayed.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: slate800),
        ),
        const SizedBox(height: 8),
        if (unplayed.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('Aucun match à jouer', style: TextStyle(fontSize: 14, color: slate400))),
          )
        else
          for (final match in unplayed) ...[
            MatchCard(
              match: match,
              teams: t.teams,
              onPress: () async {
                final matchId = match is PoolMatch ? match.id : (match as BracketMatch).id;
                await context.push('/tournament/match/$matchId?tournamentId=${t.id}');
                if (mounted) _loadTournament();
              },
            ),
            const SizedBox(height: 8),
          ],

        const SizedBox(height: 24),

        // Played
        Text(
          'Terminés (${played.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: slate800),
        ),
        const SizedBox(height: 8),
        if (played.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('Aucun match terminé', style: TextStyle(fontSize: 14, color: slate400))),
          )
        else
          for (final match in played) ...[
            MatchCard(
              match: match,
              teams: t.teams,
              onPress: () async {
                final matchId = match is PoolMatch ? match.id : (match as BracketMatch).id;
                await context.push('/tournament/match/$matchId?tournamentId=${t.id}');
                if (mounted) _loadTournament();
              },
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  // ── Stats Tab ──
  Widget _buildStatsTab(Tournament t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: TournamentStats(tournament: t),
    );
  }
}
