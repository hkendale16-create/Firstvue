import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/username_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter an email and a password of at least 8 characters.',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
        final response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );
        if (!mounted) return;
        if (response.session == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Account created. Check your email to confirm it, then sign in.',
              ),
            ),
          );
          setState(() => _isSignUp = false);
        } else {
          await _ensureProfile(response.user);
          if (mounted) await _finishAuth(missingHandlePrompt: true);
        }
      } else {
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        await _ensureProfile(response.user);
        if (mounted) await _finishAuth(missingHandlePrompt: true);
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to reach FirstVue securely. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _ensureProfile(User? user) async {
    if (user == null) return;
    final displayName = user.email?.split('@').first;
    try {
      await Supabase.instance.client.rpc(
        'ensure_user_profile',
        params: {'display_name': displayName},
      );
    } catch (_) {
      final existing = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      if (existing == null) {
        await Supabase.instance.client.from('profiles').insert({
          'id': user.id,
          'display_name': displayName,
        });
      }
    }
  }

  Future<void> _finishAuth({required bool missingHandlePrompt}) async {
    final needsHandle =
        missingHandlePrompt && (await UsernameService.fetchUsername()) == null;
    if (!mounted) return;
    Navigator.pop(context, needsHandle);
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email to reset your password.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FIRSTVUE ACCOUNT',
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _isSignUp
                  ? 'Create your account to save, inquire, and manage your business.'
                  : 'Sign in to continue with your FirstVue account.',
              style: const TextStyle(color: Colors.white54, height: 1.45),
            ),
            const SizedBox(height: 28),
            _AuthField(
              controller: _emailController,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            _AuthField(
              controller: _passwordController,
              label: 'Password',
              obscureText: true,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD8B56A),
                  foregroundColor: Colors.black,
                ),
                child: Text(
                  _isLoading
                      ? 'PLEASE WAIT...'
                      : _isSignUp
                      ? 'CREATE ACCOUNT'
                      : 'SIGN IN',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading ? null : _resetPassword,
                child: const Text('Forgot password?'),
              ),
            ),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() => _isSignUp = !_isSignUp),
              child: Text(
                _isSignUp
                    ? 'Already have an account? Sign in'
                    : 'New to FirstVue? Create an account',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;

  const _AuthField({
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF151B22),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: const Color(0xFFD8B56A).withValues(alpha: .2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFD8B56A)),
        ),
      ),
    );
  }
}
