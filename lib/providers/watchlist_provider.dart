import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WatchlistNotifier extends StateNotifier<Set<String>> {
  static const _key = 'watchlist';

  WatchlistNotifier() : super(const {}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    state = list.toSet();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state.toList());
  }

  void toggle(String symbol) {
    if (state.contains(symbol)) {
      state = {...state}..remove(symbol);
    } else {
      state = {...state, symbol};
    }
    _save();
  }

  bool isWatched(String symbol) => state.contains(symbol);

  void remove(String symbol) {
    state = {...state}..remove(symbol);
    _save();
  }

  void add(String symbol) {
    state = {...state, symbol};
    _save();
  }
}

final watchlistProvider =
    StateNotifierProvider<WatchlistNotifier, Set<String>>(
  (ref) => WatchlistNotifier(),
);
