import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_redirect.dart';
import '../services/username_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/firstvue_emblem.dart';
import '../widgets/fv_auth_field.dart';
import '../widgets/fv_gold_button.dart';

class AuthScreen extends StatefulWidget {
  final AuthSheetMode initialMode;
  final bool allowBack;

  const AuthScreen({
    super.key,
    this.initialMode = AuthSheetMode.signIn,
    this.allowBack = false,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _newPasswordController = TextEditingController();

  late AuthSheetMode _mode;
  bool _submitting = false;
  String? _emailError;
  String? _passwordError;
  String? _formError;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void didUpdateWidget(covariant AuthScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMode != widget.initialMode) {
      _mode = widget.initialMode;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _setMode(AuthSheetMode mode) {
    if (_submitting || mode == _mode) return;
    setState(() {
      _mode = mode;
      _emailError = null;
      _passwordError = null;
      _formError = null;
      _infoMessage = null;
    });
  }

  bool _validateSignIn() {
    final identifier = AuthIdentifier.parse(_emailController.text);
    _emailError = null;
    _passwordError = null;
    _formError = null;
    if (identifier.email == null && identifier.username == null) {
      _emailError = 'Enter an email or username.';
    }
    if (_passwordController.text.length < 8) {
      _passwordError = 'Password must be at least 8 characters.';
    }
    setState(() {});
    return _emailError == null && _passwordError == null;
  }

  bool _validateCreate() {
    final identifier = AuthIdentifier.parse(_emailController.text);
    _emailError = null;
    _passwordError = null;
    _formError = null;
    if (identifier.email == null) {
      _emailError = 'Enter a valid email address.';
    }
    if (_passwordController.text.length < 8) {
      _passwordError = 'Password must be at least 8 characters.';
    }
    setState(() {});
    return _emailError == null && _passwordError == null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_mode == AuthSheetMode.forgotPassword) {
      await _sendReset();
      return;
    }
    if (_mode == AuthSheetMode.recovery) {
      await _updatePassword();
      return;
    }
    if (_mode == AuthSheetMode.createAccount) {
      if (!_validateCreate()) return;
      await _createAccount();
      return;
    }
    if (!_validateSignIn()) return;
    await _signIn();
  }

  Future<void> _signIn() async {
    final identifier = AuthIdentifier.parse(_emailController.text);
    if (identifier.username != null && identifier.email == null) {
      // Username → email resolution needs a security-definer RPC that never
      // returns the email to the client. That backend is not in this project.
      setState(() => _formError = kGenericAuthError);
      return;
    }
    final email = identifier.email;
    if (email == null) {
      setState(() => _formError = kGenericAuthError);
      return;
    }

    setState(() => _submitting = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: _passwordController.text,
      );
      await _ensureProfile(Supabase.instance.client.auth.currentUser);
      if (mounted) await UsernameService.fetchUsername();
    } on AuthException {
      if (mounted) setState(() => _formError = kGenericAuthError);
    } catch (_) {
      if (mounted) setState(() => _formError = kGenericAuthError);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _createAccount() async {
    final email = AuthIdentifier.parse(_emailController.text).email!;
    setState(() => _submitting = true);
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (response.session == null) {
        setState(() {
          _mode = AuthSheetMode.signIn;
          _infoMessage =
              'Account created. Check your email to confirm it, then sign in.';
          _formError = null;
        });
      } else {
        await _ensureProfile(response.user);
      }
    } on AuthException {
      if (mounted) setState(() => _formError = kGenericAuthError);
    } catch (_) {
      if (mounted) {
        setState(() => _formError = 'Unable to create an account right now.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _sendReset() async {
    final email = AuthIdentifier.parse(_emailController.text).email;
    if (email == null) {
      setState(() => _emailError = 'Enter the email for your account.');
      return;
    }
    setState(() {
      _submitting = true;
      _emailError = null;
      _formError = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: approvedAuthCallbackUrl(),
      );
      if (mounted) {
        setState(() {
          _infoMessage = kGenericResetMessage;
          _mode = AuthSheetMode.signIn;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _infoMessage = kGenericResetMessage);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _updatePassword() async {
    if (_newPasswordController.text.length < 8) {
      setState(
        () => _passwordError = 'Password must be at least 8 characters.',
      );
      return;
    }
    if (_newPasswordController.text != _confirmController.text) {
      setState(() => _passwordError = 'Passwords do not match.');
      return;
    }
    setState(() {
      _submitting = true;
      _passwordError = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );
      if (mounted) {
        setState(() {
          _mode = AuthSheetMode.signIn;
          _infoMessage = 'Password updated. You are signed in.';
        });
      }
    } on AuthException {
      if (mounted) {
        setState(
          () => _formError =
              'This reset link is invalid or has expired. Request a new one.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _formError =
              'This reset link is invalid or has expired. Request a new one.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
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
    } catch (_) {}
  }

  Future<void> _oauth(OAuthProvider provider) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: approvedAuthCallbackUrl(),
      );
    } catch (_) {
      if (mounted) setState(() => _formError = kGenericAuthError);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final short = height < 720;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Theme(
        data: FirstVueTheme.elegantDark,
        child: PopScope(
          canPop: widget.allowBack,
          child: Scaffold(
            backgroundColor: const Color(0xFF0B1020),
            body: SafeArea(
              child: Column(
                children: [
                  SizedBox(
                    height: short ? 132 : 220,
                    child: _HeroHeader(compact: short),
                  ),
                  Expanded(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: Color(0xFF121826),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: AutofillGroup(
                            child: ListView(
                              padding: EdgeInsets.fromLTRB(
                                22,
                                20,
                                22,
                                24 + bottomInset,
                              ),
                              children: [
                                if (_mode != AuthSheetMode.forgotPassword &&
                                    _mode != AuthSheetMode.recovery)
                                  _SegmentedAuthToggle(
                                    mode: _mode,
                                    enabled: !_submitting,
                                    onChanged: _setMode,
                                  ),
                                if (_mode == AuthSheetMode.forgotPassword)
                                  Text(
                                    'Reset password',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: .92,
                                      ),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                if (_mode == AuthSheetMode.recovery)
                                  Text(
                                    'Choose a new password',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: .92,
                                      ),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                const SizedBox(height: 18),
                                AnimatedSize(
                                  duration: Duration(
                                    milliseconds: reduceMotion ? 0 : 220,
                                  ),
                                  curve: Curves.easeOut,
                                  alignment: Alignment.topCenter,
                                  child: _formBody(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formBody() {
    final signIn = _mode == AuthSheetMode.signIn;
    final create = _mode == AuthSheetMode.createAccount;
    final forgot = _mode == AuthSheetMode.forgotPassword;
    final recovery = _mode == AuthSheetMode.recovery;
    final showApple = oauthAppleEnabled();
    final showGoogle = oauthGoogleEnabled();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!recovery) ...[
          FvAuthField(
            key: const ValueKey('auth-email-field'),
            label: signIn ? 'Email or username' : 'Email',
            controller: _emailController,
            enabled: !_submitting,
            errorText: _emailError,
            keyboardType: TextInputType.emailAddress,
            textInputAction: forgot
                ? TextInputAction.done
                : TextInputAction.next,
            autofillHints: signIn
                ? const [AutofillHints.username, AutofillHints.email]
                : const [AutofillHints.email],
            onSubmitted: forgot ? (_) => _submit() : null,
          ),
          const SizedBox(height: 14),
        ],
        if (!forgot) ...[
          FvAuthField(
            key: const ValueKey('auth-password-field'),
            label: recovery ? 'New password' : 'Password',
            controller: recovery ? _newPasswordController : _passwordController,
            enabled: !_submitting,
            isPassword: true,
            obscureText: true,
            errorText: _passwordError,
            textInputAction: recovery
                ? TextInputAction.next
                : TextInputAction.done,
            autofillHints: create
                ? const [AutofillHints.newPassword]
                : const [AutofillHints.password],
            onSubmitted: recovery ? null : (_) => _submit(),
          ),
          const SizedBox(height: 8),
        ],
        if (recovery) ...[
          FvAuthField(
            label: 'Confirm password',
            controller: _confirmController,
            enabled: !_submitting,
            isPassword: true,
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
        ],
        if (signIn)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _submitting
                  ? null
                  : () => _setMode(AuthSheetMode.forgotPassword),
              child: Text(
                'Forgot password?',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (create)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Use at least 8 characters. We’ll email a confirmation link.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .62),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        SizedBox(
          height: 22,
          child: (_formError != null)
              ? Text(
                  _formError!,
                  style: const TextStyle(
                    color: Color(0xFFE39A9A),
                    fontSize: 13,
                  ),
                )
              : (_infoMessage != null)
              ? Text(
                  _infoMessage!,
                  style: const TextStyle(
                    color: FirstVueColors.teal,
                    fontSize: 13,
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),
        FvGoldButton(
          key: const ValueKey('auth-primary-button'),
          label: recovery
              ? 'Update password'
              : forgot
              ? 'Send reset link'
              : create
              ? 'Create account'
              : 'Sign in',
          loading: _submitting,
          enabled: !_submitting,
          onPressed: _submit,
        ),
        if (forgot) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _submitting
                ? null
                : () => _setMode(AuthSheetMode.signIn),
            child: const Text('Back to sign in'),
          ),
        ],
        if (signIn && (showApple || showGoogle)) ...[
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Divider(color: Colors.white.withValues(alpha: .16)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'OR CONTINUE WITH',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .45),
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Divider(color: Colors.white.withValues(alpha: .16)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (showApple)
            _SocialAuthButton(
              label: 'Continue with Apple',
              icon: Icons.apple,
              onPressed: _submitting ? null : () => _oauth(OAuthProvider.apple),
            ),
          if (showApple && showGoogle) const SizedBox(height: 10),
          if (showGoogle)
            _SocialAuthButton(
              label: 'Continue with Google',
              icon: Icons.g_mobiledata,
              onPressed: _submitting
                  ? null
                  : () => _oauth(OAuthProvider.google),
            ),
        ],
        if (signIn || create) ...[
          const SizedBox(height: 18),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                Text(
                  create ? 'Already have an account? ' : 'New to FirstVue? ',
                  style: TextStyle(color: Colors.white.withValues(alpha: .65)),
                ),
                GestureDetector(
                  onTap: _submitting
                      ? null
                      : () => _setMode(
                          create
                              ? AuthSheetMode.signIn
                              : AuthSheetMode.createAccount,
                        ),
                  child: Text(
                    create ? 'Sign in' : 'Create account',
                    style: const TextStyle(
                      color: FirstVueColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final bool compact;

  const _HeroHeader({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF0B1020)),
        Image.asset(
          'assets/images/auth_hero.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF0B1020)),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x660B1020), Color(0xCC0B1020), Color(0xFF0B1020)],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, compact ? 8 : 16, 20, 8),
          child: Column(
            children: [
              FirstVueEmblem(size: compact ? 44 : 56),
              SizedBox(height: compact ? 8 : 14),
              const Text(
                'Welcome to FirstVue',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Connect with what’s happening nearby.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .82),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SegmentedAuthToggle extends StatelessWidget {
  final AuthSheetMode mode;
  final bool enabled;
  final ValueChanged<AuthSheetMode> onChanged;

  const _SegmentedAuthToggle({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    Widget chip(String label, AuthSheetMode value) {
      final selected = mode == value;
      return Expanded(
        child: GestureDetector(
          onTap: enabled ? () => onChanged(value) : null,
          child: AnimatedContainer(
            duration: Duration(milliseconds: reduceMotion ? 0 : 180),
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? FirstVueColors.gold : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              label,
              key: ValueKey('auth-segment-$label'),
              style: TextStyle(
                color: selected
                    ? const Color(0xFF0B1020)
                    : Colors.white.withValues(alpha: .7),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2230),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            chip('Sign in', AuthSheetMode.signIn),
            chip('Create account', AuthSheetMode.createAccount),
          ],
        ),
      ),
    );
  }
}

class _SocialAuthButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _SocialAuthButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: Colors.white.withValues(alpha: .35)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
