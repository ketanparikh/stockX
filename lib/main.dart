import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'config/app_config.dart';
import 'providers/sync_provider.dart';
import 'providers/watchlist_provider.dart';
import 'services/cache_service.dart';
import 'utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1A1A2E),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialise local cache (reads last-sync metadata from SharedPreferences)
  final cache = CacheService();
  await cache.init();

  // Try to connect Supabase — silently falls back to local-only mode if
  // app_config.dart has not yet been filled in with real credentials.
  bool supabaseReady = false;
  if (AppConfig.isSupabaseConfigured) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
      supabaseReady = true;
    } catch (e) {
      debugPrint('Supabase init failed: $e');
    }
  } else {
    debugPrint('Supabase not configured — running in local-cache-only mode.');
  }

  // Use an explicit ProviderContainer so we can trigger the auto-load before
  // or shortly after the first frame without needing a widget ref.
  final container = ProviderContainer(
    overrides: [
      cacheServiceProvider.overrideWithValue(cache),
      supabaseReadyProvider.overrideWithValue(supabaseReady),
    ],
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const StockXApp(),
    ),
  );

  // After first frame: auto-load candle data and restore watchlist for any
  // pre-existing Supabase session (user was already logged in).
  if (supabaseReady) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      container.read(syncProvider.notifier).autoLoadIfEmpty(Timeframe.daily);

      // Restore watchlist if a session is already active.
      try {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid != null) {
          container
              .read(watchlistEntriesProvider.notifier)
              .loadForUser(uid);
        }
      } catch (_) {}
    });
  }
}
