class Registration {
  String id;
  String tournamentId;
  String type; // "team" | "individual"
  String teamName; // nom d'équipe (vide si individuel)
  List<String> players; // noms des joueurs
  String color; // couleur d'équipe choisie
  String status; // "pending" | "approved" | "rejected"
  String createdAt;
  String? reviewedAt;
  String createdBy; // Firebase UID du joueur qui s'inscrit
  String organizerId; // Firebase UID de l'organisateur du tournoi

  Registration({
    required this.id,
    required this.tournamentId,
    required this.type,
    this.teamName = '',
    required this.players,
    this.color = '',
    this.status = 'pending',
    required this.createdAt,
    this.reviewedAt,
    required this.createdBy,
    required this.organizerId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'tournamentId': tournamentId,
    'type': type,
    'teamName': teamName,
    'players': players,
    'color': color,
    'status': status,
    'createdAt': createdAt,
    if (reviewedAt != null) 'reviewedAt': reviewedAt,
    'createdBy': createdBy,
    'organizerId': organizerId,
  };

  factory Registration.fromJson(Map<String, dynamic> json) => Registration(
    id: json['id'] as String,
    tournamentId: json['tournamentId'] as String,
    type: json['type'] as String,
    teamName: json['teamName'] as String? ?? '',
    players: List<String>.from(json['players'] as List? ?? []),
    color: json['color'] as String? ?? '',
    status: json['status'] as String? ?? 'pending',
    createdAt: json['createdAt'] as String,
    reviewedAt: json['reviewedAt'] as String?,
    createdBy: json['createdBy'] as String? ?? '',
    organizerId: json['organizerId'] as String? ?? '',
  );
}
