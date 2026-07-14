import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/screener_result.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/watchlist_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/results_screen.dart';
import 'screens/stock_search_screen.dart';
import 'screens/stock_detail_screen.dart';
import 'theme/app_theme.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'results',
          builder: (context, state) => const ResultsScreen(),
          routes: [
            GoRoute(
              path: 'detail',
              builder: (context, state) {
                final result = state.extra as ScreenerResult;
                return StockDetailScreen(result: result);
              },
            ),
          ],
        ),
        GoRoute(
          path: 'search',
          builder: (context, state) => const StockSearchScreen(),
        ),
        GoRoute(
          path: 'detail',
          builder: (context, state) {
            final result = state.extra as ScreenerResult;
            return StockDetailScreen(result: result);
          },
        ),
      ],
    ),
  ],
);

class StockXApp extends ConsumerWidget {
  const StockXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authProvider);

    // Common theme wrapper used for both auth and main views
    final theme     = AppTheme.light;
    final darkTheme = AppTheme.dark;

    // While checking session — show a minimal splash
    if (authState.isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final user = authState.valueOrNull;

    // Not signed in → auth screen
    if (user == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        home: const AuthScreen(),
      );
    }

    // Signed in → load watchlist once per login
    ref.listen<AsyncValue<User?>>(authProvider, (prev, next) async {
      final prevUser = prev?.valueOrNull;
      final nextUser = next.valueOrNull;

      if (prevUser == null && nextUser != null) {
        // Just logged in → fetch watchlist from DB
        await ref
            .read(watchlistEntriesProvider.notifier)
            .loadForUser(nextUser.id);
      } else if (prevUser != null && nextUser == null) {
        // Logged out → wipe local state
        ref.read(watchlistEntriesProvider.notifier).clear();
      }
    });

    // Main app
    return MaterialApp.router(
      title: 'StockX Screener',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
