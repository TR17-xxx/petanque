import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:petanque_score/services/update_service.dart';
import 'package:petanque_score/utils/colors.dart';

/// Affiche le dialog de nouvelle version disponible.
/// Retourne true si l'utilisateur veut mettre à jour.
Future<bool> showUpdateDialog(BuildContext context, UpdateInfo info) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF), // blue-50
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              LucideIcons.download,
              size: 22,
              color: Color(0xFF2563EB), // blue-600
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Mise à jour disponible',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: slate800,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning banner if force uninstall required
          if (info.forceUninstall) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2), // red-50
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)), // red-300
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.alertTriangle, size: 18, color: Color(0xFFDC2626)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vous devez désinstaller l\'ancienne version avant d\'installer cette mise à jour.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFDC2626),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Badge version
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4), // green-50
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Version ${info.version}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF16A34A), // green-600
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Changelog
          const Text(
            'Nouveautés :',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: slate700,
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: Text(
                info.changelog.isNotEmpty
                    ? info.changelog
                    : 'Améliorations et corrections.',
                style: const TextStyle(fontSize: 13, color: slate500, height: 1.5),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text(
            'Plus tard',
            style: TextStyle(fontWeight: FontWeight.w600, color: slate500),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text(
            'Mettre à jour',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  return result == true;
}

/// Affiche le dialog expliquant la permission "Sources inconnues".
/// Retourne true si l'utilisateur veut ouvrir les paramètres.
Future<bool> showPermissionDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED), // orange-50
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              LucideIcons.shieldAlert,
              size: 22,
              color: Color(0xFFEA580C), // orange-600
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Permission requise',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: slate800,
              ),
            ),
          ),
        ],
      ),
      content: const Text(
        'Pour installer la mise à jour, vous devez autoriser '
        'l\'installation depuis cette application dans les paramètres Android.\n\n'
        'Activez « Autoriser depuis cette source » puis revenez dans l\'app.',
        style: TextStyle(fontSize: 13, color: slate500, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text(
            'Annuler',
            style: TextStyle(fontWeight: FontWeight.w600, color: slate500),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFEA580C),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text(
            'Ouvrir les paramètres',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  return result == true;
}

/// Affiche le dialog de téléchargement avec barre de progression.
/// Gère tout le flux : téléchargement → installation.
Future<void> showDownloadDialog(BuildContext context, UpdateInfo info) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _DownloadDialog(info: info),
  );
}

class _DownloadDialog extends StatefulWidget {
  final UpdateInfo info;
  const _DownloadDialog({required this.info});

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  double _progress = 0;
  String _status = 'Téléchargement en cours...';
  bool _downloading = true;
  bool _error = false;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    _cancelToken = CancelToken();

    try {
      final filePath = await UpdateService.downloadApk(
        widget.info.apkUrl,
        (received, total) {
          if (!mounted) return;
          setState(() {
            _progress = total > 0 ? received / total : 0;
            _status = 'Téléchargement : ${(received / 1024 / 1024).toStringAsFixed(1)} / '
                '${(total / 1024 / 1024).toStringAsFixed(1)} Mo';
          });
        },
        cancelToken: _cancelToken,
      );

      if (!mounted) return;

      setState(() {
        _status = 'Installation...';
        _downloading = false;
      });

      // Lance l'installation
      await UpdateService.installApk(filePath);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      if (!mounted) return;
      setState(() {
        _error = true;
        _downloading = false;
        _status = _errorMessage(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _downloading = false;
        _status = 'Erreur : $e';
      });
    }
  }

  String _errorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Délai d\'attente dépassé. Vérifiez votre connexion.';
      case DioExceptionType.connectionError:
        return 'Pas de connexion Internet.';
      case DioExceptionType.badResponse:
        return 'Fichier introuvable (${e.response?.statusCode}).';
      default:
        return 'Erreur de téléchargement.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        _error ? 'Erreur' : 'Mise à jour',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 17,
          color: slate800,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_error) ...[
            // Barre de progression
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _downloading ? (_progress > 0 ? _progress : null) : null,
                minHeight: 8,
                backgroundColor: slate200,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            ),
            const SizedBox(height: 12),
            // Pourcentage
            if (_downloading && _progress > 0)
              Text(
                '${(_progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: slate800,
                ),
              ),
            const SizedBox(height: 4),
          ],
          // Texte d'état
          Text(
            _status,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _error ? const Color(0xFFEF4444) : slate500,
            ),
          ),
        ],
      ),
      actions: [
        if (_downloading)
          TextButton(
            onPressed: () {
              _cancelToken?.cancel();
            },
            child: const Text(
              'Annuler',
              style: TextStyle(fontWeight: FontWeight.w600, color: slate500),
            ),
          ),
        if (_error) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Fermer',
              style: TextStyle(fontWeight: FontWeight.w600, color: slate500),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _error = false;
                _downloading = true;
                _progress = 0;
                _status = 'Téléchargement en cours...';
              });
              _startDownload();
            },
            child: const Text(
              'Réessayer',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
        ],
        if (!_downloading && !_error)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Fermer',
              style: TextStyle(fontWeight: FontWeight.w600, color: slate500),
            ),
          ),
      ],
    );
  }
}
