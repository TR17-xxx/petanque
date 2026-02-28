import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  static const _apiKeyKey = '@petanque/api_key';

  static Future<void> saveApiKey(String key) async {
    await _storage.write(key: _apiKeyKey, value: key);
  }

  static Future<String?> loadApiKey() async {
    return await _storage.read(key: _apiKeyKey);
  }

  static Future<void> deleteApiKey() async {
    await _storage.delete(key: _apiKeyKey);
  }
}
