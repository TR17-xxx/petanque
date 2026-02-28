import 'dart:math';
import '../models/game.dart';

class DistanceService {
  static MeasureResult? calculateDistances(List<Marker> markers) {
    final cochonnets = markers.where((m) => m.type == 'cochonnet').toList();
    final team1 = markers.where((m) => m.type == 'team1').toList();
    final team2 = markers.where((m) => m.type == 'team2').toList();

    if (cochonnets.isEmpty || team1.isEmpty || team2.isEmpty) return null;

    final coch = cochonnets.first;

    // Distance from boule edge (tangent) to cochonnet center
    double dist(Marker m) {
      final dx = m.x - coch.x;
      final dy = m.y - coch.y;
      final centerDist = sqrt(dx * dx + dy * dy);
      return (centerDist - m.circleRadius).clamp(0.0, double.infinity);
    }

    final allBoules = <_BouleEntry>[];
    for (final m in team1) {
      allBoules.add(_BouleEntry(marker: m, teamId: 1, distance: dist(m)));
    }
    for (final m in team2) {
      allBoules.add(_BouleEntry(marker: m, teamId: 2, distance: dist(m)));
    }

    allBoules.sort((a, b) => a.distance.compareTo(b.distance));

    final distances = <BouleDistance>[];
    for (var i = 0; i < allBoules.length; i++) {
      distances.add(BouleDistance(
        markerId: allBoules[i].marker.id,
        teamId: allBoules[i].teamId,
        distancePixels: allBoules[i].distance,
        rank: i + 1,
      ));
    }

    final closestTeamId = allBoules.first.teamId;
    final bestOpponent = allBoules.firstWhere((b) => b.teamId != closestTeamId).distance;
    int pointsScored = 0;
    for (final b in allBoules) {
      if (b.teamId == closestTeamId && b.distance < bestOpponent) {
        pointsScored++;
      }
    }
    if (pointsScored < 1) pointsScored = 1;

    return MeasureResult(
      mode: 'manual',
      markers: markers,
      distances: distances,
      closestTeamId: closestTeamId,
      pointsScored: pointsScored,
    );
  }
}

class _BouleEntry {
  final Marker marker;
  final int teamId;
  final double distance;

  _BouleEntry({required this.marker, required this.teamId, required this.distance});
}
