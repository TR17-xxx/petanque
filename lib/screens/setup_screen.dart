import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:petanque_score/models/game.dart';
import 'package:petanque_score/providers/theme_provider.dart';
import 'package:petanque_score/services/storage_service.dart';
import 'package:petanque_score/utils/helpers.dart';
import 'package:petanque_score/utils/colors.dart';

/// Available team colors.
const _teamColors = [
  '#2563EB', // blue
  '#DC2626', // red
  '#16A34A', // green
  '#EA580C', // orange
  '#9333EA', // purple
  '#DB2777', // pink
  '#0D9488', // teal
  '#CA8A04', // yellow
];

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _team1Controller = TextEditingController(text: 'Équipe 1');
  final _team2Controller = TextEditingController(text: 'Équipe 2');
  String _team1Color = _teamColors[0]; // blue
  String _team2Color = _teamColors[1]; // red

  @override
  void dispose() {
    _team1Controller.dispose();
    _team2Controller.dispose();
    super.dispose();
  }

  Future<void> _startGame() async {
    final team1Name = _team1Controller.text.trim();
    final team2Name = _team2Controller.text.trim();

    if (team1Name.isEmpty || team2Name.isEmpty) return;

    final game = Game(
      id: generateId(),
      team1: Team(id: 1, name: team1Name, color: _team1Color),
      team2: Team(id: 2, name: team2Name, color: _team2Color),
      targetScore: 13,
      rounds: [],
      status: 'playing',
      createdAt: DateTime.now().toIso8601String(),
    );

    await StorageService.saveActiveGame(game);

    if (!mounted) return;
    context.go('/game/${game.id}');
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
            // ── Header bar ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: themeColor600,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      LucideIcons.arrowLeft,
                      size: 22,
                      color: Colors.white,
                    ),
                    tooltip: 'Retour',
                  ),
                  const SizedBox(width: 4),
                  const Icon(LucideIcons.trophy, size: 20, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text(
                    'Nouvelle partie',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // ── Form content ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
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
                      // ── Équipe 1 ──
                      const Text(
                        'Équipe 1',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: slate800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _team1Controller,
                        decoration: InputDecoration(
                          hintText: 'Nom de l\'équipe',
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
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: slate800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ColorPicker(
                        selectedColor: _team1Color,
                        disabledColor: _team2Color,
                        onColorSelected: (color) {
                          setState(() => _team1Color = color);
                        },
                      ),

                      const SizedBox(height: 28),

                      // ── Équipe 2 ──
                      const Text(
                        'Équipe 2',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: slate800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _team2Controller,
                        decoration: InputDecoration(
                          hintText: 'Nom de l\'équipe',
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
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: slate800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ColorPicker(
                        selectedColor: _team2Color,
                        disabledColor: _team1Color,
                        onColorSelected: (color) {
                          setState(() => _team2Color = color);
                        },
                      ),

                      const SizedBox(height: 24),

                      // ── Objectif pill ──
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: themeColor50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Objectif : 13 points',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: themeColor600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Team preview ──
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: slate50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            // Team 1 preview
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: parseHex(_team1Color),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _team1Controller.text.isEmpty
                                          ? 'Équipe 1'
                                          : _team1Controller.text,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: slate700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'vs',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: slate400,
                                ),
                              ),
                            ),
                            // Team 2 preview
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _team2Controller.text.isEmpty
                                          ? 'Équipe 2'
                                          : _team2Controller.text,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: slate700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: parseHex(_team2Color),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Start button ──
                      GestureDetector(
                        onTap: _startGame,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: themeColor600,
                            borderRadius: BorderRadius.circular(12),
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
                              Icon(LucideIcons.play, size: 20, color: Colors.white),
                              SizedBox(width: 10),
                              Text(
                                'Démarrer la partie',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Color picker widget: a row of colored circles with check mark on selected.
class _ColorPicker extends StatelessWidget {
  const _ColorPicker({
    required this.selectedColor,
    required this.disabledColor,
    required this.onColorSelected,
  });

  final String selectedColor;
  final String disabledColor;
  final ValueChanged<String> onColorSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _teamColors.map((colorHex) {
        final isSelected = colorHex == selectedColor;
        final isDisabled = colorHex == disabledColor;
        final color = parseHex(colorHex);

        return GestureDetector(
          onTap: isDisabled ? null : () => onColorSelected(colorHex),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isDisabled ? 0.3 : 1.0,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: Colors.white, width: 3)
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}
