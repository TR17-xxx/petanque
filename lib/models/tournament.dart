class TournamentTeam {
  final String id;
  final String name;
  final List<String> players;
  final String color;

  TournamentTeam({required this.id, required this.name, required this.players, required this.color});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'players': players, 'color': color};

  factory TournamentTeam.fromJson(Map<String, dynamic> json) => TournamentTeam(
    id: json['id'] as String,
    name: json['name'] as String,
    players: List<String>.from(json['players'] as List),
    color: json['color'] as String,
  );
}

class PoolMatch {
  String id;
  String poolId;
  String team1Id;
  String team2Id;
  int? score1;
  int? score2;
  String? winnerId;
  String? playedAt;
  bool isFanny;
  // Championnat mode fields
  int? matchRound;       // 1, 2, or 3 (barrage)
  String? matchType;     // 'initial', 'winners', 'losers', 'barrage'
  String? sourceMatch1Id;
  String? sourceMatch2Id;

  PoolMatch({
    required this.id,
    required this.poolId,
    required this.team1Id,
    required this.team2Id,
    this.score1,
    this.score2,
    this.winnerId,
    this.playedAt,
    this.isFanny = false,
    this.matchRound,
    this.matchType,
    this.sourceMatch1Id,
    this.sourceMatch2Id,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'poolId': poolId, 'team1Id': team1Id, 'team2Id': team2Id,
    'score1': score1, 'score2': score2, 'winnerId': winnerId,
    'playedAt': playedAt, 'isFanny': isFanny,
    if (matchRound != null) 'matchRound': matchRound,
    if (matchType != null) 'matchType': matchType,
    if (sourceMatch1Id != null) 'sourceMatch1Id': sourceMatch1Id,
    if (sourceMatch2Id != null) 'sourceMatch2Id': sourceMatch2Id,
  };

  factory PoolMatch.fromJson(Map<String, dynamic> json) => PoolMatch(
    id: json['id'] as String,
    poolId: json['poolId'] as String,
    team1Id: json['team1Id'] as String? ?? '',
    team2Id: json['team2Id'] as String? ?? '',
    score1: json['score1'] as int?,
    score2: json['score2'] as int?,
    winnerId: json['winnerId'] as String?,
    playedAt: json['playedAt'] as String?,
    isFanny: json['isFanny'] as bool? ?? false,
    matchRound: json['matchRound'] as int?,
    matchType: json['matchType'] as String?,
    sourceMatch1Id: json['sourceMatch1Id'] as String?,
    sourceMatch2Id: json['sourceMatch2Id'] as String?,
  );
}

class PoolStanding {
  String teamId;
  int played;
  int wins;
  int losses;
  int pointsFor;
  int pointsAgainst;
  int diff;
  int rank;
  bool qualified;

  PoolStanding({
    required this.teamId,
    this.played = 0,
    this.wins = 0,
    this.losses = 0,
    this.pointsFor = 0,
    this.pointsAgainst = 0,
    this.diff = 0,
    this.rank = 0,
    this.qualified = false,
  });

  Map<String, dynamic> toJson() => {
    'teamId': teamId, 'played': played, 'wins': wins, 'losses': losses,
    'pointsFor': pointsFor, 'pointsAgainst': pointsAgainst,
    'diff': diff, 'rank': rank, 'qualified': qualified,
  };

  factory PoolStanding.fromJson(Map<String, dynamic> json) => PoolStanding(
    teamId: json['teamId'] as String,
    played: json['played'] as int? ?? 0,
    wins: json['wins'] as int? ?? 0,
    losses: json['losses'] as int? ?? 0,
    pointsFor: json['pointsFor'] as int? ?? 0,
    pointsAgainst: json['pointsAgainst'] as int? ?? 0,
    diff: json['diff'] as int? ?? 0,
    rank: json['rank'] as int? ?? 0,
    qualified: json['qualified'] as bool? ?? false,
  );
}

class Pool {
  String id;
  String name;
  List<String> teamIds;
  List<PoolMatch> matches;
  List<PoolStanding> standings;
  bool completed;

  Pool({
    required this.id,
    required this.name,
    required this.teamIds,
    required this.matches,
    required this.standings,
    this.completed = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'teamIds': teamIds,
    'matches': matches.map((m) => m.toJson()).toList(),
    'standings': standings.map((s) => s.toJson()).toList(),
    'completed': completed,
  };

  factory Pool.fromJson(Map<String, dynamic> json) => Pool(
    id: json['id'] as String,
    name: json['name'] as String,
    teamIds: List<String>.from(json['teamIds'] as List),
    matches: (json['matches'] as List).map((m) => PoolMatch.fromJson(m as Map<String, dynamic>)).toList(),
    standings: (json['standings'] as List).map((s) => PoolStanding.fromJson(s as Map<String, dynamic>)).toList(),
    completed: json['completed'] as bool? ?? false,
  );
}

class BracketMatch {
  String id;
  int round;
  int position;
  String? team1Id;
  String? team2Id;
  int? score1;
  int? score2;
  String? winnerId;
  String? playedAt;
  String? sourceMatch1Id;
  String? sourceMatch2Id;
  bool isThirdPlace;
  bool isFanny;

