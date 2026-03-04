import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:petanque_score/models/tournament.dart';
import 'package:petanque_score/services/tournament_storage.dart';
import 'package:petanque_score/services/firebase_tournament_service.dart';
import 'package:petanque_score/providers/theme_provider.dart';
import 'package:petanque_score/utils/colors.dart';

const _red500 = Color(0xFFEF4444);

class TournamentListScreen extends StatefulWidget {
  final String? modeFilter;

  const TournamentListScreen({super.key, this.modeFilter});

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  List<Tournament> _tournaments = [];
  bool _loading = true;

  // Selection mode
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  bool get _isChampionnat => widget.modeFilter == 'championnat';
  String get _noun => _isChampionnat ? 'championnat' : 'tournoi';
  String get _nounPlural => _isChampionnat ? 'championnats' : 'tournois';
  String get _nounCapital => _isChampionnat ? 'Championnats' : 'Tournois';

  Future<void> _loadData() async {
    var tournaments = await TournamentStorage.loadTournamentList();
    if (widget.modeFilter != null) {
      tournaments = tournaments.where((t) => t.mode == widget.modeFilter).toList();
    }
    if (!mounted) return;
    setState(() {
      _tournaments = tournaments;
      _loading = false;
    });
  }

  void _enterSelectionMode(String id) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectionMode = true;
      _selectedIds.clear();
      _selectedIds.add(id);
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _tournaments.length) {
        _selectedIds.clear();
        _selectionMode = false;
      } else {
        _selectedIds.clear();
        for (final t in _tournaments) {
          _selectedIds.add(t.id);
        }
      }
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Supprimer ${_selectedIds.length} $_noun${_selectedIds.length > 1 ? 's' : ''} ?',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: slate800),
        ),
        content: const Text(
          'Cette action est irréversible.',
          style: TextStyle(fontSize: 14, color: slate500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600, color: slate500)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.w600, color: _red500)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    for (final id in _selectedIds) {
      // If tournament was shared, also stop sharing on Firestore
      final t = _tournaments.where((t) => t.id == id).firstOrNull;
      if (t != null && t.isShared && t.shareCode != null) {
        try {
          await FirebaseTournamentService.stopSharing(t);
        } catch (_) {}
      }
      await TournamentStorage.deleteTournament(id);
    }
    _cancelSelection();
    await _loadData();
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
        return const Color(0xFFEA580C); // orange
      case 'pools':
        return const Color(0xFF2563EB); // blue
      case 'bracket':
        return const Color(0xFF9333EA); // purple
      case 'finished':
        return themeColor;
      default:
        return slate500;
    }
  }

  Color _phaseBgColor(String phase, Color themeColor50) {
    switch (phase) {
      case 'registration':
        return const Color(0xFFFFF7ED); // orange-50
      case 'pools':
        return const Color(0xFFEFF6FF); // blue-50
      case 'bracket':
        return const Color(0xFFFAF5FF); // purple-50
      case 'finished':
        return themeColor50;
      default:
        return slate100;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
      return dateStr;
    } catch (_) {
      return dateStr;
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

    final activeTournaments = _tournaments.where((t) => t.phase != 'finished').toList();
    final pastTournaments = _tournaments.where((t) => t.phase == 'finished').toList();

    return Scaffold(
      backgroundColor: slate50,
      body: SafeArea(
        child: Column(
          children: [
            // ── Selection bar or Header ──
            if (_selectionMode)
              _buildSelectionBar()
            else
              _buildHeader(themeColor600),

            // ── Content ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  // ── Create button ──
                  if (!_selectionMode) ...[
                    const SizedBox(height: 16),
                    _buildCreateButton(themeColor600),
                  ],

                  // ── Rules card (championnat only) ──
                  if (_isChampionnat && !_selectionMode) ...[
                    const SizedBox(height: 12),
                    _buildRulesCard(themeColor600),
                  ],

                  // ── Active tournaments ──
                  if (activeTournaments.isNotEmpty && !_selectionMode) ...[
                    const SizedBox(height: 16),
                    for (final t in activeTournaments)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildActiveBanner(t, themeColor600, themeColor50),
                      ),
                  ],

                  // ── Past tournaments ──
                  const SizedBox(height: 24),
                  if (!_selectionMode)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '$_nounCapital passés',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: slate800),
                      ),
                    ),
                  const SizedBox(height: 12),

                  if (_selectionMode)
                    ..._tournaments.map((t) => _buildTournamentCard(t, themeColor600, themeColor50))
                  else if (pastTournaments.isEmpty)
                    _buildEmptyState()
                  else
                    ...pastTournaments.map((t) => _buildTournamentCard(t, themeColor600, themeColor50)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color themeColor600) {
    return Padding(
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
          Icon(_isChampionnat ? LucideIcons.award : LucideIcons.trophy, size: 24, color: themeColor600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _nounCapital,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: slate800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: slate200, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _cancelSelection,
            icon: const Icon(LucideIcons.x, size: 22, color: slate700),
            tooltip: 'Annuler',
          ),
          Text(
            '${_selectedIds.length} sélectionné${_selectedIds.length > 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: slate800),
          ),
          const Spacer(),
          TextButton(
            onPressed: _selectAll,
            child: Text(
              _selectedIds.length == _tournaments.length
                  ? 'Tout désélect.'
                  : 'Tout sélect.',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: slate500,
              ),
            ),
          ),
          IconButton(
            onPressed: _selectedIds.isNotEmpty ? _deleteSelected : null,
            icon: Icon(
              LucideIcons.trash2,
              size: 22,
              color: _selectedIds.isNotEmpty ? _red500 : slate400,
            ),
            tooltip: 'Supprimer',
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton(Color themeColor600) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () async {
          final mode = widget.modeFilter ?? 'tournoi';
          await context.push('/tournament/create?mode=$mode');
          if (mounted) _loadData();
        },
        child: Container(
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.plus, size: 20, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                'Créer un $_noun',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveBanner(Tournament tournament, Color themeColor600, Color themeColor50) {
    final phaseCol = _phaseColor(tournament.phase, themeColor600);
    final phaseBg = _phaseBgColor(tournament.phase, themeColor50);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onLongPress: () {
          if (!_selectionMode) {
            _enterSelectionMode(tournament.id);
          }
        },
        onTap: () async {
          if (_selectionMode) {
            _toggleSelection(tournament.id);
          } else {
            await context.push('/tournament/${tournament.id}');
            if (mounted) _loadData();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: const Border(left: BorderSide(color: amber500, width: 4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.trophy, size: 24, color: amber500),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tournament.mode == 'championnat' ? 'Championnat en cours' : 'Tournoi en cours',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: slate500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tournament.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: slate800),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: phaseBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _phaseLabel(tournament.phase),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: phaseCol),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(LucideIcons.chevronRight, size: 20, color: slate400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTournamentCard(Tournament tournament, Color themeColor600, Color themeColor50) {
    final isSelected = _selectedIds.contains(tournament.id);
    final phaseCol = _phaseColor(tournament.phase, themeColor600);
    final phaseBg = _phaseBgColor(tournament.phase, themeColor50);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onLongPress: () {
          if (!_selectionMode) {
            _enterSelectionMode(tournament.id);
          }
        },
        onTap: () {
          if (_selectionMode) {
            _toggleSelection(tournament.id);
          } else {
            context.push('/tournament/${tournament.id}').then((_) {
              if (mounted) _loadData();
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? themeColor50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: themeColor600, width: 2)
                : Border.all(color: slate200, width: 1),
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
              if (_selectionMode) ...[
                Icon(
                  isSelected ? LucideIcons.checkCircle2 : LucideIcons.circle,
                  size: 22,
                  color: isSelected ? themeColor600 : slate400,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(tournament.date),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: slate500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tournament.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: slate800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${tournament.teams.length} équipes${tournament.mode == 'championnat' ? ' — Championnat' : ''}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: slate500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: phaseBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _phaseLabel(tournament.phase),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: phaseCol),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_isChampionnat ? LucideIcons.award : LucideIcons.trophy, size: 48, color: slate200),
            const SizedBox(height: 12),
            Text(
              'Aucun $_noun',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: slate400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRulesCard(Color themeColor600) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => context.push('/help?section=Championnat (FFPJP)'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: slate200),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.info, size: 18, color: themeColor600),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Règles Championnat (FFPJP)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: slate800),
                ),
              ),
              const Icon(LucideIcons.chevronRight, size: 18, color: slate400),
            ],
          ),
        ),
      ),
    );
  }

}
