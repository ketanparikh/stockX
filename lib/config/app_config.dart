/// Supabase project credentials.
///
/// How to get these:
///   1. Go to https://supabase.com → sign in → New project
///   2. Once created: Settings (gear icon) → API
///   3. Copy "Project URL" and "anon / public" key below
///   4. Run the SQL in supabase_schema.sql via Supabase → SQL Editor
///
/// The anon key is safe to include in the app — Supabase Row Level Security
/// controls what each key can access.
class AppConfig {
  // ── Replace these two values ────────────────────────────────────────────
  static const supabaseUrl = 'https://cwwrjhjzrgrhkcgvxbof.supabase.co';
  static const supabaseAnonKey = 'sb_publishable_qSkk1HaV4vOantlzM79wmQ_g_U6y5hi';
  // ────────────────────────────────────────────────────────────────────────

  /// Redirect URL after Google OAuth (must match what you add in Supabase
  /// Auth → URL Configuration → Redirect URLs).
  ///
  /// For local dev: 'http://localhost:8080'
  /// For production: 'https://your-deployed-domain.com'
  static const oauthRedirectUrl = 'http://localhost:8080';

  /// True once the placeholders above have been replaced with real values.
  static bool get isSupabaseConfigured =>
      !supabaseUrl.contains('YOUR_PROJECT_ID') &&
      supabaseAnonKey != 'YOUR_ANON_KEY';
}
