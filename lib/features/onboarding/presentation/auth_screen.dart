import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/widgets/common.dart';

enum _AuthMode { signIn, signUp, reset }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  _AuthMode _mode = _AuthMode.signIn;
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!AppConfig.supabaseReady) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final auth = Supabase.instance.client.auth;
      if (_mode == _AuthMode.reset) {
        await auth.resetPasswordForEmail(_email.text.trim());
        if (mounted) {
          showMessage(
            context,
            'If the address is registered, a reset email will arrive shortly.',
          );
        }
      } else if (_mode == _AuthMode.signUp) {
        final response = await auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
        );
        if (mounted) {
          showMessage(
            context,
            response.session == null
                ? 'Check your email to confirm your account, then sign in.'
                : 'Account created. Your workspace remains local in this MVP.',
          );
          context.go('/welcome');
        }
      } else {
        await auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        if (mounted) {
          showMessage(
            context,
            'Signed in. Note: this MVP workspace is stored on this device.',
          );
          context.go('/welcome');
        }
      }
    } on AuthException catch (error) {
      if (mounted) showMessage(context, error.message);
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Could not reach the sign-in service. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                if (!AppConfig.supabaseReady) ...[
                  const DemoNotice(
                    message:
                        'Supabase is not configured. Account sign-in is unavailable; use the local demo.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go('/welcome'),
                    child: const Text('Back to demo'),
                  ),
                ] else ...[
                  Text(
                    _mode == _AuthMode.signIn
                        ? 'Welcome back'
                        : _mode == _AuthMode.signUp
                            ? 'Create an account'
                            : 'Reset password',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Supabase handles authentication. Career, journal, and learning workspace data are still stored locally in this MVP.',
                  ),
                  const SizedBox(height: 22),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (value) =>
                              value == null || !value.contains('@')
                                  ? 'Enter a valid email address.'
                                  : null,
                        ),
                        if (_mode != _AuthMode.reset) ...[
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            autofillHints: _mode == _AuthMode.signIn
                                ? const [AutofillHints.password]
                                : const [AutofillHints.newPassword],
                            decoration: InputDecoration(
                              labelText: 'Password',
                              suffixIcon: IconButton(
                                tooltip: _obscure
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) =>
                                value == null || value.length < 8
                                    ? 'Use at least 8 characters.'
                                    : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _mode == _AuthMode.signIn
                                ? 'Sign in'
                                : _mode == _AuthMode.signUp
                                    ? 'Create account'
                                    : 'Send reset link',
                          ),
                  ),
                  const SizedBox(height: 10),
                  if (_mode == _AuthMode.signIn)
                    TextButton(
                      onPressed: () => setState(() => _mode = _AuthMode.reset),
                      child: const Text('Forgot password?'),
                    ),
                  if (_mode != _AuthMode.reset)
                    TextButton(
                      onPressed: () => setState(
                        () => _mode = _mode == _AuthMode.signIn
                            ? _AuthMode.signUp
                            : _AuthMode.signIn,
                      ),
                      child: Text(
                        _mode == _AuthMode.signIn
                            ? 'Create an account'
                            : 'I already have an account',
                      ),
                    ),
                  if (_mode == _AuthMode.reset)
                    TextButton(
                      onPressed: () => setState(() => _mode = _AuthMode.signIn),
                      child: const Text('Back to sign in'),
                    ),
                ],
              ],
            ),
          ),
        ),
      );
}
