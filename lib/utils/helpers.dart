import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String generateId() => _uuid.v4();

String formatGameDate(String isoDate) {
  try {
    final dt = DateTime.parse(isoDate);
    const days = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    final day = days[dt.weekday - 1];
    final month = months[dt.month - 1];
    final hour = dt.hour.toString();
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day ${dt.day} $month — ${hour}h$minute';
  } catch (e) {
    return isoDate;
  }
}
