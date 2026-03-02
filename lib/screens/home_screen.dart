import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:petanque_score/models/game.dart';
import 'package:petanque_score/models/tournament.dart';
import 'package:petanque_score/providers/purchase_provider.dart';
import 'package:petanque_score/providers/theme_provider.dart';
import 'package:petanque_score/services/storage_service.dart';
import 'package:petanque_score/services/tournament_storage.dart';
import 'package:petanque_score/services/update_service.dart';
import 'package:petanque_score/widgets/match_history_card.dart';
import 'package:petanque_score/widgets/update_dialog.dart';
import 'package:petanque_score/widgets/upgrade_dialog.dart';
import 'package:petanque_score/utils/app_config.dart';
import 'package:petanque_score/utils/colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Game> _activeGames = [];
  List<Game> _history = [];
  Tournament? _activeTournament;
  String _version = '';

  // Selection mode
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadVersion();
    _checkForUpdate();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  /// Vérifie si une mise à jour est disponible (silencieux en cas d'erreur).
  /// Désactivé sur le build Play Store (mises à jour via le Store).
  Future<void> _checkForUpdate() async {
    if (AppConfig.isPlayStore) return;

    final info = await UpdateService.checkForUpdate();
    if (info == null || !mounted) return;

    final wantsUpdate = await showUpdateDialog(context, info);
    if (!wantsUpdate || !mounted) return;

    // Vérifie la permission d'installation
    var canInstall = await UpdateService.canInstallPackages();

    if (!canInstall) {
      if (!mounted) return;
      final openSettings = await showPermissionDialog(context);
      if (!openSettings) return;

      await UpdateService.requestInstallPermission();

      // Attend le retour de l'utilisateur depuis les paramètres
      // et re-vérifie la permission
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      canInstall = await UpdateService.canInstallPackages();

      if (!canInstall) return;
    }

    // Lance le téléchargement et l'installation
    if (!mounted) return;
    await showDownloadDialog(context, info);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  Future<void> _loadData() async {
    final activeGames = await StorageService.loadActiveGames();
    final history = await StorageService.loadGameHistory();
    final activeId = await TournamentStorage.getActiveTournamentId();
    Tournament? activeTournament;
    if (activeId != null) {
      activeTournament = await TournamentStorage.loadTournament(activeId);
    }

    if (!mounted) return;
    setState(() {
      _activeGames = activeGames;
      _history = history;
      _activeTournament = activeTournament;
    });
  }

  void _enterSelectionMode(String gameId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectionMode = true;
      _selectedIds.clear();
      _selectedIds.add(gameId);
    });
  }

  void _toggleSelection(String gameId) {
    setState(() {
      if (_selectedIds.contains(gameId)) {
        _selectedIds.remove(gameId);
        if (_selectedIds.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedIds.add(gameId);
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  /// All selectable game IDs (active + history).
  Set<String> get _allGameIds => {
        ..._activeGames.map((g) => g.id),
        ..._history.map((g) => g.id),
      };

  void _selectAll() {
    setState(() {
      final all = _allGameIds;
      if (_selectedIds.length == all.length) {
        _selectedIds.clear();
        _selectionMode = false;
      } else {
        _selectedIds
          ..clear()
          ..addAll(all);
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Supprimer ${_selectedIds.length} partie${_selectedIds.length > 1 ? 's' : ''} ?',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: slate800,
          ),
        ),
        content: const Text(
          'Cette action est irréversible.',
          style: TextStyle(fontSize: 14, color: slate500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Annuler',
              style: TextStyle(fontWeight: FontWeight.w600, color: slate500),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final ids = _selectedIds.toList();
    // Remove from active games
    final activeIds = _activeGames.map((g) => g.id).toSet();
    for (final id in ids) {
      if (activeIds.contains(id)) {
        await StorageService.removeActiveGame(id);
      }
    }
    // Remove from history
    final historyIds = _history.map((g) => g.id).toSet();
    final historyToRemove = ids.where((id) => historyIds.contains(id)).toList();
    if (historyToRemove.isNotEmpty) {
      await StorageService.removeGamesFromHistory(historyToRemove);
    }
    _cancelSelection();
    await _loadData();
  }

  Future<void> _deleteTournament() async {
    if (_activeTournament == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          _activeTournament!.mode == 'championnat'
              ? 'Supprimer le championnat ?'
              : 'Supprimer le tournoi ?',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: slate800,
          ),
        ),
        content: Text(
          '« ${_activeTournament!.name} » sera supprimé définitivement.',
          style: const TextStyle(fontSize: 14, color: slate500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Annuler',
              style: TextStyle(fontWeight: FontWeight.w600, color: slate500),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await TournamentStorage.deleteTournament(_activeTournament!.id);
    await TournamentStorage.clearActiveTournament();
    await _loadData();
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
            // ── Selection mode bar or Header ──
            if (_selectionMode)
              _buildSelectionBar()
            else
              _buildHeader(themeColor600),

            // ── Content ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  // ── Action buttons ──
                  if (!_selectionMode) ...[
                    const SizedBox(height: 16),
                    _buildActionButtons(themeColor600),
                    const SizedBox(height: 10),
                    _buildFollowButton(themeColor600),
                  ],

                  // ── Active tournament banner ──
                  if (_activeTournament != null && !_selectionMode) ...[
                    const SizedBox(height: 12),
                    _buildTournamentBanner(),
                  ],

                  // ── Active games banners ──
                  if (_activeGames.isNotEmpty)
                    ..._activeGames.map((game) => Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _buildResumeGameBanner(game, themeColor600),
                        )),

                  // ── Last games label ──
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Dernières parties',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: slate800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Game history list ──
                  if (_history.isEmpty)
                    _buildEmptyState()
                  else
                    ..._history.map((game) => MatchHistoryCard(
                          game: game,
                          selectionMode: _selectionMode,
                          selected: _selectedIds.contains(game.id),
                          onLongPress: () {
                            if (!_selectionMode) {
                              _enterSelectionMode(game.id);
                            }
                          },
                          onPress: () {
                            if (_selectionMode) {
                              _toggleSelection(game.id);
                            } else {
                              context.push('/history?gameId=${game.id}');
                            }
                          },
                        )),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(LucideIcons.target, size: 28, color: themeColor600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pétanque Score',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: slate800,
                  ),
                ),
                if (_version.isNotEmpty)
                  Text(
                    'v$_version',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: slate400,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              await context.push('/help');
              if (mounted) _loadData();
            },
            icon: const Icon(LucideIcons.helpCircle, size: 22, color: slate500),
            tooltip: 'Aide',
          ),
          IconButton(
            onPressed: () async {
              await context.push('/settings');
              if (mounted) _loadData();
            },
            icon: const Icon(LucideIcons.settings, size: 22, color: slate500),
            tooltip: 'Paramètres',
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
        border: Border(
          bottom: BorderSide(color: slate200, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Cancel button
          IconButton(
            onPressed: _cancelSelection,
            icon: const Icon(LucideIcons.x, size: 22, color: slate700),
            tooltip: 'Annuler',
          ),

          // Count
          Text(
            '${_selectedIds.length} sélectionnée${_selectedIds.length > 1 ? 's' : ''}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: slate800,
            ),
          ),

          const Spacer(),

          // Select all toggle
          TextButton(
            onPressed: _selectAll,
            child: Text(
              _selectedIds.length == _allGameIds.length
                  ? 'Tout désélect.'
                  : 'Tout sélect.',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: slate500,
              ),
            ),
          ),

          // Delete button
          IconButton(
            onPressed: _selectedIds.isNotEmpty ? _deleteSelected : null,
            icon: Icon(
              LucideIcons.trash2,
              size: 22,
              color: _selectedIds.isNotEmpty
                  ? const Color(0xFFEF4444)
                  : slate400,
            ),
            tooltip: 'Supprimer',
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Color themeColor600) {
    final isPro = context.watch<PurchaseProvider>().isPro;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: LucideIcons.target,
              label: 'Partie',
              color: themeColor600,
              onTap: () async {
                await context.push('/setup');
                if (mounted) _loadData();
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildActionButton(
              icon: LucideIcons.trophy,
              label: 'Tournois',
              color: slate800,
              locked: !isPro,
              onTap: () async {
                if (!isPro) {
                  await showUpgradeDialog(context);
                  return;
                }
                await context.push('/tournament');
                if (mounted) _loadData();
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildActionButton(
              icon: LucideIcons.award,
              label: 'Champ.',
              color: const Color(0xFF7C3AED),
              locked: !isPro,
              onTap: () async {
                if (!isPro) {
                  await showUpgradeDialog(context);
                  return;
                }
                await context.push('/championnat');
                if (mounted) _loadData();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowButton(Color themeColor600) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () async {
          await context.push('/tournament/join');
          if (mounted) _loadData();
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
              Icon(LucideIcons.radio, size: 18, color: themeColor600),
              const SizedBox(width: 8),
              Text(
                'Suivre un tournoi',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: themeColor600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool locked = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (locked)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.lock, size: 12, color: slate500),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTournamentBanner() {
    final tournament = _activeTournament!;
    final isChamp = tournament.mode == 'championnat';
    final bannerColor = isChamp ? const Color(0xFF7C3AED) : const Color(0xFFF59E0B);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () async {
          await context.push('/tournament/${tournament.id}');
          if (mounted) _loadData();
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          _deleteTournament();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(color: bannerColor, width: 4),
            ),
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
              Icon(
                isChamp ? LucideIcons.award : LucideIcons.trophy,
                size: 24,
                color: bannerColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isChamp ? 'Championnat en cours' : 'Tournoi en cours',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: slate500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tournament.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: slate800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                size: 20,
                color: slate400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResumeGameBanner(Game game, Color themeColor600) {
    final lastRound = game.rounds.isNotEmpty ? game.rounds.last : null;
    final score1 = lastRound != null ? lastRound.totalAfter[0] : 0;
    final score2 = lastRound != null ? lastRound.totalAfter[1] : 0;
    final isSelected = _selectedIds.contains(game.id);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () async {
          if (_selectionMode) {
            _toggleSelection(game.id);
          } else {
            await context.push('/game/${game.id}');
            if (mounted) _loadData();
          }
        },
        onLongPress: () {
          if (!_selectionMode) {
            _enterSelectionMode(game.id);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFEF2F2) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(color: const Color(0xFFF87171), width: 2)
                : Border(
                    left: BorderSide(color: themeColor600, width: 4),
                  ),
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
              if (_selectionMode) ...[
                Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  size: 24,
                  color: isSelected
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFCBD5E1),
                ),
                const SizedBox(width: 12),
              ] else ...[
                Icon(
                  LucideIcons.play,
                  size: 24,
                  color: themeColor600,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Partie en cours',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: slate500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${game.team1.name} vs ${game.team2.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: slate800,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$score1 - $score2',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: themeColor600,
                ),
              ),
              if (!_selectionMode) ...[
                const SizedBox(width: 8),
                const Icon(
                  LucideIcons.chevronRight,
                  size: 20,
                  color: slate400,
                ),
              ],
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
            Icon(LucideIcons.target, size: 48, color: slate200),
            const SizedBox(height: 12),
            const Text(
              'Aucune partie jouée',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: slate400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
