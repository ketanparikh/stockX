import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

// ── Current session user (null = not logged in) ───────────────────────────────

final authProvider = StreamProvider<User?>((ref) {
  if (!AppConfig.isSupabaseConfigured) return Stream.value(null);
  try {
    return Supabase.instance.client.auth.onAuthStateChange
        .map((data) => data.session?.user);
  } catch (_) {
    return Stream.value(null);
  }
});

/// Convenience synchronous read of the current user.
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).valueOrNull;
});

// ── Auth actions ──────────────────────────────────────────────────────────────

class AuthService {
  final SupabaseClient _client;
  AuthService(this._client);

  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signIn(String email, String password) =>
      _client.auth.signInWithPassword(email: email, password: password);

  Future<AuthResponse> signUp(String email, String password) =>
      _client.auth.signUp(email: email, password: password);

  Future<void> signOut() => _client.auth.signOut();

  Future<void> resetPassword(String email) =>
      _client.auth.resetPasswordForEmail(email);

  /// Opens the Google OAuth flow (redirect-based for Flutter Web).
  Future<void> signInWithGoogle() =>
      _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: AppConfig.oauthRedirectUrl,
      );
}

final authServiceProvider = Provider<AuthService?>((ref) {
  if (!AppConfig.isSupabaseConfigured) return null;
  try {
    return AuthService(Supabase.instance.client);
  } catch (_) {
    return null;
  }
});
