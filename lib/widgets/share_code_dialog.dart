import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petanque_score/utils/colors.dart';

class ShareCodeDialog extends StatelessWidget {
  final String shareCode;
  final VoidCallback onStopSharing;

  const ShareCodeDialog({
    super.key,
    required this.shareCode,
    required this.onStopSharing,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      title: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Tournoi partagé',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: slate800,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Partagez ce code avec les spectateurs pour qu\'ils puissent suivre le tournoi en temps réel.',
            style: TextStyle(fontSize: 13, color: slate500),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: slate50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: slate200),
            ),
            child: Text(
              shareCode,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
                color: slate800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: shareCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Code copié !'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copier le code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Fermer',
            style: TextStyle(color: slate500),
          ),
        ),
        TextButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text(
                  'Arrêter le partage ?',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: slate800,
                  ),
                ),
                content: const Text(
                  'Les spectateurs ne pourront plus suivre le tournoi.',
                  style: TextStyle(fontSize: 14, color: slate500),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Annuler',
                        style: TextStyle(color: slate500)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop();
                      onStopSharing();
                    },
                    child: const Text(
                      'Arrêter',
                      style: TextStyle(color: Color(0xFFEF4444)),
                    ),
                  ),
                ],
              ),
            );
          },
          child: const Text(
            'Arrêter le partage',
            style: TextStyle(color: Color(0xFFEF4444)),
          ),
        ),
      ],
    );
  }
}
