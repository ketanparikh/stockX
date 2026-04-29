import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'models/screener_result.dart';
import 'screens/home_screen.dart';
import 'screens/results_screen.dart';
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

class StockXApp extends StatelessWidget {
  const StockXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'StockX Screener',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _router,
    );
  }
}
