import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:petanque_score/models/shared_tournament_meta.dart';
import 'package:petanque_score/services/firebase_tournament_service.dart';
import 'package:petanque_score/providers/theme_provider.dart';
import 'package:petanque_score/utils/colors.dart';

class JoinTournamentScreen extends StatefulWidget {
  const JoinTournamentScreen({super.key});

  @override
  State<JoinTournamentScreen> createState() => _JoinTournamentScreenState();
}

class _JoinTournamentScreenState extends State<JoinTournamentScreen> {
  final _codeController = TextEditingController();
  List<SharedTournamentMeta> _followed = [];
  bool _loading = false;
  bool _loadingList = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFollowed();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowed() async {
    final list = await FirebaseTournamentService.loadFollowedTournaments();
    if (mounted) {
      setState(() {
        _followed = list;
        _loadingList = false;
      });
    }
  }

  String _formatCode(String input) {
    final clean = input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (clean.length <= 3) return clean;
    return 'PET-${clean.substring(clean.startsWith('PET') ? 3 : 0)}';
  }

  Future<void> _joinTournament() async {
    final raw = _codeController.text.trim();
    if (raw.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Normalize code
      String code = raw.toUpperCase().replaceAll(' ', '');
      if (!code.startsWith('PET-')) {
        code = 'PET-$code';
      }

      final tournamentId = await FirebaseTournamentService.resolveShareCode(code);
      if (tournamentId == null) {
        if (mounted) {
          setState(() {
            _error = 'Code introuvable. Vérifiez et réessayez.';
            _loading = false;
          });
        }
        return;
      }

      // Fetch tournament name for bookmark
      await FirebaseTournamentService.streamTournament(tournamentId).first.then((t) async {
        if (t != null) {
          await FirebaseTournamentService.followTournament(SharedTournamentMeta(
            firestoreDocId: tournamentId,
            shareCode: code,
            name: t.name,
            joinedAt: DateTime.now().toIso8601String(),
          ));
        }
      });

      if (!mounted) return;
      context.push('/tournament/live/$tournamentId');
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur de connexion. Vérifiez votre réseau.';
          _loading = false;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unfollowTournament(String docId) async {
    await FirebaseTournamentService.unfollowTournament(docId);
    await _loadFollowed();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final themeColor600 = theme.colors.shade600;

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
                  const Text(
                    'Suivre un tournoi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: slate800),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Code input section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: slate200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(LucideIcons.radio, size: 20, color: themeColor600),
                            const SizedBox(width: 8),
                            const Text(
                              'Entrez le code de partage',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: slate800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Demandez le code à l\'organisateur du tournoi.',
                          style: TextStyle(fontSize: 13, color: slate500),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
                            _ShareCodeFormatter(),
                          ],
                          decoration: InputDecoration(
                            hintText: 'PET-XXXXXX',
                            hintStyle: const TextStyle(color: slate300, letterSpacing: 2),
                            filled: true,
                            fillColor: slate50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: slate200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: slate200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: themeColor600, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3,
                            color: slate800,
                          ),
                          textAlign: TextAlign.center,
                          onSubmitted: (_) => _joinTournament(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            style: const TextStyle(fontSize: 13, color: Color(0xFFEF4444)),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _joinTournament,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              disabledBackgroundColor: slate300,
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Rejoindre',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Followed tournaments list
                  if (!_loadingList && _followed.isNotEmpty) ...[
                    const Text(
                      'Tournois suivis',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: slate800),
                    ),
                    const SizedBox(height: 12),
                    for (final meta in _followed) ...[
                      Dismissible(
                        key: Key(meta.firestoreDocId),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(LucideIcons.trash2, color: Colors.white, size: 20),
                        ),
                        onDismissed: (_) => _unfollowTournament(meta.firestoreDocId),
                        child: GestureDetector(
                          onTap: () => context.push('/tournament/live/${meta.firestoreDocId}'),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: slate200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: themeColor600.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(LucideIcons.trophy, size: 20, color: themeColor600),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        meta.name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: slate800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Code : ${meta.shareCode}',
                                        style: const TextStyle(fontSize: 12, color: slate500),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(LucideIcons.chevronRight, size: 18, color: slate400),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],

                  if (!_loadingList && _followed.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Column(
                        children: [
                          Icon(LucideIcons.radio, size: 48, color: slate200),
                          const SizedBox(height: 12),
                          const Text(
                            'Aucun tournoi suivi',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: slate400),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Entrez un code pour suivre un tournoi en temps réel',
                            style: TextStyle(fontSize: 13, color: slate400),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formats input as PET-XXXX automatically
class _ShareCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Extract only alphanumeric chars (no dashes)
    final raw = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    // Remove PET prefix if user typed it
    final withoutPrefix = raw.startsWith('PET') ? raw.substring(3) : raw;

    // Limit to 6 code chars
    final code = withoutPrefix.length > 6 ? withoutPrefix.substring(0, 6) : withoutPrefix;

    if (code.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final formatted = 'PET-$code';
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
