import 'dart:math';
import '../models/tournament.dart';
import 'helpers.dart';

// --- Génération des poules ---

List<Pool> generatePools(List<TournamentTeam> teams, {int teamsPerPool = 4, int? poolCount}) {
  final nbPools = poolCount ?? (teams.length / teamsPerPool).ceil();
  final pools = <Pool>[];

  for (var i = 0; i < nbPools; i++) {
    pools.add(Pool(
      id: generateId(),
      name: 'Poule ${String.fromCharCode(65 + i)}',
      teamIds: [],
      matches: [],
      standings: [],
    ));
  }

  // Distribution serpentine
  for (var index = 0; index < teams.length; index++) {
    final cycle = index ~/ nbPools;
    final pos = index % nbPools;
    final poolIndex = cycle % 2 == 0 ? pos : nbPools - 1 - pos;
    pools[poolIndex].teamIds.add(teams[index].id);
  }

  // Round-robin par poule
  for (final pool in pools) {
    pool.matches = _generateRoundRobinMatches(pool.id, pool.teamIds);
    pool.standings = _initStandings(pool.teamIds);
  }

  return pools;
}

List<PoolMatch> _generateRoundRobinMatches(String poolId, List<String> teamIds) {
  final matches = <PoolMatch>[];
  for (var i = 0; i < teamIds.length; i++) {
    for (var j = i + 1; j < teamIds.length; j++) {
      matches.add(PoolMatch(
        id: generateId(),
        poolId: poolId,
        team1Id: teamIds[i],
        team2Id: teamIds[j],
      ));
    }
  }
  return matches;
}

List<PoolStanding> _initStandings(List<String> teamIds) {
  return teamIds.asMap().entries.map((e) => PoolStanding(
    teamId: e.value,
    rank: e.key + 1,
  )).toList();
}

// --- Classement poule ---

List<PoolStanding> calculatePoolStandings(Pool pool, {int qualifiedCount = 2}) {
  final map = <String, PoolStanding>{};

  for (final teamId in pool.teamIds) {
    map[teamId] = PoolStanding(teamId: teamId);
  }

  for (final match in pool.matches) {
    if (match.score1 == null || match.score2 == null) continue;

    final s1 = map[match.team1Id]!;
    final s2 = map[match.team2Id]!;

    s1.played++;
    s2.played++;
    s1.pointsFor += match.score1!;
    s1.pointsAgainst += match.score2!;
    s2.pointsFor += match.score2!;
    s2.pointsAgainst += match.score1!;

    if (match.winnerId == match.team1Id) {
      s1.wins++;
      s2.losses++;
    } else {
      s2.wins++;
      s1.losses++;
    }
  }

  final standings = map.values.toList();
  for (final s in standings) {
    s.diff = s.pointsFor - s.pointsAgainst;
  }

  standings.sort((a, b) {
    if (b.wins != a.wins) return b.wins - a.wins;
    if (b.diff != a.diff) return b.diff - a.diff;
    return b.pointsFor - a.pointsFor;
  });

  for (var i = 0; i < standings.length; i++) {
    standings[i].rank = i + 1;
    standings[i].qualified = i < qualifiedCount;
  }

  return standings;
}

bool isPoolComplete(Pool pool) {
  return pool.matches.every((m) => m.score1 != null && m.score2 != null);
}

// --- Mode Championnat (format FFPJP) ---

List<Pool> generateChampionnatPools(List<TournamentTeam> teams, {int teamsPerPool = 4, int? poolCount, int targetScore = 11}) {
  final nbPools = poolCount ?? (teams.length / teamsPerPool).ceil();
  final pools = <Pool>[];

  for (var i = 0; i < nbPools; i++) {
    pools.add(Pool(
      id: generateId(),
      name: 'Poule ${String.fromCharCode(65 + i)}',
      teamIds: [],
      matches: [],
      standings: [],
    ));
  }

  // Distribution serpentine (même logique que tournoi)
  for (var index = 0; index < teams.length; index++) {
    final cycle = index ~/ nbPools;
    final pos = index % nbPools;
    final poolIndex = cycle % 2 == 0 ? pos : nbPools - 1 - pos;
    pools[poolIndex].teamIds.add(teams[index].id);
  }

  // Matchs format championnat par poule
  for (final pool in pools) {
    pool.matches = _generateChampionnatMatches(pool.id, pool.teamIds, targetScore);
    pool.standings = _initStandings(pool.teamIds);
  }

  return pools;
}

