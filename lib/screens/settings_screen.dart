import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:petanque_score/providers/purchase_provider.dart';
import 'package:petanque_score/utils/app_config.dart';
import 'package:petanque_score/providers/theme_provider.dart';
import 'package:petanque_score/services/secure_storage_service.dart';
import 'package:petanque_score/utils/colors.dart';
import 'package:petanque_score/widgets/upgrade_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  bool _obscureApiKey = true;
  bool _hasSavedApiKey = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
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

                    // ── Version Pro ──
                    _buildProSection(themeColor600),

                    const SizedBox(height: 20),

                    // ── Aide & Règles du jeu ──
                    _buildHelpCard(themeColor600),

                    const SizedBox(height: 20),

                    // ── Couleur de l'application ──
                    _buildThemeSection(theme, themeColor600, themeColor200),

                    const SizedBox(height: 20),

                    // ── Offrir un pastis ──
                    _buildDonationSection(),

                    const SizedBox(height: 20),

                    // ── Clé API Anthropic ──
                    _buildApiKeySection(themeColor600, themeColor50),

                    const SizedBox(height: 20),

                    // ── Info box ──
                    _buildInfoBox(),

                    const SizedBox(height: 32),

                    // ── Footer ──
                    Center(
                      child: Text(
                        'Pétanque Score${_version.isNotEmpty ? ' v$_version' : ''}',
                        style: const TextStyle(
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Couleur de l\'application',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: slate800,
                  ),
                ),
              ),
              if (!context.watch<PurchaseProvider>().isPro)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
            ],
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

              final isPro = context.watch<PurchaseProvider>().isPro;
              final isLocked = !isPro && key != ThemeKey.emerald;

              return GestureDetector(
                onTap: () {
                  if (isLocked) {
                    showUpgradeDialog(context);
                    return;
                  }
                  theme.setTheme(key);
                },
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
                  child: Stack(
                    children: [
                      Center(
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
                                color: isLocked ? slate400 : (isSelected ? palette.shade700 : slate700),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isLocked)
                        const Positioned(
                          top: 4,
                          right: 4,
                          child: Icon(LucideIcons.lock, size: 10, color: slate400),
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

  Widget _buildProSection(Color themeColor600) {
    final purchase = context.watch<PurchaseProvider>();

    if (purchase.isPro) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.crown, size: 22, color: Color(0xFF16A34A)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Version Pro',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                  Text(
                    purchase.isPlayStoreAvailable
                        ? 'Toutes les fonctionnalites sont debloquees.'
                        : 'Debloquee (installation directe).',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF15803D)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final price = purchase.proProduct?.price ?? '2,00\u00a0\u20ac';

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
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.crown, size: 22, color: Color(0xFFF59E0B)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Passer en Pro',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: slate800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  price,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(LucideIcons.trophy, size: 16, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              const Text('Tournois & Championnats',
                  style: TextStyle(fontSize: 13, color: slate500)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(LucideIcons.palette, size: 16, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              const Text('Themes personnalises',
                  style: TextStyle(fontSize: 13, color: slate500)),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => purchase.buyPro(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.crown, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Debloquer la version Pro',
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
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => purchase.restore(),
            child: const Center(
              child: Text(
                'Restaurer les achats',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: slate400,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationSection() {
    final purchase = context.watch<PurchaseProvider>();
    final price = purchase.pastisProduct?.price ?? '2,00\u00a0\u20ac';

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
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.beer, size: 22, color: Color(0xFFF59E0B)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Offrir un pastis',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: slate800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Soutenez le developpement de l\'application !',
            style: TextStyle(fontSize: 13, color: slate500),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () async {
              if (AppConfig.isPlayStore) {
                // Play Store: Google Play Billing
                await purchase.buyPastis();
                if (mounted) await showPastisThanksDialog(context);
              } else {
                // APK sideloadé: PayPal
                final url = Uri.parse('https://paypal.me/TR17petanque/2');
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.beer, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Offrir un pastis (${AppConfig.isPlayStore ? price : '2,00\u00a0\u20ac'})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
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
