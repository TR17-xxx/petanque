import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:petanque_score/models/tournament.dart';
import 'package:petanque_score/services/tournament_storage.dart';
import 'package:petanque_score/utils/tournament_logic.dart';
import 'package:petanque_score/utils/helpers.dart';
import 'package:petanque_score/providers/theme_provider.dart';
import 'package:petanque_score/utils/colors.dart';

const List<String> _teamColors = [
  '#2563EB', '#DC2626', '#16A34A', '#EA580C',
  '#9333EA', '#DB2777', '#0D9488', '#CA8A04',
  '#4F46E5', '#0891B2', '#65A30D', '#C026D3',
  '#E11D48', '#0369A1', '#B91C1C', '#7C3AED',
];

class TournamentCreateScreen extends StatefulWidget {
  final String? initialMode;

  const TournamentCreateScreen({super.key, this.initialMode});

  @override
  State<TournamentCreateScreen> createState() => _TournamentCreateScreenState();
}

class _TournamentCreateScreenState extends State<TournamentCreateScreen> {
  int _step = 0; // 0, 1, 2

  // Step 1: Tournament info
  final _nameController = TextEditingController();
  final _dateController = TextEditingController();
  final _locationController = TextEditingController();
  String _gameType = 'triplette'; // triplette | doublette | tete-a-tete
  String _mode = 'tournoi'; // tournoi | championnat
  bool _usePools = true; // true = multiple pools, false = single pool
  int _poolCount = 2; // number of pools when _usePools is true
  int _teamsPerPool = 3; // number of teams per pool
  bool _hasThirdPlace = false;
  int _poolTargetScore = 13;
  int _bracketTargetScore = 13;