List<PoolMatch> _generateChampionnatMatches(String poolId, List<String> teamIds, int targetScore) {
  final matches = <PoolMatch>[];

  if (teamIds.length < 2) return matches;

  if (teamIds.length == 2) {
    // Seulement 2 équipes : un seul match
    matches.add(PoolMatch(
      id: generateId(),
      poolId: poolId,
      team1Id: teamIds[0],
      team2Id: teamIds[1],
      matchRound: 1,
      matchType: 'initial',
    ));
    return matches;
  }

  // Poule de 3 : une équipe a un bye au Tour 1
  // Poule de 4 : standard
  final hasbye = teamIds.length == 3;

  // Tour 1 — Match 1 : team[0] vs team[1]
  final m1 = PoolMatch(
    id: generateId(),
    poolId: poolId,
    team1Id: teamIds[0],
    team2Id: teamIds[1],
    matchRound: 1,
    matchType: 'initial',
  );
  matches.add(m1);

  // Tour 1 — Match 2 : team[2] vs team[3], ou bye si 3 équipes
  final PoolMatch m2;
  if (hasbye) {
    m2 = PoolMatch(
      id: generateId(),
      poolId: poolId,
      team1Id: teamIds[2],
      team2Id: '',
      matchRound: 1,
      matchType: 'initial',
      // Bye auto-gagné
      score1: targetScore,
      score2: 0,
      winnerId: teamIds[2],
    );
  } else {
    m2 = PoolMatch(
      id: generateId(),
      poolId: poolId,
      team1Id: teamIds[2],
      team2Id: teamIds[3],
      matchRound: 1,
      matchType: 'initial',
    );
  }
  matches.add(m2);

  // Tour 2 — Gagnants : Winner(M1) vs Winner(M2)
  final m3 = PoolMatch(
    id: generateId(),
    poolId: poolId,
    team1Id: '',
    team2Id: '',
    matchRound: 2,
    matchType: 'winners',
    sourceMatch1Id: m1.id,
    sourceMatch2Id: m2.id,
  );
  matches.add(m3);

  // Tour 2 — Perdants : Loser(M1) vs Loser(M2)
  final m4 = PoolMatch(
    id: generateId(),
    poolId: poolId,
    team1Id: '',
    team2Id: '',
    matchRound: 2,
    matchType: 'losers',
    sourceMatch1Id: m1.id,
    sourceMatch2Id: m2.id,
  );
  matches.add(m4);

  // Barrage : Loser(M3=gagnants) vs Winner(M4=perdants)
  final m5 = PoolMatch(
    id: generateId(),
    poolId: poolId,
    team1Id: '',
    team2Id: '',
    matchRound: 3,
    matchType: 'barrage',
    sourceMatch1Id: m3.id,
    sourceMatch2Id: m4.id,
  );
  matches.add(m5);

  // Si bye au Tour 1, propager immédiatement le gagnant du bye
  if (hasbye && m2.winnerId != null) {
    _propagateChampionnatResult(matches, m2.id, m2.winnerId!, '');
    _autoCompleteByes(matches);
  }

  return matches;
}

void propagateChampionnatPoolWinner(Pool pool, String matchId, String winnerId, String loserId) {
  _propagateChampionnatResult(pool.matches, matchId, winnerId, loserId);
  _autoCompleteByes(pool.matches);
}

