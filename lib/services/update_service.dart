import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Informations sur une mise à jour disponible.
class UpdateInfo {
  final String version;
  final String apkUrl;
  final String changelog;
  final bool forceUninstall;

  const UpdateInfo({
    required this.version,
    required this.apkUrl,
    required this.changelog,
    this.forceUninstall = false,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] as String? ?? '',
      apkUrl: json['apk_url'] as String? ?? '',
      changelog: json['changelog'] as String? ?? '',
      forceUninstall: json['force_uninstall'] as bool? ?? false,
    );
  }
}

/// Service de vérification et téléchargement des mises à jour.
class UpdateService {
  // URL du fichier version.json — à remplacer avec votre URL
  static const _versionUrl =
      'https://raw.githubusercontent.com/TR17-xxx/petanque/main/version.json';

  static const _channel = MethodChannel('com.petanquescore.app/installer');

  /// Vérifie si une nouvelle version est disponible.
  /// Retourne [UpdateInfo] si mise à jour dispo, null sinon.
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http
          .get(Uri.parse(_versionUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final info = UpdateInfo.fromJson(data);

      if (info.version.isEmpty || info.apkUrl.isEmpty) return null;

      // Compare avec la version actuelle
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_compareVersions(info.version, currentVersion) > 0) {
        return info;
      }

      return null;
    } catch (_) {
      // Erreur réseau, timeout, JSON invalide → on ignore silencieusement
      return null;
    }
  }

  /// Télécharge l'APK avec indication de progression.
  /// [onProgress] reçoit (bytesReceived, totalBytes).
  /// Retourne le chemin local du fichier téléchargé.
  static Future<String> downloadApk(
    String url,
    void Function(int received, int total) onProgress, {
    CancelToken? cancelToken,
  }) async {
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/update.apk';

    // Supprime l'ancien APK s'il existe
    final oldFile = File(filePath);
    if (await oldFile.exists()) {
      await oldFile.delete();
    }

    final dio = Dio(BaseOptions(
      followRedirects: true,
      maxRedirects: 5,
      headers: {
        'Accept': 'application/octet-stream',
        'User-Agent': 'PetanqueScore-App',
      },
    ));
    await dio.download(
      url,
      filePath,
      cancelToken: cancelToken,
      onReceiveProgress: onProgress,
      options: Options(
        receiveTimeout: const Duration(minutes: 10),
        sendTimeout: const Duration(seconds: 30),
        followRedirects: true,
        maxRedirects: 5,
      ),
    );

    return filePath;
  }

  /// Vérifie si l'app a la permission d'installer des packages.
  static Future<bool> canInstallPackages() async {
    try {
      final result = await _channel.invokeMethod<bool>('canInstallPackages');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Ouvre les paramètres Android pour autoriser les sources inconnues.
  static Future<void> requestInstallPermission() async {
    try {
      await _channel.invokeMethod('requestInstallPermission');
    } catch (_) {
      // Ignore — l'utilisateur peut ne pas avoir accès aux paramètres
    }
  }

  /// Lance l'installation d'un APK téléchargé.
  static Future<void> installApk(String filePath) async {
    try {
      await _channel.invokeMethod('installApk', {'filePath': filePath});
    } catch (e) {
      throw Exception('Impossible de lancer l\'installation : $e');
    }
  }

  /// Compare deux versions semver (ex: "1.2.3" vs "1.1.0").
  /// Retourne > 0 si v1 > v2, 0 si égales, < 0 si v1 < v2.
  static int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Étend à 3 segments minimum
    while (parts1.length < 3) {
      parts1.add(0);
    }
    while (parts2.length < 3) {
      parts2.add(0);
    }

    for (var i = 0; i < 3; i++) {
      if (parts1[i] != parts2[i]) {
        return parts1[i] - parts2[i];
      }
    }
    return 0;
  }
}
