import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import '../models/tournament.dart';
import '../models/shared_tournament_meta.dart';
import '../models/registration.dart';

class FirebaseTournamentService {
  static bool _initialized = false;
  static final _random = Random.secure();

  // --- Lazy Firebase Init ---

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    _initialized = true;
  }

  static Future<String> _ensureAnonymousAuth() async {
    await _ensureInitialized();
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
    return auth.currentUser!.uid;
  }

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  // --- Share Code Generation ---

  static String _generateShareCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No I/O/0/1
    final code =
        List.generate(4, (_) => chars[_random.nextInt(chars.length)]).join();
    return 'PET-$code';
  }

  // --- Organizer: Share Tournament ---

  static Future<String> shareTournament(Tournament tournament) async {
    final uid = await _ensureAnonymousAuth();

    // Generate unique share code
    String code;
    bool exists = true;
    do {
      code = _generateShareCode();
      final doc = await _db.collection('share_codes').doc(code).get();
      exists = doc.exists;
    } while (exists);

    // Set sharing metadata on tournament
    tournament.shareCode = code;
    tournament.isShared = true;
    tournament.organizerId = uid;

    // Write tournament doc
    await _db.collection('tournaments').doc(tournament.id).set({
      ...tournament.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Write share code index
    await _db.collection('share_codes').doc(code).set({
      'code': code,
      'tournamentId': tournament.id,
      'organizerId': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return code;
  }

  // --- Organizer: Push Update ---

  static Future<void> pushTournamentUpdate(Tournament tournament) async {
    if (!tournament.isShared || tournament.shareCode == null) return;
    await _ensureInitialized();

    await _db.collection('tournaments').doc(tournament.id).update({
      ...tournament.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // --- Organizer: Stop Sharing ---

  static Future<void> stopSharing(Tournament tournament) async {
    if (tournament.shareCode == null) return;
    await _ensureInitialized();

    await _db.collection('share_codes').doc(tournament.shareCode!).delete();
    await _db.collection('tournaments').doc(tournament.id).delete();

    tournament.isShared = false;
    tournament.shareCode = null;
    tournament.organizerId = null;
  }

  // --- Viewer: Resolve Share Code ---

  static Future<String?> resolveShareCode(String code) async {
    await _ensureAnonymousAuth();
    final upperCode = code.toUpperCase().trim();

    final doc = await _db.collection('share_codes').doc(upperCode).get();
    if (!doc.exists) return null;
    return doc.data()!['tournamentId'] as String;
  }

  // --- Viewer: Stream Tournament ---

  static Stream<Tournament?> streamTournament(String tournamentId) {
    return _db
        .collection('tournaments')
        .doc(tournamentId)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return Tournament.fromJson(snap.data()!);
    });
  }

  // --- Viewer: Local bookmarks (SharedPreferences) ---

  static const _bookmarksKey = '@petanque/followed_tournaments';

  static Future<List<SharedTournamentMeta>> loadFollowedTournaments() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_bookmarksKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list
        .map((e) =>
            SharedTournamentMeta.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> followTournament(SharedTournamentMeta meta) async {
    final list = await loadFollowedTournaments();
    if (list.any((m) => m.firestoreDocId == meta.firestoreDocId)) return;
    list.insert(0, meta);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _bookmarksKey, jsonEncode(list.map((m) => m.toJson()).toList()));
  }

  static Future<void> unfollowTournament(String docId) async {
    final list = await loadFollowedTournaments();
    list.removeWhere((m) => m.firestoreDocId == docId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _bookmarksKey, jsonEncode(list.map((m) => m.toJson()).toList()));
  }

  // --- Registration: Player submits ---

  static Future<void> submitRegistration(Registration reg) async {
    await _ensureAnonymousAuth();
    await _db.collection('registrations').doc(reg.id).set(reg.toJson());
  }

  static Future<void> cancelRegistration(String regId) async {
    await _ensureInitialized();
    await _db.collection('registrations').doc(regId).delete();
  }

  // --- Registration: Stream ---

  static Stream<List<Registration>> streamRegistrations(String tournamentId) {
    return _db
        .collection('registrations')
        .where('tournamentId', isEqualTo: tournamentId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Registration.fromJson(doc.data()))
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)));
  }

  // --- Registration: Organizer manages ---

  static Future<void> approveRegistration(String regId) async {
    await _ensureInitialized();
    await _db.collection('registrations').doc(regId).update({
      'status': 'approved',
      'reviewedAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> rejectRegistration(String regId) async {
    await _ensureInitialized();
    await _db.collection('registrations').doc(regId).update({
      'status': 'rejected',
      'reviewedAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> deleteRegistration(String regId) async {
    await _ensureInitialized();
    await _db.collection('registrations').doc(regId).delete();
  }

  /// Get current user UID (for registration createdBy field)
  static Future<String> getCurrentUid() async {
    return _ensureAnonymousAuth();
  }
}