  // Step 2: Teams
  final List<_TeamData> _teams = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialMode != null) {
      _mode = widget.initialMode!;
    }
    final now = DateTime.now();
    _dateController.text =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    // Initialize teams based on pool config
    _syncTeamsCount();
  }

  List<TextEditingController> _createPlayerControllers() {
    final count = _playersPerTeam();
    return List.generate(count, (_) => TextEditingController());
  }

  int _playersPerTeam() {
    switch (_gameType) {
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

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _locationController.dispose();
    for (final team in _teams) {
      team.nameController.dispose();
      for (final pc in team.playerControllers) {
        pc.dispose();
      }
    }
    super.dispose();
  }

  /// Calcule le nombre total d'équipes souhaité selon la config poules.
  int _targetTeamCount() {
    if (!_usePools) return _teamsPerPool;
    return _poolCount * _teamsPerPool;
  }

  /// Synchronise la liste _teams avec le nombre cible.
  void _syncTeamsCount() {
    final target = _targetTeamCount();
    // Ajouter des équipes si nécessaire
    while (_teams.length < target) {
      final idx = _teams.length;
      _teams.add(_TeamData(
        nameController: TextEditingController(text: 'Équipe ${idx + 1}'),
        playerControllers: _createPlayerControllers(),
        color: _teamColors[idx % _teamColors.length],
      ));
    }
    // Retirer des équipes si nécessaire (depuis la fin)
    while (_teams.length > target) {
      final removed = _teams.removeLast();
      removed.nameController.dispose();
      for (final pc in removed.playerControllers) {
        pc.dispose();
      }
    }
  }

  void _addTeam() {
    setState(() {
      final idx = _teams.length;
      _teams.add(_TeamData(
        nameController: TextEditingController(text: 'Équipe ${idx + 1}'),
        playerControllers: _createPlayerControllers(),
        color: _teamColors[idx % _teamColors.length],
      ));
    });
  }

  void _removeTeam(int index) {
    if (_teams.length <= 2) return;
    setState(() {
      _teams[index].nameController.dispose();
      for (final pc in _teams[index].playerControllers) {
        pc.dispose();
      }
      _teams.removeAt(index);
    });
  }

  void _updateTeamColor(int index, String color) {
    setState(() {
      _teams[index].color = color;
    });
  }

  bool _canGoStep2() {
    return _nameController.text.trim().isNotEmpty;
  }

  bool _canGoStep3() {
    if (_teams.length < 3) return false;
    for (final team in _teams) {
      if (team.nameController.text.trim().isEmpty) return false;
    }
    return _validatePoolConfig() == null;
  }

  /// Valide la configuration poules/équipes.
  /// Retourne un message d'erreur ou null si valide.
  String? _validatePoolConfig() {
    final nbTeams = _teams.length;
    final nbPools = _usePools ? _poolCount : 1;

    if (nbPools > nbTeams) {
      return 'Plus de poules ($nbPools) que d\'équipes ($nbTeams). Réduisez le nombre de poules.';
    }

    // Vérifier qu'aucune poule n'a moins de 2 équipes
    final minPerPool = nbTeams ~/ nbPools;
    if (minPerPool < 2) {
      final maxPools = nbTeams ~/ 2;
      return 'Certaines poules n\'auraient qu\'1 équipe. '
          'Maximum $maxPools poules pour $nbTeams équipes.';
    }

    // En mode championnat, les poules ne peuvent pas dépasser 4 équipes
    if (_mode == 'championnat' && nbPools > 1) {
      final maxPerPool = (nbTeams / nbPools).ceil();
      if (maxPerPool > 4) {
        final minPools = (nbTeams / 4).ceil();
        return 'En championnat, maximum 4 équipes par poule. '
            'Utilisez au moins $minPools poules pour $nbTeams équipes.';
      }
    }

    return null;
  }

  String _gameTypeLabel(String type) {
    switch (type) {
      case 'triplette':
        return 'Triplette';
      case 'doublette':
        return 'Doublette';
      case 'tete-a-tete':
        return 'Tête-à-tête';
      default:
        return type;
    }
  }

  String _stepTitle() {
    switch (_step) {
      case 0:
        return 'Informations';
      case 1:
        return 'Équipes';
      case 2:
        return 'Résumé';
      default:
        return '';
    }
  }

  Future<void> _launchTournament() async {
    final teams = _teams.map((t) {
      final players = t.playerControllers
          .map((pc) => pc.text.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      return TournamentTeam(
        id: generateId(),
        name: t.nameController.text.trim(),
        players: players,
        color: t.color,
      );
    }).toList();

    final List<Pool> pools;
    if (_mode == 'championnat') {
      pools = _usePools
          ? generateChampionnatPools(teams, poolCount: _poolCount, targetScore: _poolTargetScore)
          : generateChampionnatPools(teams, poolCount: 1, targetScore: _poolTargetScore);
    } else {
      pools = _usePools
          ? generatePools(teams, poolCount: _poolCount)
          : generatePools(teams, poolCount: 1);
    }

    final tournament = Tournament(
      id: generateId(),
      name: _nameController.text.trim(),
      date: _dateController.text.trim(),
      location: _locationController.text.trim(),
      gameType: _gameType,
      mode: _mode,
      targetScore: _mode == 'championnat' ? _poolTargetScore : 13,
      bracketTargetScore: _mode == 'championnat' ? _bracketTargetScore : null,
      teams: teams,
      pools: pools,
      bracket: [],
      phase: 'pools',
      hasThirdPlace: _hasThirdPlace,
      createdAt: DateTime.now().toIso8601String(),
    );

    await TournamentStorage.saveTournament(tournament);
    await TournamentStorage.setActiveTournament(tournament.id);

    if (!mounted) return;
    context.pushReplacement('/tournament/${tournament.id}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final themeColor600 = theme.colors.shade600;
    final themeColor50 = theme.colors.shade50;

    return Scaffold(
      backgroundColor: slate50,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            _buildHeader(themeColor600),

            // ── Step content ──
            Expanded(
              child: _step == 0
                  ? _buildStep1(themeColor600, themeColor50)
                  : _step == 1
                      ? _buildStep2(themeColor600, themeColor50)
                      : _buildStep3(themeColor600, themeColor50),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color themeColor600) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: themeColor600,
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  if (_step > 0) {
                    setState(() => _step--);
                  } else {
                    context.pop();
                  }
                },
                icon: const Icon(LucideIcons.arrowLeft, size: 22, color: Colors.white),
                tooltip: 'Retour',
              ),
              const SizedBox(width: 4),
              const Icon(LucideIcons.trophy, size: 22, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _stepTitle(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final isActive = i == _step;
              final isPast = i < _step;
              return Container(
                width: isActive ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isActive || isPast ? Colors.white : Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── STEP 1: Tournament info ──
  Widget _buildStep1(Color themeColor600, Color themeColor50) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name
          const Text('Nom du tournoi *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: slate700)),
          const SizedBox(height: 8),
          _buildTextField(_nameController, 'Ex: Tournoi de la Bastide', themeColor600),
          const SizedBox(height: 20),

          // Date
          const Text('Date (AAAA-MM-JJ)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: slate700)),
          const SizedBox(height: 8),
          _buildTextField(_dateController, 'AAAA-MM-JJ', themeColor600),
          const SizedBox(height: 20),

          // Location
          const Text('Lieu (optionnel)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: slate700)),
          const SizedBox(height: 8),
          _buildTextField(_locationController, 'Ex: Boulodrome municipal', themeColor600),
          const SizedBox(height: 24),

          // Game type
          const Text('Type de jeu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: slate700)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildOptionButton('Triplette', _gameType == 'triplette', themeColor600, themeColor50, () {
                setState(() {
                  _gameType = 'triplette';
                  _updatePlayersPerTeam();
                });
              }),
              const SizedBox(width: 8),
              _buildOptionButton('Doublette', _gameType == 'doublette', themeColor600, themeColor50, () {
                setState(() {
                  _gameType = 'doublette';
                  _updatePlayersPerTeam();
                });
              }),
              const SizedBox(width: 8),
              _buildOptionButton('Tête-à-tête', _gameType == 'tete-a-tete', themeColor600, themeColor50, () {
                setState(() {
                  _gameType = 'tete-a-tete';
                  _updatePlayersPerTeam();
                });
              }),
            ],
          ),
          const SizedBox(height: 24),

          // Mode
          const Text('Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: slate700)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildOptionButton('Tournoi', _mode == 'tournoi', themeColor600, themeColor50, () {
                setState(() {
                  _mode = 'tournoi';
                  _poolTargetScore = 13;
                  _bracketTargetScore = 13;
                });
              }),
              const SizedBox(width: 8),
              _buildOptionButton('Championnat', _mode == 'championnat', themeColor600, themeColor50, () {
                setState(() {
                  _mode = 'championnat';
                  _poolTargetScore = 11;
                  _bracketTargetScore = 13;
                });
              }),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _mode == 'tournoi'
                ? 'Poules en round-robin classique'
                : 'Format éliminatoire FFPJP (gagnants/perdants/barrage)',
            style: const TextStyle(fontSize: 11, color: slate500),
          ),

          // Score targets (championnat mode)
          if (_mode == 'championnat') ...[
            const SizedBox(height: 20),
            const Text('Score cible', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: slate700)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: slate200),
              ),
              child: Column(
                children: [
                  _buildScoreSelector('Poules', _poolTargetScore, themeColor600, themeColor50, (v) => setState(() => _poolTargetScore = v)),
                  const SizedBox(height: 12),
                  _buildScoreSelector('Bracket', _bracketTargetScore, themeColor600, themeColor50, (v) => setState(() => _bracketTargetScore = v)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Pools configuration
          const Text('Poules', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: slate700)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: slate200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Plusieurs poules', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: slate800)),
                          const SizedBox(height: 2),
                          Text(
                            _usePools
                                ? '$_poolCount poules de $_teamsPerPool équipes'
                                : 'Poule unique de $_teamsPerPool équipes',
                            style: const TextStyle(fontSize: 12, color: slate500),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _usePools,
                      onChanged: (v) => setState(() {
                        _usePools = v;
                        _syncTeamsCount();
                      }),
                      activeTrackColor: themeColor600,
                    ),
                  ],
                ),
                // Équipes par poule (toujours visible)
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Équipes par poule', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: slate700)),
                    const Spacer(),
                    GestureDetector(
                      onTap: _teamsPerPool > 2 ? () => setState(() {
                        _teamsPerPool--;
                        _syncTeamsCount();
                      }) : null,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _teamsPerPool > 2 ? themeColor50 : slate50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _teamsPerPool > 2 ? themeColor600 : slate200),
                        ),
                        child: Icon(LucideIcons.minus, size: 18, color: _teamsPerPool > 2 ? themeColor600 : slate400),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '$_teamsPerPool',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: themeColor600),
                      ),
                    ),
                    GestureDetector(
                      onTap: _teamsPerPool < 30 ? () => setState(() {
                        _teamsPerPool++;
                        _syncTeamsCount();
                      }) : null,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _teamsPerPool < 30 ? themeColor50 : slate50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _teamsPerPool < 30 ? themeColor600 : slate200),
                        ),
                        child: Icon(LucideIcons.plus, size: 18, color: _teamsPerPool < 30 ? themeColor600 : slate400),
                      ),
                    ),
                  ],
                ),
                if (_usePools) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Nombre de poules', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: slate700)),
                      const Spacer(),
                      GestureDetector(
                        onTap: _poolCount > 2 ? () => setState(() {
                          _poolCount--;
                          _syncTeamsCount();
                        }) : null,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _poolCount > 2 ? themeColor50 : slate50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _poolCount > 2 ? themeColor600 : slate200),
                          ),
                          child: Icon(LucideIcons.minus, size: 18, color: _poolCount > 2 ? themeColor600 : slate400),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '$_poolCount',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: themeColor600),
                        ),
                      ),
                      GestureDetector(
                        onTap: _poolCount < 10 ? () => setState(() {
                          _poolCount++;
                          _syncTeamsCount();
                        }) : null,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _poolCount < 10 ? themeColor50 : slate50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _poolCount < 10 ? themeColor600 : slate200),
                          ),
                          child: Icon(LucideIcons.plus, size: 18, color: _poolCount < 10 ? themeColor600 : slate400),
                        ),
                      ),
                    ],
                  ),
                  // Résumé dynamique
                  const SizedBox(height: 8),
                  Text(
                    '${_targetTeamCount()} équipes au total ($_teamsPerPool × $_poolCount)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: slate500),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Third place
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: slate200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Match 3ème place', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: slate800)),
                      SizedBox(height: 2),
                      Text('Petite finale entre les perdants des demi-finales', style: TextStyle(fontSize: 12, color: slate500)),
                    ],
                  ),
                ),
                Switch(
                  value: _hasThirdPlace,
                  onChanged: (v) => setState(() => _hasThirdPlace = v),
                  activeTrackColor: themeColor600,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Next button
          _buildNextButton('Suivant', _canGoStep2(), themeColor600, () {
            if (_canGoStep2()) setState(() => _step = 1);
          }),
        ],
      ),
    );
  }

  void _updatePlayersPerTeam() {
    final count = _playersPerTeam();
    for (final team in _teams) {
      while (team.playerControllers.length < count) {
        team.playerControllers.add(TextEditingController());
      }
      while (team.playerControllers.length > count) {
        team.playerControllers.removeLast();
      }
    }
  }

  // ── STEP 2: Teams ──
  Widget _buildStep2(Color themeColor600, Color themeColor50) {
    return Column(
      children: [
        // Team count header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(LucideIcons.users, size: 20, color: themeColor600),
              const SizedBox(width: 8),
              Text(
                '${_teams.length} équipes',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: slate800),
              ),
            ],
          ),
        ),

        // Team list
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (var i = 0; i < _teams.length; i++) _buildTeamCard(i, themeColor600, themeColor50),

              // Add team button
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _addTeam,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: slate400, width: 1, style: BorderStyle.solid),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.plus, size: 18, color: slate500),
                      const SizedBox(width: 8),
                      const Text(
                        'Ajouter une équipe',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: slate500),
                      ),
                    ],
                  ),
                ),
              ),

              // Warning si configuration invalide
              if (_teams.length >= 3 && _validatePoolConfig() != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2), // red-50
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)), // red-200
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.alertTriangle, size: 18, color: Color(0xFFDC2626)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _validatePoolConfig()!,
                          style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              _buildNextButton('Suivant', _canGoStep3(), themeColor600, () {
                if (_canGoStep3()) setState(() => _step = 2);
              }),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTeamCard(int index, Color themeColor600, Color themeColor50) {
    final team = _teams[index];
    final teamColor = parseHex(team.color);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: color dot + name + delete
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(color: teamColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: team.nameController,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: slate800),
                  decoration: InputDecoration(
                    hintText: 'Nom de l\'équipe',
                    hintStyle: const TextStyle(color: slate400),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (_teams.length > 2)
                IconButton(
                  onPressed: () => _removeTeam(index),
                  icon: const Icon(LucideIcons.trash2, size: 18, color: Color(0xFFEF4444)),
                  tooltip: 'Supprimer',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Player inputs
          for (var p = 0; p < team.playerControllers.length; p++) ...[
            TextField(
              controller: team.playerControllers[p],
              style: const TextStyle(fontSize: 13, color: slate700),
              decoration: InputDecoration(
                hintText: 'Joueur ${p + 1}',
                hintStyle: const TextStyle(color: slate400),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                filled: true,
                fillColor: slate50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: slate200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: slate200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: themeColor600, width: 2),
                ),
              ),
            ),
            if (p < team.playerControllers.length - 1) const SizedBox(height: 6),
          ],
          const SizedBox(height: 10),

          // Color picker
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _teamColors.map((c) {
              final isSelected = team.color == c;
              final color = parseHex(c);
              return GestureDetector(
                onTap: () => _updateTeamColor(index, c),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: slate800, width: 3)
                        : Border.all(color: Colors.transparent, width: 3),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── STEP 3: Summary ──
  Widget _buildStep3(Color themeColor600, Color themeColor50) {
    final previewTeams = _teams.map((t) => TournamentTeam(
      id: generateId(),
      name: t.nameController.text.trim(),
      players: t.playerControllers.map((pc) => pc.text.trim()).where((p) => p.isNotEmpty).toList(),
      color: t.color,
    )).toList();
    final List<Pool> pools;
    if (_mode == 'championnat') {
      pools = _usePools
          ? generateChampionnatPools(previewTeams, poolCount: _poolCount, targetScore: _poolTargetScore)
          : generateChampionnatPools(previewTeams, poolCount: 1, targetScore: _poolTargetScore);
    } else {
      pools = _usePools
          ? generatePools(previewTeams, poolCount: _poolCount)
          : generatePools(previewTeams, poolCount: 1);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tournament info card
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
                Text(
                  _nameController.text.trim(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: slate800),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(LucideIcons.calendar, _dateController.text),
                if (_locationController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _buildInfoRow(LucideIcons.mapPin, _locationController.text.trim()),
                ],
                const SizedBox(height: 4),
                _buildInfoRow(LucideIcons.users, '${_teams.length} équipes en ${_gameTypeLabel(_gameType)}'),
                const SizedBox(height: 4),
                _buildInfoRow(LucideIcons.shield, _mode == 'championnat' ? 'Championnat (FFPJP)' : 'Tournoi classique'),
                const SizedBox(height: 4),
                _buildInfoRow(LucideIcons.layoutGrid, _usePools ? '$_poolCount poules' : 'Poule unique'),
                if (_mode == 'championnat') ...[
                  const SizedBox(height: 4),
                  _buildInfoRow(LucideIcons.target, 'Poules: $_poolTargetScore pts — Bracket: $_bracketTargetScore pts'),
                ],
                if (_hasThirdPlace) ...[
                  const SizedBox(height: 4),
                  _buildInfoRow(LucideIcons.medal, 'Match 3ème place'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Pool preview
          const Text('Aperçu des poules', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: slate800)),
          const SizedBox(height: 8),
          for (final pool in pools)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pool.name,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: themeColor600),
                  ),
                  const SizedBox(height: 6),
                  ...pool.teamIds.map((teamId) {
                    // Find team in our _teams list by index (pool.teamIds are generated ids)
                    // We use index-based matching since we just generated them
                    final idx = pools.expand((p) => p.teamIds).toList().indexOf(teamId);
                    final name = idx >= 0 && idx < _teams.length ? _teams[idx].nameController.text : teamId;
                    final color = idx >= 0 && idx < _teams.length ? parseHex(_teams[idx].color) : slate400;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(name, style: const TextStyle(fontSize: 13, color: slate700)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Team list
          const Text('Équipes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: slate800)),
          const SizedBox(height: 8),
          for (final team in _teams)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: parseHex(team.color), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(
                    team.nameController.text.trim(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: slate800),
                  ),
                  if (team.playerControllers.any((pc) => pc.text.trim().isNotEmpty)) ...[
                    const SizedBox(width: 8),
                    Text(
                      '(${team.playerControllers.map((pc) => pc.text.trim()).where((p) => p.isNotEmpty).join(', ')})',
                      style: const TextStyle(fontSize: 12, color: slate500),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 24),

          // Launch button
          GestureDetector(
            onTap: _launchTournament,
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
                  Icon(LucideIcons.rocket, size: 20, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'Lancer le tournoi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: slate500),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 13, color: slate700)),
      ],
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

  Widget _buildOptionButton(String label, bool isSelected, Color themeColor600, Color themeColor50, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? themeColor50 : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? themeColor600 : slate200,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? themeColor600 : slate700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreSelector(String label, int value, Color themeColor600, Color themeColor50, ValueChanged<int> onChanged) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: slate700)),
        const Spacer(),
        GestureDetector(
          onTap: value > 1 ? () => onChanged(value - 1) : null,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: value > 1 ? themeColor50 : slate50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: value > 1 ? themeColor600 : slate200),
            ),
            child: Icon(LucideIcons.minus, size: 18, color: value > 1 ? themeColor600 : slate400),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '$value',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: themeColor600),
          ),
        ),
        GestureDetector(
          onTap: () => onChanged(value + 1),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: themeColor50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: themeColor600),
            ),
            child: Icon(LucideIcons.plus, size: 18, color: themeColor600),
          ),
        ),
      ],
    );
  }

  Widget _buildNextButton(String label, bool enabled, Color themeColor600, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: enabled ? themeColor600 : slate200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: enabled ? Colors.white : slate400,
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamData {
  TextEditingController nameController;
  List<TextEditingController> playerControllers;
  String color;

  _TeamData({
    required this.nameController,
    required this.playerControllers,
    required this.color,
  });
}
