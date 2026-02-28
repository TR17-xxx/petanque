import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game.dart';

class StorageService {
  static const _activeGamesKey = '@petanque/active_games';
  static const _currentGameKey = '@petanque/current_game'; // legacy migration
  static const _gameHistoryKey = '@petanque/game_history';
  static const _measureResultTempKey = '@petanque/measure_result_temp';
  static const _maxHistory = 10;

  // --- Parties actives (multiples simultanées) ---

  /// Loads all active (in-progress) games.
  static Future<List<Game>> loadActiveGames() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Migrate old single-game key if present
      final legacyJson = prefs.getString(_currentGameKey);
      if (legacyJson != null) {
        final legacyGame =
            Game.fromJson(jsonDecode(legacyJson) as Map<String, dynamic>);
        if (legacyGame.status == 'playing') {
          // Move to active games list
          await saveActiveGame(legacyGame);
        }
        await prefs.remove(_currentGameKey);
        // Re-read after migration
        return loadActiveGames();
      }

      final json = prefs.getString(_activeGamesKey);
      if (json == null) return [];
      final list = jsonDecode(json) as List;
      return list
          .map((e) => Game.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Loads a single active game by ID.
  static Future<Game?> loadActiveGame(String id) async {
    try {
      final games = await loadActiveGames();
      return games.where((g) => g.id == id).firstOrNull;
    } catch (e) {
      return null;
    }
  }

  /// Saves (inserts or updates) a game in the active list.
  static Future<void> saveActiveGame(Game game) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Read raw to avoid migration loop
      final json = prefs.getString(_activeGamesKey);
      final List<Game> games;
      if (json != null) {
        final list = jsonDecode(json) as List;
        games =
            list.map((e) => Game.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        games = [];
      }
      final index = games.indexWhere((g) => g.id == game.id);
      if (index >= 0) {
        games[index] = game;
      } else {
        games.insert(0, game);
      }
      await prefs.setString(
          _activeGamesKey, jsonEncode(games.map((g) => g.toJson()).toList()));
    } catch (e) {
      // ignore
    }
  }

  /// Removes an active game by ID.
  static Future<void> removeActiveGame(String id) async {
    try {
      final games = await loadActiveGames();
      games.removeWhere((g) => g.id == id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _activeGamesKey, jsonEncode(games.map((g) => g.toJson()).toList()));
    } catch (e) {
      // ignore
    }
  }

  // --- Historique ---

  static Future<List<Game>> loadGameHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_gameHistoryKey);
      if (json == null) return [];
      final list = jsonDecode(json) as List;
      return list.map((e) => Game.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> addGameToHistory(Game game) async {
    try {
      final history = await loadGameHistory();
      final updated = [game, ...history];
      if (updated.length > _maxHistory) {
        updated.removeRange(_maxHistory, updated.length);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_gameHistoryKey, jsonEncode(updated.map((g) => g.toJson()).toList()));
    } catch (e) {
      // ignore
    }
  }

  static Future<Game?> loadGameFromHistory(String id) async {
    try {
      final history = await loadGameHistory();
      return history.where((g) => g.id == id).firstOrNull;
    } catch (e) {
      return null;
    }
  }

  static Future<void> removeGamesFromHistory(List<String> ids) async {
    try {
      final history = await loadGameHistory();
      final updated = history.where((g) => !ids.contains(g.id)).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_gameHistoryKey, jsonEncode(updated.map((g) => g.toJson()).toList()));
    } catch (e) {
      // ignore
    }
  }

  // --- Résultat mesure temporaire ---

  static Future<void> saveMeasureResult(MeasureResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_measureResultTempKey, jsonEncode(result.toJson()));
    } catch (e) {
      // ignore
    }
  }

  static Future<MeasureResult?> loadMeasureResult() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_measureResultTempKey);
      if (json == null) return null;
      return MeasureResult.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  static Future<void> clearMeasureResult() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_measureResultTempKey);
    } catch (e) {
      // ignore
    }
  }
}
