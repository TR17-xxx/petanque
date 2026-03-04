import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  static const _apiKeyKey = '@petanque/api_key';
  static const _followedKey = '@petanque/followed_tournaments_secure';

  static Future<void> saveApiKey(String key) async {
    await _storage.write(key: _apiKeyKey, value: key);
  }

  static Future<String?> loadApiKey() async {
    return await _storage.read(key: _apiKeyKey);
  }

  static Future<void> deleteApiKey() async {
    await _storage.delete(key: _apiKeyKey);
  }

  // --- Secure followed tournaments storage ---

  static Future<void> saveFollowedTournaments(String jsonString) async {
    await _storage.write(key: _followedKey, value: jsonString);
  }

  static Future<String?> loadFollowedTournaments() async {
    return await _storage.read(key: _followedKey);
  }
}
