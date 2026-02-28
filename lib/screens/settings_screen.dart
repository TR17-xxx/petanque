import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:petanque_score/providers/theme_provider.dart';
import 'package:petanque_score/services/secure_storage_service.dart';
import 'package:petanque_score/utils/colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  bool _obscureApiKey = true;
  bool _hasSavedApiKey = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    final key = await SecureStorageService.loadApiKey();
    if (!mounted) return;
    setState(() {
      if (key != null && key.isNotEmpty) {
        _apiKeyController.text = key;
        _hasSavedApiKey = true;
      }
    });
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) return;

    await SecureStorageService.saveApiKey(key);

    if (!mounted) return;
    setState(() {
      _hasSavedApiKey = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Clé API sauvegardée'),
        backgroundColor: context.read<ThemeProvider>().colors.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _deleteApiKey() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Supprimer la clé API ?',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: slate800,
          ),
        ),
        content: const Text(
          'La mesure par IA ne sera plus disponible.',
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

    await SecureStorageService.deleteApiKey();

    if (!mounted) return;
    setState(() {
      _apiKeyController.clear();
      _hasSavedApiKey = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Clé API supprimée'),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final themeColor600 = theme.colors.shade600;
    final themeColor50 = theme.colors.shade50;
    final themeColor200 = theme.colors.shade200;

    return Scaffold(
      backgroundColor: slate50,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      LucideIcons.arrowLeft,
                      size: 22,
                      color: slate800,
                    ),
                    tooltip: 'Retour',
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Paramètres',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: slate800,
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // ── Aide & Règles du jeu ──
                    _buildHelpCard(themeColor600),

                    const SizedBox(height: 20),

                    // ── Couleur de l'application ──
                    _buildThemeSection(theme, themeColor600, themeColor200),

                    const SizedBox(height: 20),

                    // ── Clé API Anthropic ──
                    _buildApiKeySection(themeColor600, themeColor50),

                    const SizedBox(height: 20),

                    // ── Info box ──
                    _buildInfoBox(),

                    const SizedBox(height: 32),

                    // ── Footer ──
                    const Center(
                      child: Text(
                        'Pétanque Score v1.0.0',
                        style: TextStyle(
                          fontSize: 13,
                          color: slate400,
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

  Widget _buildHelpCard(Color themeColor600) {
    return GestureDetector(
      onTap: () => context.push('/help'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
            Icon(LucideIcons.helpCircle, size: 24, color: themeColor600),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Aide & Règles du jeu',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: slate800,
                ),
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 20, color: slate400),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSection(
    ThemeProvider theme,
    Color themeColor600,
    Color themeColor200,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Couleur de l\'application',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: slate800,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
            ),
            itemCount: ThemeKey.values.length,
            itemBuilder: (context, index) {
              final key = ThemeKey.values[index];
              final palette = palettes[key]!;
              final label = themeLabels[key]!;
              final isSelected = theme.themeKey == key;

              return GestureDetector(
                onTap: () => theme.setTheme(key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? palette.shade50 : slate50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? palette.shade600 : slate200,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: palette.shade600,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? palette.shade700 : slate700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeySection(Color themeColor600, Color themeColor50) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Clé API Anthropic',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: slate800,
            ),
          ),
          const SizedBox(height: 12),

          // API key text field
          TextFormField(
            controller: _apiKeyController,
            obscureText: _obscureApiKey,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: slate800,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: 'sk-ant-...',
              hintStyle: const TextStyle(color: slate400),
              filled: true,
              fillColor: slate50,
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() => _obscureApiKey = !_obscureApiKey);
                },
                icon: Icon(
                  _obscureApiKey ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 20,
                  color: slate400,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Save + Delete buttons
          Row(
            children: [
              // Save button
              Expanded(
                child: GestureDetector(
                  onTap: _saveApiKey,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: themeColor600,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.save, size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Sauvegarder',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Delete button (only if saved)
              if (_hasSavedApiKey) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _deleteApiKey,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2), // red-100
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.trash2,
                          size: 18,
                          color: Color(0xFFEF4444), // red-500
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Supprimer',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // blue-50
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFBFDBFE), // blue-200
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              LucideIcons.info,
              size: 18,
              color: Color(0xFF3B82F6), // blue-500
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Pourquoi une clé API ?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E40AF), // blue-800
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'La clé API Anthropic permet d\'utiliser la fonctionnalité de mesure '
                  'des distances par IA. Elle est stockée de manière sécurisée sur votre '
                  'appareil et n\'est jamais partagée. Vous pouvez obtenir une clé sur '
                  'console.anthropic.com.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1E40AF), // blue-800
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
