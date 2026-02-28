import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ColorPalette {
  final Color shade50;
  final Color shade200;
  final Color shade500;
  final Color shade600;
  final Color shade700;

  const ColorPalette({
    required this.shade50,
    required this.shade200,
    required this.shade500,
    required this.shade600,
    required this.shade700,
  });
}

enum ThemeKey { emerald, blue, violet, rose, amber, indigo }

const Map<ThemeKey, ColorPalette> palettes = {
  ThemeKey.emerald: ColorPalette(
    shade50: Color(0xFFECFDF5), shade200: Color(0xFFA7F3D0),
    shade500: Color(0xFF10B981), shade600: Color(0xFF059669), shade700: Color(0xFF047857),
  ),
  ThemeKey.blue: ColorPalette(
    shade50: Color(0xFFEFF6FF), shade200: Color(0xFFBFDBFE),
    shade500: Color(0xFF3B82F6), shade600: Color(0xFF2563EB), shade700: Color(0xFF1D4ED8),
  ),
  ThemeKey.violet: ColorPalette(
    shade50: Color(0xFFF5F3FF), shade200: Color(0xFFDDD6FE),
    shade500: Color(0xFF8B5CF6), shade600: Color(0xFF7C3AED), shade700: Color(0xFF6D28D9),
  ),
  ThemeKey.rose: ColorPalette(
    shade50: Color(0xFFFFF1F2), shade200: Color(0xFFFECDD3),
    shade500: Color(0xFFF43F5E), shade600: Color(0xFFE11D48), shade700: Color(0xFFBE123C),
  ),
  ThemeKey.amber: ColorPalette(
    shade50: Color(0xFFFFFBEB), shade200: Color(0xFFFDE68A),
    shade500: Color(0xFFF59E0B), shade600: Color(0xFFD97706), shade700: Color(0xFFB45309),
  ),
  ThemeKey.indigo: ColorPalette(
    shade50: Color(0xFFEEF2FF), shade200: Color(0xFFC7D2FE),
    shade500: Color(0xFF6366F1), shade600: Color(0xFF4F46E5), shade700: Color(0xFF4338CA),
  ),
};

const Map<ThemeKey, String> themeLabels = {
  ThemeKey.emerald: 'Vert',
  ThemeKey.blue: 'Bleu',
  ThemeKey.violet: 'Violet',
  ThemeKey.rose: 'Rose',
  ThemeKey.amber: 'Orange',
  ThemeKey.indigo: 'Indigo',
};

const _storageKey = '@petanque/theme_color';

class ThemeProvider extends ChangeNotifier {
  ThemeKey _themeKey = ThemeKey.emerald;

  ThemeKey get themeKey => _themeKey;
  ColorPalette get colors => palettes[_themeKey]!;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_storageKey);
    if (value != null) {
      for (final key in ThemeKey.values) {
        if (key.name == value) {
          _themeKey = key;
          notifyListeners();
          break;
        }
      }
    }
  }

  Future<void> setTheme(ThemeKey key) async {
    _themeKey = key;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, key.name);
  }
}
