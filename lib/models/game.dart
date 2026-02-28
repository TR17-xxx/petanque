class Team {
  final int id; // 1 or 2
  final String name;
  final String color;

  Team({required this.id, required this.name, required this.color});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};

  factory Team.fromJson(Map<String, dynamic> json) => Team(
    id: json['id'] as int,
    name: json['name'] as String,
    color: json['color'] as String,
  );
}

class Round {
  final int number;
  final int winnerId;
  final int points;
  final List<int> totalAfter;
  final MeasureResult? measurement;

  Round({
    required this.number,
    required this.winnerId,
    required this.points,
    required this.totalAfter,
    this.measurement,
  });

  Map<String, dynamic> toJson() => {
    'number': number,
    'winnerId': winnerId,
    'points': points,
    'totalAfter': totalAfter,
    if (measurement != null) 'measurement': measurement!.toJson(),
  };

  factory Round.fromJson(Map<String, dynamic> json) => Round(
    number: json['number'] as int,
    winnerId: json['winnerId'] as int,
    points: json['points'] as int,
    totalAfter: List<int>.from(json['totalAfter'] as List),
    measurement: json['measurement'] != null
        ? MeasureResult.fromJson(json['measurement'] as Map<String, dynamic>)
        : null,
  );
}

class Game {
  final String id;
  final Team team1;
  final Team team2;
  final int targetScore;
  final List<Round> rounds;
  final String status; // "playing" | "finished"
  final int? winnerId;
  final String createdAt;

  Game({
    required this.id,
    required this.team1,
    required this.team2,
    this.targetScore = 13,
    required this.rounds,
    required this.status,
    this.winnerId,
    required this.createdAt,
  });

  Game copyWith({
    List<Round>? rounds,
    String? status,
    int? winnerId,
  }) => Game(
    id: id,
    team1: team1,
    team2: team2,
    targetScore: targetScore,
    rounds: rounds ?? this.rounds,
    status: status ?? this.status,
    winnerId: winnerId ?? this.winnerId,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'team1': team1.toJson(),
    'team2': team2.toJson(),
    'targetScore': targetScore,
    'rounds': rounds.map((r) => r.toJson()).toList(),
    'status': status,
    if (winnerId != null) 'winnerId': winnerId,
    'createdAt': createdAt,
  };

  factory Game.fromJson(Map<String, dynamic> json) => Game(
    id: json['id'] as String,
    team1: Team.fromJson(json['team1'] as Map<String, dynamic>),
    team2: Team.fromJson(json['team2'] as Map<String, dynamic>),
    targetScore: json['targetScore'] as int? ?? 13,
    rounds: (json['rounds'] as List).map((r) => Round.fromJson(r as Map<String, dynamic>)).toList(),
    status: json['status'] as String,
    winnerId: json['winnerId'] as int?,
    createdAt: json['createdAt'] as String,
  );
}

class Marker {
  final String id;
  final double x;
  final double y;
  final String type; // "cochonnet" | "team1" | "team2"
  final double circleRadius; // relative radius (0-1), default 0.03

  Marker({
    required this.id,
    required this.x,
    required this.y,
    required this.type,
    this.circleRadius = 0.03,
  });

  Marker copyWith({double? x, double? y, double? circleRadius}) => Marker(
    id: id,
    x: x ?? this.x,
    y: y ?? this.y,
    type: type,
    circleRadius: circleRadius ?? this.circleRadius,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'x': x, 'y': y, 'type': type, 'circleRadius': circleRadius,
  };

  factory Marker.fromJson(Map<String, dynamic> json) => Marker(
    id: json['id'] as String,
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    type: json['type'] as String,
    circleRadius: (json['circleRadius'] as num?)?.toDouble() ?? 0.03,
  );
}

class BouleDistance {
  final String markerId;
  final int teamId;
  final double distancePixels;
  final int rank;

  BouleDistance({
    required this.markerId,
    required this.teamId,
    required this.distancePixels,
    required this.rank,
  });

  Map<String, dynamic> toJson() => {
    'markerId': markerId,
    'teamId': teamId,
    'distancePixels': distancePixels,
    'rank': rank,
  };

  factory BouleDistance.fromJson(Map<String, dynamic> json) => BouleDistance(
    markerId: json['markerId'] as String,
    teamId: json['teamId'] as int,
    distancePixels: (json['distancePixels'] as num).toDouble(),
    rank: json['rank'] as int,
  );
}

class MeasureResult {
  final String mode; // "manual" | "ai"
  final List<Marker>? markers;
  final List<BouleDistance>? distances;
  final int closestTeamId;
  final int pointsScored;
  final String? aiAnalysis;
  final String? photoUri;
  final String? confidence; // "high" | "medium" | "low"

  MeasureResult({
    required this.mode,
    this.markers,
    this.distances,
    required this.closestTeamId,
    required this.pointsScored,
    this.aiAnalysis,
    this.photoUri,
    this.confidence,
  });

  Map<String, dynamic> toJson() => {
    'mode': mode,
    if (markers != null) 'markers': markers!.map((m) => m.toJson()).toList(),
    if (distances != null) 'distances': distances!.map((d) => d.toJson()).toList(),
    'closestTeamId': closestTeamId,
    'pointsScored': pointsScored,
    if (aiAnalysis != null) 'aiAnalysis': aiAnalysis,
    if (photoUri != null) 'photoUri': photoUri,
    if (confidence != null) 'confidence': confidence,
  };

  factory MeasureResult.fromJson(Map<String, dynamic> json) => MeasureResult(
    mode: json['mode'] as String,
    markers: json['markers'] != null
        ? (json['markers'] as List).map((m) => Marker.fromJson(m as Map<String, dynamic>)).toList()
        : null,
    distances: json['distances'] != null
        ? (json['distances'] as List).map((d) => BouleDistance.fromJson(d as Map<String, dynamic>)).toList()
        : null,
    closestTeamId: json['closestTeamId'] as int,
    pointsScored: json['pointsScored'] as int,
    aiAnalysis: json['aiAnalysis'] as String?,
    photoUri: json['photoUri'] as String?,
    confidence: json['confidence'] as String?,
  );
}
