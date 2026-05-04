import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _tab.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final svc = ref.read(authServiceProvider);
    if (svc == null) {
      setState(() => _error = 'Supabase is not configured.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      if (_tab.index == 0) {
        await svc.signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
      } else {
        final res = await svc.signUp(_emailCtrl.text.trim(), _passwordCtrl.text);
        if (res.user != null && res.session == null) {
          if (mounted) {
            _showConfirmDialog();
            return;
          }
        }
      }
    } on Exception catch (e) {
      setState(() => _error = _friendly(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Check your email'),
        content: const Text(
          'A confirmation link has been sent to your email address.\n'
          'Click it to activate your account, then sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _tab.animateTo(0);
            },
            child: const Text('Go to Sign In'),
          ),
        ],
      ),
    );
  }

  String _friendly(String raw) {
    if (raw.contains('Invalid login credentials')) return 'Incorrect email or password.';
    if (raw.contains('Email not confirmed'))       return 'Please confirm your email first.';
    if (raw.contains('User already registered'))   return 'An account with this email already exists.';
    if (raw.contains('Password should be'))        return 'Password must be at least 6 characters.';
    if (raw.contains('Unable to validate'))        return 'Invalid email address.';
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final c      = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Branding ────────────────────────────────────────────────
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.candlestick_chart, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 20),
                Text(
                  'StockX Screener',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Professional NSE Stock Screener',
                  style: TextStyle(color: c.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 36),

                // ── Card ────────────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.border, width: 0.8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 20,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Tabs
                      Container(
                        decoration: BoxDecoration(
                          color: c.surfaceVariant,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16)),
                        ),
                        child: TabBar(
                          controller: _tab,
                          labelColor: scheme.primary,
                          unselectedLabelColor: c.textMuted,
                          labelStyle: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                          unselectedLabelStyle: const TextStyle(fontSize: 14),
                          indicator: BoxDecoration(
                            color: c.card,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(14)),
                          ),
                          tabs: const [
                            Tab(text: 'Sign In'),
                            Tab(text: 'Register'),
                          ],
                        ),
                      ),

                      // Form
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Email
                              TextFormField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                style: TextStyle(color: c.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Email address',
                                  prefixIcon: Icon(Icons.email_outlined,
                                      color: c.textMuted, size: 18),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Email is required';
                                  if (!v.contains('@')) return 'Enter a valid email';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // Password
                              TextFormField(
                                controller: _passwordCtrl,
                                obscureText: _obscure,
                                style: TextStyle(color: c.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(Icons.lock_outline_rounded,
                                      color: c.textMuted, size: 18),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: c.textMuted,
                                      size: 18,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Password is required';
                                  if (_tab.index == 1 && v.length < 6) return 'Min. 6 characters';
                                  return null;
                                },
                              ),

                              // Error
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.bearish.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: AppColors.bearish.withValues(alpha: 0.25)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline,
                                          color: AppColors.bearish, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(_error!,
                                            style: const TextStyle(
                                                color: AppColors.bearish,
                                                fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 20),

                              // Submit button
                              SizedBox(
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _submit,
                                  child: _loading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white),
                                        )
                                      : Text(_tab.index == 0
                                          ? 'Sign In'
                                          : 'Create Account'),
                                ),
                              ),

                              // Forgot password (sign-in tab only)
                              if (_tab.index == 0) ...[
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _loading ? null : _showForgotPassword,
                                  child: Text('Forgot password?',
                                      style: TextStyle(
                                          color: c.textMuted, fontSize: 13)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Text(
                  'Your data is stored securely in Supabase.\nWatchlist syncs across all your devices.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: c.textMuted, fontSize: 11, height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPassword() {
    final ctrl = TextEditingController(text: _emailCtrl.text);
    final c    = context.appColors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        title: Text('Reset Password', style: TextStyle(color: c.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your email and we\'ll send a reset link.',
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: c.textPrimary),
              decoration: const InputDecoration(labelText: 'Email address'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final svc = ref.read(authServiceProvider);
              if (svc != null && ctrl.text.trim().isNotEmpty) {
                await svc.resetPassword(ctrl.text.trim());
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Password reset email sent.')),
                  );
                }
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }
}