  BracketMatch({
    required this.id,
    required this.round,
    required this.position,
    this.team1Id,
    this.team2Id,
    this.score1,
    this.score2,
    this.winnerId,
    this.playedAt,
    this.sourceMatch1Id,
    this.sourceMatch2Id,
    this.isThirdPlace = false,
    this.isFanny = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'round': round, 'position': position,
    'team1Id': team1Id, 'team2Id': team2Id,
    'score1': score1, 'score2': score2, 'winnerId': winnerId,
    'playedAt': playedAt,
    'sourceMatch1Id': sourceMatch1Id, 'sourceMatch2Id': sourceMatch2Id,
    'isThirdPlace': isThirdPlace, 'isFanny': isFanny,
  };

  factory BracketMatch.fromJson(Map<String, dynamic> json) => BracketMatch(
    id: json['id'] as String,
    round: json['round'] as int,
    position: json['position'] as int,
    team1Id: json['team1Id'] as String?,
    team2Id: json['team2Id'] as String?,
    score1: json['score1'] as int?,
    score2: json['score2'] as int?,
    winnerId: json['winnerId'] as String?,
    playedAt: json['playedAt'] as String?,
    sourceMatch1Id: json['sourceMatch1Id'] as String?,
    sourceMatch2Id: json['sourceMatch2Id'] as String?,
    isThirdPlace: json['isThirdPlace'] as bool? ?? false,
    isFanny: json['isFanny'] as bool? ?? false,
  );
}

class Tournament {
  String id;
  String name;
  String date;
  String location;
  String gameType; // "triplette" | "doublette" | "tete-a-tete"
  String mode; // "tournoi" | "championnat"
  int targetScore;
  int? bracketTargetScore; // separate score for bracket phase (null = use targetScore)
  List<TournamentTeam> teams;
  List<Pool> pools;
  List<BracketMatch> bracket;
  String phase; // "registration" | "pools" | "bracket" | "finished"
  bool hasThirdPlace;
  String? winnerId;
  String createdAt;
  // Sharing fields
  String? shareCode;    // e.g. "PET-A3K9", null if not shared
  bool isShared;        // true if currently synced to Firestore
  String? organizerId;  // Firebase anonymous UID of the organizer
  // Registration fields
  String registrationType; // "none" | "team" | "individual"
  bool autoApprove;        // auto-approve registrations or manual validation
  int? maxTeams;           // optional max teams limit
  // Pool configuration (stored for registration mode)
  int? poolCount;          // user-chosen pool count (null = auto-calculate)

  Tournament({
    required this.id,
    required this.name,
    required this.date,
    this.location = '',
    required this.gameType,
    this.mode = 'tournoi',
    this.targetScore = 13,
    this.bracketTargetScore,
    required this.teams,
    required this.pools,
    required this.bracket,
    required this.phase,
    this.hasThirdPlace = false,
    this.winnerId,
    required this.createdAt,
    this.shareCode,
    this.isShared = false,
    this.organizerId,
    this.registrationType = 'none',
    this.autoApprove = true,
    this.maxTeams,
    this.poolCount,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'date': date, 'location': location,
    'gameType': gameType, 'mode': mode,
    'targetScore': targetScore,
    if (bracketTargetScore != null) 'bracketTargetScore': bracketTargetScore,
    'teams': teams.map((t) => t.toJson()).toList(),
    'pools': pools.map((p) => p.toJson()).toList(),
    'bracket': bracket.map((b) => b.toJson()).toList(),
    'phase': phase, 'hasThirdPlace': hasThirdPlace,
    'winnerId': winnerId, 'createdAt': createdAt,
    if (shareCode != null) 'shareCode': shareCode,
    'isShared': isShared,
    if (organizerId != null) 'organizerId': organizerId,
    'registrationType': registrationType,
    'autoApprove': autoApprove,
    if (maxTeams != null) 'maxTeams': maxTeams,
    if (poolCount != null) 'poolCount': poolCount,
  };

  factory Tournament.fromJson(Map<String, dynamic> json) => Tournament(
    id: json['id'] as String,
    name: json['name'] as String,
    date: json['date'] as String,
    location: json['location'] as String? ?? '',
    gameType: json['gameType'] as String,
    mode: json['mode'] as String? ?? 'tournoi',
    targetScore: json['targetScore'] as int? ?? 13,
    bracketTargetScore: json['bracketTargetScore'] as int?,
    teams: (json['teams'] as List).map((t) => TournamentTeam.fromJson(t as Map<String, dynamic>)).toList(),
    pools: (json['pools'] as List).map((p) => Pool.fromJson(p as Map<String, dynamic>)).toList(),
    bracket: (json['bracket'] as List).map((b) => BracketMatch.fromJson(b as Map<String, dynamic>)).toList(),
    phase: json['phase'] as String,
    hasThirdPlace: json['hasThirdPlace'] as bool? ?? false,
    winnerId: json['winnerId'] as String?,
    createdAt: json['createdAt'] as String,
    shareCode: json['shareCode'] as String?,
    isShared: json['isShared'] as bool? ?? false,
    organizerId: json['organizerId'] as String?,
    registrationType: json['registrationType'] as String? ?? 'none',
    autoApprove: json['autoApprove'] as bool? ?? true,
    maxTeams: json['maxTeams'] as int?,
    poolCount: json['poolCount'] as int?,
  );
}
