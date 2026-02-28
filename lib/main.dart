import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/game_screen.dart';
import 'screens/measure_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/help_screen.dart';
import 'screens/tournament_list_screen.dart';
import 'screens/tournament_create_screen.dart';
import 'screens/tournament_dashboard_screen.dart';
import 'screens/tournament_bracket_screen.dart';
import 'screens/tournament_match_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const PetanqueApp(),
    ),
  );
}

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/setup', builder: (_, __) => const SetupScreen()),
    GoRoute(
      path: '/game/:id',
      builder: (_, state) => GameScreen(gameId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/measure',
      builder: (_, state) => MeasureScreen(
        gameId: state.uri.queryParameters['gameId'],
      ),
    ),
    GoRoute(
      path: '/history',
      builder: (_, state) => HistoryScreen(
        gameId: state.uri.queryParameters['gameId'],
        isActive: state.uri.queryParameters['active'] == 'true',
      ),
    ),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    GoRoute(path: '/help', builder: (_, __) => const HelpScreen()),
    GoRoute(path: '/tournament', builder: (_, __) => const TournamentListScreen(modeFilter: 'tournoi')),
    GoRoute(path: '/championnat', builder: (_, __) => const TournamentListScreen(modeFilter: 'championnat')),
    GoRoute(
      path: '/tournament/create',
      builder: (_, state) => TournamentCreateScreen(
        initialMode: state.uri.queryParameters['mode'],
      ),
    ),
    GoRoute(
      path: '/tournament/:id',
      builder: (_, state) => TournamentDashboardScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/tournament/bracket/:id',
      builder: (_, state) => TournamentBracketScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/tournament/match/:matchId',
      builder: (_, state) => TournamentMatchScreen(
        matchId: state.pathParameters['matchId']!,
        tournamentId: state.uri.queryParameters['tournamentId']!,
      ),
    ),
  ],
);

class PetanqueApp extends StatelessWidget {
  const PetanqueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pétanque Score',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
