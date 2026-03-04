import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:petanque_score/models/registration.dart';
import 'package:petanque_score/utils/colors.dart';

class RegistrationList extends StatelessWidget {
  final List<Registration> registrations;
  final bool isManualApproval;
  final void Function(String regId)? onApprove;
  final void Function(String regId)? onReject;
  final void Function(String regId)? onDelete;
  final void Function(String regId)? onRevoke; // move approved → pending
  final Color themeColor600;

  const RegistrationList({
    super.key,
    required this.registrations,
    this.isManualApproval = false,
    this.onApprove,
    this.onReject,
    this.onDelete,
    this.onRevoke,
    required this.themeColor600,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'pending':
        return const Color(0xFFF59E0B);
      default:
        return slate500;
    }
  }

  Color _statusBgColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFFECFDF5);
      case 'rejected':
        return const Color(0xFFFEF2F2);
      case 'pending':
        return const Color(0xFFFFFBEB);
      default:
        return slate100;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Validé';
      case 'rejected':
        return 'Refusé';
      case 'pending':
        return 'En attente';
      default:
        return status;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'approved':
        return LucideIcons.checkCircle;
      case 'rejected':
        return LucideIcons.xCircle;
      case 'pending':
        return LucideIcons.clock;
      default:
        return LucideIcons.helpCircle;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (registrations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.inbox, size: 48, color: slate200),
            const SizedBox(height: 12),
            const Text(
              'Aucune inscription',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: slate400),
            ),
            const SizedBox(height: 4),
            const Text(
              'Les inscriptions apparaîtront ici',
              style: TextStyle(fontSize: 13, color: slate400),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: registrations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final reg = registrations[index];
        return _buildRegistrationCard(reg);
      },
    );
  }

  Widget _buildRegistrationCard(Registration reg) {
    final teamColor = reg.color.isNotEmpty ? parseHex(reg.color) : slate400;
    final statusCol = _statusColor(reg.status);
    final statusBg = _statusBgColor(reg.status);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: team color + name + status badge
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: teamColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  reg.type == 'team' && reg.teamName.isNotEmpty
                      ? reg.teamName
                      : reg.players.isNotEmpty
                          ? reg.players.first
                          : 'Sans nom',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: slate800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon(reg.status), size: 14, color: statusCol),
                    const SizedBox(width: 4),
                    Text(
                      _statusLabel(reg.status),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusCol),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Players list
          if (reg.players.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: reg.players.map((p) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.user, size: 13, color: slate400),
                  const SizedBox(width: 4),
                  Text(p, style: const TextStyle(fontSize: 13, color: slate500)),
                ],
              )).toList(),
            ),
          ],

          // Action buttons for pending registrations (always shown)
          if (reg.status == 'pending') ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildActionButton(
                  icon: LucideIcons.xCircle,
                  label: 'Refuser',
                  color: const Color(0xFFEF4444),
                  bgColor: const Color(0xFFFEF2F2),
                  onTap: () => onReject?.call(reg.id),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: LucideIcons.checkCircle,
                  label: 'Valider',
                  color: const Color(0xFF10B981),
                  bgColor: const Color(0xFFECFDF5),
                  onTap: () => onApprove?.call(reg.id),
                ),
              ],
            ),
          ],

          // Actions for approved registrations
          if (reg.status == 'approved') ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onRevoke != null)
                  _buildActionButton(
                    icon: LucideIcons.undo2,
                    label: 'En attente',
                    color: const Color(0xFFF59E0B),
                    bgColor: const Color(0xFFFFFBEB),
                    onTap: () => onRevoke?.call(reg.id),
                  ),
                if (onRevoke != null && onDelete != null)
                  const SizedBox(width: 8),
                if (onDelete != null)
                  _buildActionButton(
                    icon: LucideIcons.trash2,
                    label: 'Supprimer',
                    color: const Color(0xFFEF4444),
                    bgColor: const Color(0xFFFEF2F2),
                    onTap: () => onDelete?.call(reg.id),
                  ),
              ],
            ),
          ],

          // Delete button for rejected
          if (reg.status == 'rejected' && onDelete != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildActionButton(
                  icon: LucideIcons.trash2,
                  label: 'Supprimer',
                  color: slate500,
                  bgColor: slate50,
                  onTap: () => onDelete?.call(reg.id),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}