void _propagateChampionnatResult(List<PoolMatch> matches, String matchId, String winnerId, String loserId) {
  final source = matches.where((m) => m.id == matchId).firstOrNull;
  if (source == null) return;

  for (final m in matches) {
    if (m.sourceMatch1Id == matchId || m.sourceMatch2Id == matchId) {
      final isSource1 = m.sourceMatch1Id == matchId;

      if (m.matchType == 'winners') {
        // Le match des gagnants reçoit les gagnants
        if (isSource1) {
          m.team1Id = winnerId;
        } else {
          m.team2Id = winnerId;
        }
      } else if (m.matchType == 'losers') {
        // Le match des perdants reçoit les perdants
        if (isSource1) {
          m.team1Id = loserId;
        } else {
          m.team2Id = loserId;
        }
      } else if (m.matchType == 'barrage') {
        // Le barrage : perdant du match gagnants (source1) vs gagnant du match perdants (source2)
        if (isSource1) {
          m.team1Id = loserId; // Perdant du match des gagnants
        } else {
          m.team2Id = winnerId; // Gagnant du match des perdants
        }
      }
    }
  }
}

/// Auto-complète les matchs où un seul adversaire est présent (bye).
/// Cela arrive dans les poules de 3 : le perdant du bye est '' (vide),
/// donc le match des perdants a un seul vrai adversaire.
void _autoCompleteByes(List<PoolMatch> matches) {
  bool changed = true;
  while (changed) {
    changed = false;
    for (final m in matches) {
      if (m.winnerId != null) continue;
      if (m.matchType == 'initial') continue;

      // Vérifier que les deux sources sont terminées
      bool sourcesComplete = true;
      if (m.sourceMatch1Id != null) {
        final src = matches.where((x) => x.id == m.sourceMatch1Id).firstOrNull;
        if (src == null || src.winnerId == null) sourcesComplete = false;
      }
      if (m.sourceMatch2Id != null) {
        final src = matches.where((x) => x.id == m.sourceMatch2Id).firstOrNull;
        if (src == null || src.winnerId == null) sourcesComplete = false;
      }
      if (!sourcesComplete) continue;

      // Une équipe présente, l'autre absente (bye) → victoire par forfait
      if (m.team1Id.isNotEmpty && m.team2Id.isEmpty) {
        m.winnerId = m.team1Id;
        m.score1 = 13;
        m.score2 = 0;
        _propagateChampionnatResult(matches, m.id, m.winnerId!, '');
        changed = true;
        break;
      } else if (m.team1Id.isEmpty && m.team2Id.isNotEmpty) {
        m.winnerId = m.team2Id;
        m.score1 = 0;
        m.score2 = 13;
        _propagateChampionnatResult(matches, m.id, m.winnerId!, '');
        changed = true;
        break;
      }
    }
  }
}

List<String> getChampionnatQualifiedTeamIds(Pool pool) {
  final qualified = <String>[];
  for (final m in pool.matches) {
    if (m.matchType == 'winners' && m.winnerId != null && m.winnerId!.isNotEmpty) {
      qualified.add(m.winnerId!);
    }
    if (m.matchType == 'barrage' && m.winnerId != null && m.winnerId!.isNotEmpty) {
      qualified.add(m.winnerId!);
    }
  }
  // Si poule de 2, le gagnant du seul match initial qualifie
  if (qualified.isEmpty) {
    final initial = pool.matches.where((m) => m.matchType == 'initial').toList();
    if (initial.length == 1 && initial[0].winnerId != null) {
      qualified.add(initial[0].winnerId!);
    }
  }
  return qualified;
}

bool isChampionnatMatchPlayable(PoolMatch match, Pool pool) {
  if (match.matchRound == null || match.matchRound == 1) return true;
  if (match.sourceMatch1Id != null) {
    final src = pool.matches.where((m) => m.id == match.sourceMatch1Id).firstOrNull;
    if (src == null || src.winnerId == null) return false;
  }
  if (match.sourceMatch2Id != null) {
    final src = pool.matches.where((m) => m.id == match.sourceMatch2Id).firstOrNull;
    if (src == null || src.winnerId == null) return false;
  }
  return match.team1Id.isNotEmpty && match.team2Id.isNotEmpty;
}

