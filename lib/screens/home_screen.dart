import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../providers/alert_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import 'screener_screen.dart';
import 'sync_screen.dart';
import 'watchlist_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final _screens = const [
    ScreenerScreen(),
    WatchlistScreen(),
    SyncScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider.notifier).isDark;
    final scheme = Theme.of(context).colorScheme;
    final c = context.appColors;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.card,
          border: Border(top: BorderSide(color: c.border, width: 0.5)),
          boxShadow: isDark
              ? const []
              : const [BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, -2))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: scheme.primary,
          unselectedItemColor: c.textMuted,
          selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          type: BottomNavigationBarType.fixed,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.candlestick_chart_outlined),
              activeIcon: Icon(Icons.candlestick_chart),
              label: 'Screener',
            ),
            BottomNavigationBarItem(
              icon: _WatchlistTabIcon(active: false),
              activeIcon: _WatchlistTabIcon(active: true),
              label: 'Watchlist',
            ),
            BottomNavigationBarItem(
              icon: _SyncTabIcon(active: false),
              activeIcon: _SyncTabIcon(active: true),
              label: 'Data Sync',
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sign out button (only when Supabase is configured)
          if (AppConfig.isSupabaseConfigured) ...[
            FloatingActionButton.small(
              heroTag: 'signOut',
              onPressed: () => _confirmSignOut(context),
              backgroundColor: c.card,
              foregroundColor: c.textMuted,
              tooltip: 'Sign Out',
              child: const Icon(Icons.logout_rounded, size: 18),
            ),
            const SizedBox(height: 8),
          ],
          // Theme toggle
          FloatingActionButton.small(
            heroTag: 'theme',
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
            backgroundColor: scheme.primary,
            foregroundColor: Colors.white,
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            child: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext ctx) {
    final c = ctx.appColors;
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        backgroundColor: c.card,
        title: Text('Sign Out', style: TextStyle(color: c.textPrimary)),
        content: Text(
          'Your watchlist is saved in the cloud.\nSign back in any time to restore it.',
          style: TextStyle(color: c.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dCtx);
              final svc = ref.read(authServiceProvider);
              await svc?.signOut();
            },
            child: Text('Sign Out', style: TextStyle(color: AppColors.bearish)),
          ),
        ],
      ),
    );
  }
}

// ── Watchlist tab — badge when alerts exist ───────────────────────────────────

class _WatchlistTabIcon extends ConsumerWidget {
  final bool active;
  const _WatchlistTabIcon({required this.active});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertCount = ref.watch(alertProvider.select((s) => s.count));
    final icon = active ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded;
    if (alertCount > 0) {
      return Badge(
        label: Text('$alertCount'),
        backgroundColor: AppColors.bearish,
        child: Icon(icon),
      );
    }
    return Icon(icon);
  }
}

// ── Sync tab — spinning while syncing, badge showing cached count ─────────────

class _SyncTabIcon extends ConsumerWidget {
  final bool active;
  const _SyncTabIcon({required this.active});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRunning = ref.watch(syncProvider.select((s) => s.isRunning));

    if (isRunning) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: active
              ? Theme.of(context).colorScheme.primary
              : context.appColors.textMuted,
        ),
      );
    }

    final cacheCount = ref.watch(cacheServiceProvider.select((c) => c.count));
    final icon = active ? Icons.cloud_rounded : Icons.cloud_outlined;

    if (cacheCount > 0 && !active) {
      return Badge(
        label: Text('$cacheCount'),
        child: Icon(icon),
      );
    }
    return Icon(icon);
  }
}
