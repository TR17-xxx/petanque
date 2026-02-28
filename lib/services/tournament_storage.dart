import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tournament.dart';

class TournamentStorage {
  static const _listKey = '@petanque/tournament_list';
  static const _activeKey = '@petanque/tournament_active';

  static String _tournamentKey(String id) => '@petanque/tournament_$id';

  // --- CRUD ---

  static Future<void> saveTournament(Tournament tournament) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tournamentKey(tournament.id), jsonEncode(tournament.toJson()));

      final ids = await _loadIds();
      if (!ids.contains(tournament.id)) {
        ids.insert(0, tournament.id);
        await prefs.setString(_listKey, jsonEncode(ids));
      }
    } catch (e) {
      // ignore
    }
  }

  static Future<Tournament?> loadTournament(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_tournamentKey(id));
      if (json == null) return null;
      return Tournament.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  static Future<void> deleteTournament(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tournamentKey(id));

      final ids = await _loadIds();
      ids.remove(id);
      await prefs.setString(_listKey, jsonEncode(ids));

      final activeId = await getActiveTournamentId();
      if (activeId == id) {
        await clearActiveTournament();
      }
    } catch (e) {
      // ignore
    }
  }

  // --- Liste ---

  static Future<List<String>> _loadIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_listKey);
      if (json == null) return [];
      return List<String>.from(jsonDecode(json) as List);
    } catch (e) {
      return [];
    }
  }

  static Future<List<Tournament>> loadTournamentList() async {
    try {
      final ids = await _loadIds();
      final tournaments = <Tournament>[];
      for (final id in ids) {
        final t = await loadTournament(id);
        if (t != null) tournaments.add(t);
      }
      return tournaments;
    } catch (e) {
      return [];
    }
  }

  // --- Tournoi actif ---

  static Future<void> setActiveTournament(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeKey, id);
    } catch (e) {
      // ignore
    }
  }

  static Future<String?> getActiveTournamentId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_activeKey);
    } catch (e) {
      return null;
    }
  }

  static Future<void> clearActiveTournament() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeKey);
    } catch (e) {
      // ignore
    }
  }
}