bool isChampionnatPoolComplete(Pool pool) {
  // Poule de 2 : un seul match initial
  if (pool.teamIds.length <= 2) {
    return pool.matches.every((m) => m.winnerId != null);
  }
  final winnersMatch = pool.matches.where((m) => m.matchType == 'winners').firstOrNull;
  final barrageMatch = pool.matches.where((m) => m.matchType == 'barrage').firstOrNull;
  return winnersMatch?.winnerId != null && barrageMatch?.winnerId != null;
}

List<PoolStanding> calculateChampionnatStandings(Pool pool) {
  final map = <String, PoolStanding>{};
  for (final teamId in pool.teamIds) {
    map[teamId] = PoolStanding(teamId: teamId);
  }

  // Calculer stats depuis les matchs joués
  for (final match in pool.matches) {
    if (match.score1 == null || match.score2 == null) continue;
    if (match.team1Id.isEmpty || match.team2Id.isEmpty) continue;

    final s1 = map[match.team1Id];
    final s2 = map[match.team2Id];
    if (s1 == null || s2 == null) continue;

    s1.played++;
    s2.played++;
    s1.pointsFor += match.score1!;
    s1.pointsAgainst += match.score2!;
    s2.pointsFor += match.score2!;
    s2.pointsAgainst += match.score1!;

    if (match.winnerId == match.team1Id) {
      s1.wins++;
      s2.losses++;
    } else if (match.winnerId == match.team2Id) {
      s2.wins++;
      s1.losses++;
    }
  }

  for (final s in map.values) {
    s.diff = s.pointsFor - s.pointsAgainst;
  }

  // Rang basé sur les résultats des matchs éliminatoires
  final qualifiedIds = getChampionnatQualifiedTeamIds(pool);
  final winnersMatch = pool.matches.where((m) => m.matchType == 'winners').firstOrNull;
  final barrageMatch = pool.matches.where((m) => m.matchType == 'barrage').firstOrNull;
  final losersMatch = pool.matches.where((m) => m.matchType == 'losers').firstOrNull;

  // Rang 1 : gagnant du match gagnants
  // Rang 2 : gagnant du barrage
  // Rang 3 : perdant du barrage
  // Rang 4 : perdant du match perdants
  final ranked = <String>[];
  if (winnersMatch?.winnerId != null && winnersMatch!.winnerId!.isNotEmpty) ranked.add(winnersMatch.winnerId!);
  if (barrageMatch?.winnerId != null && barrageMatch!.winnerId!.isNotEmpty) ranked.add(barrageMatch.winnerId!);
  // Perdant du barrage
  if (barrageMatch?.winnerId != null && barrageMatch!.team1Id.isNotEmpty && barrageMatch.team2Id.isNotEmpty) {
    final loser = barrageMatch.team1Id == barrageMatch.winnerId ? barrageMatch.team2Id : barrageMatch.team1Id;
    if (loser.isNotEmpty && !ranked.contains(loser)) ranked.add(loser);
  }
  // Perdant du match perdants
  if (losersMatch?.winnerId != null && losersMatch!.team1Id.isNotEmpty && losersMatch.team2Id.isNotEmpty) {
    final loser = losersMatch.team1Id == losersMatch.winnerId ? losersMatch.team2Id : losersMatch.team1Id;
    if (loser.isNotEmpty && !ranked.contains(loser)) ranked.add(loser);
  }

  // Assigner les rangs
  final standings = map.values.toList();
  for (final s in standings) {
    final idx = ranked.indexOf(s.teamId);
    s.rank = idx >= 0 ? idx + 1 : pool.teamIds.length;
    s.qualified = qualifiedIds.contains(s.teamId);
  }
  standings.sort((a, b) => a.rank - b.rank);

  return standings;
}

String getChampionnatMatchLabel(PoolMatch match) {
  switch (match.matchType) {
    case 'initial': return 'Tour 1';
    case 'winners': return 'Gagnants';
    case 'losers': return 'Perdants';
    case 'barrage': return 'Barrage';
    default: return '';
  }
}

// --- Bracket squelette ---

