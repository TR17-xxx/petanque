import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:petanque_score/models/tournament.dart';
import 'package:petanque_score/services/tournament_storage.dart';
import 'package:petanque_score/providers/theme_provider.dart';
import 'package:petanque_score/widgets/bracket_view.dart';
import 'package:petanque_score/utils/colors.dart';

class TournamentBracketScreen extends StatefulWidget {
  final String id;
  const TournamentBracketScreen({super.key, required this.id});

  @override
  State<TournamentBracketScreen> createState() => _TournamentBracketScreenState();
}

class _TournamentBracketScreenState extends State<TournamentBracketScreen> {
  Tournament? _tournament;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTournament();
  }

  Future<void> _loadTournament() async {
    final tournament = await TournamentStorage.loadTournament(widget.id);
    if (!mounted) return;
    setState(() {
      _tournament = tournament;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch theme so bracket_view gets it via context
    context.watch<ThemeProvider>();

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
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Tournoi introuvable', style: TextStyle(fontSize: 16, color: slate500)),
                const SizedBox(height: 16),
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
              ],
            ),
          ),
        ),
      );
    }

    final t = _tournament!;

    return Scaffold(
      backgroundColor: slate50,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header text
                Padding(
                  padding: const EdgeInsets.fromLTRB(56, 12, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${t.name} — Bracket',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: slate800),
                    ),
                  ),
                ),

                // Bracket view
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
                  ),
                ),
              ],
            ),

            // Floating back button
            Positioned(
              top: 8,
              left: 8,
              child: GestureDetector(
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(LucideIcons.arrowLeft, size: 20, color: slate800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
