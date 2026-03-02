class SharedTournamentMeta {
  final String firestoreDocId;
  final String shareCode;
  final String name;
  final String joinedAt;

  SharedTournamentMeta({
    required this.firestoreDocId,
    required this.shareCode,
    required this.name,
    required this.joinedAt,
  });

  Map<String, dynamic> toJson() => {
    'firestoreDocId': firestoreDocId,
    'shareCode': shareCode,
    'name': name,
    'joinedAt': joinedAt,
  };

  factory SharedTournamentMeta.fromJson(Map<String, dynamic> json) =>
      SharedTournamentMeta(
        firestoreDocId: json['firestoreDocId'] as String,
        shareCode: json['shareCode'] as String,
        name: json['name'] as String,
        joinedAt: json['joinedAt'] as String,
      );
}
