import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:petanque_score/providers/purchase_provider.dart';
import 'package:petanque_score/utils/colors.dart';

/// Affiche le dialog de passage en Pro.
/// Retourne true si l'utilisateur a lancé l'achat.
Future<bool> showUpgradeDialog(BuildContext context) async {
  final purchase = context.read<PurchaseProvider>();
  final price = purchase.proProduct?.price ?? '2,00\u00a0\u20ac';

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
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              LucideIcons.crown,
              size: 22,
              color: Color(0xFFF59E0B),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Passer en Pro',
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
          const Text(
            'Debloquez toutes les fonctionnalites :',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: slate700,
            ),
          ),
          const SizedBox(height: 12),
          _buildFeatureRow(LucideIcons.trophy, 'Tournois & Championnats'),
          const SizedBox(height: 8),
          _buildFeatureRow(LucideIcons.palette, 'Themes personnalises'),
          const SizedBox(height: 16),
          // Badge prix
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Achat unique : $price',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF16A34A),
                ),
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
          onPressed: () async {
            await purchase.buyPro();
            if (ctx.mounted) Navigator.of(ctx).pop(true);
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text(
            'Debloquer',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
      ],
    ),
  );

  return result == true;
}

Widget _buildFeatureRow(IconData icon, String text) {
  return Row(
    children: [
      Icon(icon, size: 18, color: const Color(0xFFF59E0B)),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, color: slate500, height: 1.4),
        ),
      ),
    ],
  );
}

/// Affiche le dialog de remerciement apres un don pastis.
Future<void> showPastisThanksDialog(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              LucideIcons.beer,
              size: 22,
              color: Color(0xFFF59E0B),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Merci !',
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
        'Merci pour le pastis ! Votre soutien aide a ameliorer l\'application.',
        style: TextStyle(fontSize: 13, color: slate500, height: 1.5),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text(
            'Sante !',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
      ],
    ),
  );
}