List<BracketMatch> generateSkeletonBracket(int nbPools, int qualifiedPerPool, bool hasThirdPlace) {
  final nbTeams = nbPools * qualifiedPerPool;
  if (nbTeams < 2) return [];

  final bracketSize = pow(2, (log(nbTeams) / log(2)).ceil()).toInt();
  final nbRounds = (log(bracketSize) / log(2)).round();

  final matches = <BracketMatch>[];

  // Round 0
  for (var i = 0; i < bracketSize ~/ 2; i++) {
    matches.add(BracketMatch(id: generateId(), round: 0, position: i));
  }

  // Rounds suivants
  for (var round = 1; round < nbRounds; round++) {
    final prev = matches.where((m) => m.round == round - 1 && !m.isThirdPlace).toList();
    for (var pos = 0; pos < prev.length ~/ 2; pos++) {
      matches.add(BracketMatch(
        id: generateId(),
        round: round,
        position: pos,
        sourceMatch1Id: prev[pos * 2].id,
        sourceMatch2Id: prev[pos * 2 + 1].id,
      ));
    }
  }

  // Match 3ème place
  if (hasThirdPlace && nbRounds >= 2) {
    final semis = matches.where((m) => m.round == nbRounds - 2 && !m.isThirdPlace).toList();
    if (semis.length == 2) {
      matches.add(BracketMatch(
        id: generateId(),
        round: nbRounds - 1,
        position: 1,
        sourceMatch1Id: semis[0].id,
        sourceMatch2Id: semis[1].id,
        isThirdPlace: true,
      ));
    }
  }

  return matches;
}

// --- Remplir le bracket ---

List<BracketMatch> populateBracketFromPools(List<BracketMatch> bracket, List<Pool> pools) {
  final updated = bracket.map((m) => BracketMatch.fromJson(m.toJson())).toList();

  final qualified = <_QualifiedTeam>[];
  for (var poolIndex = 0; poolIndex < pools.length; poolIndex++) {
    for (final s in pools[poolIndex].standings.where((s) => s.qualified)) {
      qualified.add(_QualifiedTeam(teamId: s.teamId, poolIndex: poolIndex, rank: s.rank));
    }
  }

  final pairs = _createCrossedPairs(qualified, pools.length);

  final round0 = updated.where((m) => m.round == 0 && !m.isThirdPlace).toList()
    ..sort((a, b) => a.position - b.position);

  for (var i = 0; i < round0.length && i < pairs.length; i++) {
    if (round0[i].score1 != null) continue;
    round0[i].team1Id = pairs[i].team1Id;
    round0[i].team2Id = pairs[i].team2Id;
  }

  // Propager byes
  for (final match in updated) {
    if (match.round == 0 && match.winnerId == null) {
      if (match.team1Id != null && match.team2Id == null) {
        match.winnerId = match.team1Id;
        match.score1 = 13;
        match.score2 = 0;
        _propagateWinnerInternal(updated, match.id, match.winnerId!);
      } else if (match.team1Id == null && match.team2Id != null) {
        match.winnerId = match.team2Id;
        match.score1 = 0;
        match.score2 = 13;
        _propagateWinnerInternal(updated, match.id, match.winnerId!);
      }
    }
  }

  return updated;
}

List<BracketMatch> generateBracket(List<Pool> pools, bool hasThirdPlace) {
  final qualifiedPerPool = getQualifiedPerPool(pools);
  final skeleton = generateSkeletonBracket(pools.length, qualifiedPerPool, hasThirdPlace);
  return populateBracketFromPools(skeleton, pools);
}

