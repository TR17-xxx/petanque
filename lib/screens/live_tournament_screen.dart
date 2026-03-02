import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:petanque_score/models/tournament.dart';
import 'package:petanque_score/services/firebase_tournament_service.dart';
import 'package:petanque_score/providers/theme_provider.dart';
import 'package:petanque_score/utils/colors.dart';
import 'package:petanque_score/widgets/pool_table.dart';
import 'package:petanque_score/widgets/pool_match_list.dart';
import 'package:petanque_score/widgets/bracket_view.dart';
import 'package:petanque_score/widgets/match_card.dart';
import 'package:petanque_score/widgets/championnat_pool_bracket.dart';
import 'package:petanque_score/widgets/tournament_stats.dart';
import 'package:petanque_score/widgets/live_badge.dart';
import 'package:petanque_score/models/registration.dart';

class LiveTournamentScreen extends StatefulWidget {
  final String tournamentId;
  const LiveTournamentScreen({super.key, required this.tournamentId});

  @override
  State<LiveTournamentScreen> createState() => _LiveTournamentScreenState();
}

class _LiveTournamentScreenState extends State<LiveTournamentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showReadOnlySnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mode spectateur — lecture seule'),
        duration: Duration(seconds: 2),
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

  double _progressPercent(Tournament t) {
    int played = 0;
    int total = 0;
    for (final pool in t.pools) {
      total += pool.matches.length;
      played += pool.matches.where((m) => m.score1 != null).length;
    }
    total += t.bracket.length;
    played += t.bracket.where((m) => m.score1 != null).length;
    return total == 0 ? 0 : played / total;
  }

  TournamentTeam? _getTeam(Tournament t, String? teamId) {
    if (teamId == null) return null;
    return t.teams.where((team) => team.id == teamId).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final themeColor600 = theme.colors.shade600;
    final themeColor50 = theme.colors.shade50;

    return Scaffold(
      backgroundColor: slate50,
      body: SafeArea(
        child: StreamBuilder<Tournament?>(
          stream: FirebaseTournamentService.streamTournament(widget.tournamentId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.wifiOff, size: 48, color: slate300),
                    const SizedBox(height: 12),
                    const Text(
                      'Erreur de connexion',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: slate800),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Vérifiez votre connexion internet',
                      style: TextStyle(fontSize: 13, color: slate500),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        }
                      },
                      child: const Text('Retour'),
                    ),
                  ],
                ),
              );
            }

            final t = snapshot.data;
            if (t == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.wifiOff, size: 48, color: slate300),
                    const SizedBox(height: 12),
                    const Text(
                      'Tournoi non disponible',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: slate800),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Le partage a été arrêté ou le tournoi a été supprimé.',
                      style: TextStyle(fontSize: 13, color: slate500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        await FirebaseTournamentService.unfollowTournament(widget.tournamentId);
                        if (context.mounted) {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/');
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Ne plus suivre'),
                    ),
                  ],
                ),
              );
            }

            final phaseCol = _phaseColor(t.phase, themeColor600);
            final phaseBg = _phaseBgColor(t.phase, themeColor50);
            final progress = _progressPercent(t);

            return Column(
              children: [
                // Header
                _buildHeader(t, phaseCol, phaseBg, progress, themeColor600),

                // Winner banner
                if (t.phase == 'finished' && t.winnerId != null)
                  _buildWinnerBanner(t, themeColor600),

                // Registration phase
                if (t.phase == 'registration')
                  Expanded(child: _buildRegistrationView(t, themeColor600, themeColor50))
                else ...[
                // Tabs
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

                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPoolsTab(t, themeColor600, themeColor50),
                      _buildBracketTab(t, themeColor600),
                      _buildMatchsTab(t),
                      _buildStatsTab(t),
                    ],
                  ),
                ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Registration View (viewer/player) ──
  Widget _buildRegistrationView(Tournament t, Color themeColor600, Color themeColor50) {
    return StreamBuilder<List<Registration>>(
      stream: FirebaseTournamentService.streamRegistrations(t.id),
      builder: (context, snapshot) {
        final registrations = snapshot.data ?? [];
        final approved = registrations.where((r) => r.status == 'approved').toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tournament info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: slate200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(LucideIcons.clipboardList, size: 20, color: themeColor600),
                        const SizedBox(width: 8),
                        const Text('Inscriptions ouvertes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: slate800)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(LucideIcons.users, size: 16, color: slate500),
                        const SizedBox(width: 6),
                        Text(
                          '${approved.length + t.teams.length} inscrits${t.maxTeams != null ? ' / ${t.maxTeams}' : ''}',
                          style: const TextStyle(fontSize: 13, color: slate700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(LucideIcons.gamepad2, size: 16, color: slate500),
                        const SizedBox(width: 6),
                        Text(
                          t.registrationType == 'team' ? 'Inscription par équipe' : 'Inscription individuelle',
                          style: const TextStyle(fontSize: 13, color: slate700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Register button
              GestureDetector(
                onTap: () => context.push('/tournament/register/${t.id}'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: themeColor600,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor600.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.userPlus, size: 20, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'S\'inscrire',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // List of approved registrations
              if (approved.isNotEmpty || t.teams.isNotEmpty) ...[
                Text(
                  'Inscrits (${approved.length + t.teams.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: slate800),
                ),
                const SizedBox(height: 8),
                // Pre-added teams by organizer
                for (final team in t.teams)
                  _buildRegisteredTeamRow(team.name, team.players, team.color),
                // Approved registrations
                for (final reg in approved)
                  _buildRegisteredTeamRow(
                    reg.type == 'team' && reg.teamName.isNotEmpty ? reg.teamName : reg.players.isNotEmpty ? reg.players.first : '—',
                    reg.players,
                    reg.color,
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRegisteredTeamRow(String name, List<String> players, String color) {
    final teamColor = parseHex(color);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: slate200),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: teamColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: slate800)),
                if (players.isNotEmpty)
                  Text(
                    players.join(', '),
                    style: const TextStyle(fontSize: 12, color: slate500),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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
              const LiveBadge(),
              const SizedBox(width: 8),
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
    final winner = _getTeam(t, t.winnerId);
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

  // ── Poules Tab (read-only) ──
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
              onMatchPress: (_) => _showReadOnlySnackbar(),
            )
          else ...[
            PoolTable(pool: pool, teams: t.teams),
            const SizedBox(height: 12),
            PoolMatchList(
              pool: pool,
              teams: t.teams,
              onMatchPress: (_) => _showReadOnlySnackbar(),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  // ── Bracket Tab (read-only) ──
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
              'Phase de poules en cours',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: slate400),
            ),
            const SizedBox(height: 4),
            const Text(
              'Le bracket apparaîtra une fois les poules terminées',
              style: TextStyle(fontSize: 13, color: slate400),
            ),
          ],
        ),
      );
    }

    return BracketView(
      bracket: t.bracket,
      teams: t.teams,
      pools: t.pools,
      isChampionnat: t.mode == 'championnat',
      onMatchPress: (_) => _showReadOnlySnackbar(),
      onPoolPress: (_) => _tabController.animateTo(0),
    );
  }

  // ── Matchs Tab (read-only) ──
  Widget _buildMatchsTab(Tournament t) {
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
              onPress: _showReadOnlySnackbar,
            ),
            const SizedBox(height: 8),
          ],

        const SizedBox(height: 24),

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
              onPress: _showReadOnlySnackbar,
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
