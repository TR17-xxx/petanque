import 'package:flutter/material.dart';

// ── Slate palette ──
const slate50 = Color(0xFFF8FAFC);
const slate100 = Color(0xFFF1F5F9);
const slate200 = Color(0xFFE2E8F0);
const slate300 = Color(0xFFCBD5E1);
const slate400 = Color(0xFF94A3B8);
const slate500 = Color(0xFF64748B);
const slate700 = Color(0xFF334155);
const slate800 = Color(0xFF1E293B);
const slate900 = Color(0xFF0F172A);

// ── Accent colors ──
const amber500 = Color(0xFFF59E0B);

Color parseHex(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length == 6) {
    return Color(int.parse('FF$cleaned', radix: 16));
  }
  return slate400;
}