List<_Pair> _createCrossedPairs(List<_QualifiedTeam> qualified, int nbPools) {
  if (nbPools == 1) {
    final sorted = [...qualified]..sort((a, b) => a.rank - b.rank);
    final pairs = <_Pair>[];
    var lo = 0;
    var hi = sorted.length - 1;
    while (lo < hi) {
      pairs.add(_Pair(team1Id: sorted[lo].teamId, team2Id: sorted[hi].teamId));
      lo++;
      hi--;
    }
    if (lo == hi) {
      pairs.add(_Pair(team1Id: sorted[lo].teamId, team2Id: null));
    }
    return pairs;
  }

  final firsts = qualified.where((q) => q.rank == 1).toList()..sort((a, b) => a.poolIndex - b.poolIndex);
  final seconds = qualified.where((q) => q.rank == 2).toList()..sort((a, b) => a.poolIndex - b.poolIndex);

  final pairs = <_Pair>[];
  for (var i = 0; i < firsts.length; i++) {
    final crossIndex = (i + 1) % seconds.length;
    final opponent = crossIndex < seconds.length ? seconds[crossIndex] : null;
    pairs.add(_Pair(team1Id: firsts[i].teamId, team2Id: opponent?.teamId));
  }

  final usedSeconds = pairs.map((p) => p.team2Id).toSet();
  final remaining = seconds.where((s) => !usedSeconds.contains(s.teamId));
  for (final r in remaining) {
    pairs.add(_Pair(team1Id: r.teamId, team2Id: null));
  }

  return pairs;
}

void _propagateWinnerInternal(List<BracketMatch> matches, String matchId, String winnerId) {
  final nextMatch = matches.where((m) =>
    !m.isThirdPlace && (m.sourceMatch1Id == matchId || m.sourceMatch2Id == matchId)
  ).firstOrNull;

  if (nextMatch != null) {
    if (nextMatch.sourceMatch1Id == matchId) {
      nextMatch.team1Id = winnerId;
    } else {
      nextMatch.team2Id = winnerId;
    }
  }
}

// --- Propagation gagnant (après saisie score bracket) ---

List<BracketMatch> propagateWinner(List<BracketMatch> bracket, String matchId, String winnerId, String loserId) {
  final updated = bracket.map((m) => BracketMatch.fromJson(m.toJson())).toList();

  final nextMatch = updated.where((m) =>
    !m.isThirdPlace && (m.sourceMatch1Id == matchId || m.sourceMatch2Id == matchId)
  ).firstOrNull;

  if (nextMatch != null) {
    if (nextMatch.sourceMatch1Id == matchId) {
      nextMatch.team1Id = winnerId;
    } else {
      nextMatch.team2Id = winnerId;
    }
  }

  final thirdPlaceMatch = updated.where((m) =>
    m.isThirdPlace && (m.sourceMatch1Id == matchId || m.sourceMatch2Id == matchId)
  ).firstOrNull;

  if (thirdPlaceMatch != null) {
    if (thirdPlaceMatch.sourceMatch1Id == matchId) {
      thirdPlaceMatch.team1Id = loserId;
    } else {
      thirdPlaceMatch.team2Id = loserId;
    }
  }

  return updated;
}

// --- Utilitaires ---

String getRoundLabel(int round, int totalRounds) {
  final fromEnd = totalRounds - 1 - round;
  switch (fromEnd) {
    case 0: return 'Finale';
    case 1: return 'Demi-finales';
    case 2: return 'Quarts de finale';
    default: return 'Tour ${round + 1}';
  }
}

String getMatchLabel(BracketMatch match, int totalRounds, List<Pool> pools) {
  if (match.isThirdPlace) return 'Match 3ème place';
  return getRoundLabel(match.round, totalRounds);
}

int getQualifiedPerPool(List<Pool> pools) {
  if (pools.length == 1) return pools[0].teamIds.length;
  return 2;
}

bool isBracketComplete(List<BracketMatch> bracket) {
  if (bracket.isEmpty) return false;
  final nonThirdPlace = bracket.where((b) => !b.isThirdPlace);
  final maxRound = nonThirdPlace.map((b) => b.round).reduce(max);
  final finale = nonThirdPlace.where((m) => m.round == maxRound).firstOrNull;
  return finale?.winnerId != null;
}

// --- Classes privées ---

class _QualifiedTeam {
  final String teamId;
  final int poolIndex;
  final int rank;
  _QualifiedTeam({required this.teamId, required this.poolIndex, required this.rank});
}

class _Pair {
  final String? team1Id;
  final String? team2Id;
  _Pair({this.team1Id, this.team2Id});
}
