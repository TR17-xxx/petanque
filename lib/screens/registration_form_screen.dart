import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:petanque_score/models/tournament.dart';
import 'package:petanque_score/models/registration.dart';
import 'package:petanque_score/services/firebase_tournament_service.dart';
import 'package:petanque_score/providers/theme_provider.dart';
import 'package:petanque_score/utils/colors.dart';
import 'package:petanque_score/utils/helpers.dart';

const List<String> _teamColors = [
  '#2563EB', '#DC2626', '#16A34A', '#EA580C',
  '#9333EA', '#DB2777', '#0D9488', '#CA8A04',
  '#4F46E5', '#0891B2', '#65A30D', '#C026D3',
  '#E11D48', '#0369A1', '#B91C1C', '#7C3AED',
];

class RegistrationFormScreen extends StatefulWidget {
  final String tournamentId;
  const RegistrationFormScreen({super.key, required this.tournamentId});

  @override
  State<RegistrationFormScreen> createState() => _RegistrationFormScreenState();
}

class _RegistrationFormScreenState extends State<RegistrationFormScreen> {
  Tournament? _tournament;
  bool _loading = true;
  bool _submitting = false;
  bool _submitted = false;

  final _teamNameController = TextEditingController();
  final List<TextEditingController> _playerControllers = [];
  String _selectedColor = _teamColors[0];

  @override
  void initState() {
    super.initState();
    _loadTournament();
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    for (final c in _playerControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _loadTournament() {
    FirebaseTournamentService.streamTournament(widget.tournamentId).first.then((t) {
      if (!mounted) return;
      if (t != null) {
        final count = _playersPerTeam(t.gameType);
        for (int i = 0; i < count; i++) {
          _playerControllers.add(TextEditingController());
        }
      }
      setState(() {
        _tournament = t;
        _loading = false;
      });
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  int _playersPerTeam(String gameType) {
    switch (gameType) {
      case 'triplette':
        return 3;
      case 'doublette':
        return 2;
      case 'tete-a-tete':
        return 1;
      default:
        return 3;
    }
  }

  bool _canSubmit() {
    if (_tournament == null) return false;
    final t = _tournament!;

    if (t.registrationType == 'team') {
      if (_teamNameController.text.trim().isEmpty) return false;
      // At least one player name required
      if (_playerControllers.every((c) => c.text.trim().isEmpty)) return false;
    } else {
      // Individual: at least the first player name
      if (_playerControllers.isEmpty || _playerControllers[0].text.trim().isEmpty) return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_canSubmit() || _submitting) return;
    setState(() => _submitting = true);

    try {
      final t = _tournament!;
      final uid = await FirebaseTournamentService.getCurrentUid();
      final players = _playerControllers
          .map((c) => c.text.trim())
          .where((p) => p.isNotEmpty)
          .toList();

      final reg = Registration(
        id: generateId(),
        tournamentId: t.id,
        type: t.registrationType,
        teamName: t.registrationType == 'team' ? _teamNameController.text.trim() : '',
        players: players,
        color: _selectedColor,
        status: t.autoApprove ? 'approved' : 'pending',
        createdAt: DateTime.now().toIso8601String(),
        createdBy: uid,
        organizerId: t.organizerId ?? '',
      );

      await FirebaseTournamentService.submitRegistration(reg);

      if (mounted) {
        setState(() {
          _submitting = false;
          _submitted = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
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
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.alertCircle, size: 48, color: slate300),
                const SizedBox(height: 12),
                const Text('Tournoi non trouvé', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: slate800)),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Retour'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_submitted) {
      return _buildSuccessScreen(themeColor600);
    }

    return _buildForm(themeColor600, themeColor50);
  }

  Widget _buildSuccessScreen(Color themeColor600) {
    final t = _tournament!;
    final isAutoApproved = t.autoApprove;

    return Scaffold(
      backgroundColor: slate50,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isAutoApproved ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isAutoApproved ? LucideIcons.checkCircle : LucideIcons.clock,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isAutoApproved ? 'Inscription confirmée !' : 'Inscription envoyée !',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: slate800),
                ),
                const SizedBox(height: 8),
                Text(
                  isAutoApproved
                      ? 'Vous êtes inscrit au tournoi.'
                      : 'Votre inscription est en attente de validation par l\'organisateur.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: slate500),
                ),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    decoration: BoxDecoration(
                      color: themeColor600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Retour au tournoi',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(Color themeColor600, Color themeColor50) {
    final t = _tournament!;
    final isTeam = t.registrationType == 'team';

    return Scaffold(
      backgroundColor: slate50,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(color: themeColor600),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(LucideIcons.arrowLeft, size: 22, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  Icon(isTeam ? LucideIcons.users : LucideIcons.user, size: 22, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    isTeam ? 'Inscrire une équipe' : 'S\'inscrire',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tournament info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: themeColor50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: themeColor600.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.trophy, size: 20, color: themeColor600),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: themeColor600)),
                                Text(
                                  '${t.date}${t.location.isNotEmpty ? ' — ${t.location}' : ''}',
                                  style: const TextStyle(fontSize: 12, color: slate500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Team name (if team mode)
                    if (isTeam) ...[
                      const Text('Nom de l\'équipe *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: slate700)),
                      const SizedBox(height: 8),
                      _buildTextField(_teamNameController, 'Ex: Les Invincibles', themeColor600),
                      const SizedBox(height: 20),
                    ],

                    // Player names
                    Text(
                      isTeam ? 'Joueurs' : 'Votre nom *',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: slate700),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _playerControllers.length; i++) ...[
                      _buildTextField(
                        _playerControllers[i],
                        isTeam ? 'Joueur ${i + 1}' : 'Votre nom',
                        themeColor600,
                      ),
                      if (i < _playerControllers.length - 1) const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 24),

                    // Color picker
                    const Text('Couleur', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: slate700)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: slate200),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _teamColors.map((c) {
                          final isSelected = _selectedColor == c;
                          final color = parseHex(c);
                          return GestureDetector(
                            onTap: () => setState(() => _selectedColor = c),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: slate800, width: 3)
                                    : Border.all(color: Colors.transparent, width: 3),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Submit button
                    GestureDetector(
                      onTap: _canSubmit() ? _submit : null,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _canSubmit() ? themeColor600 : slate200,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _canSubmit()
                              ? [
                                  BoxShadow(
                                    color: themeColor600.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: _submitting
                            ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.send, size: 18, color: _canSubmit() ? Colors.white : slate400),
                                  const SizedBox(width: 10),
                                  Text(
                                    'S\'inscrire',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _canSubmit() ? Colors.white : slate400),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, Color themeColor600) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: slate800),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: slate400),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: themeColor600, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      onChanged: (_) => setState(() {}),
    );
  }
}
