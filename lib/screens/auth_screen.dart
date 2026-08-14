import 'dart:async';

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
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _newPasswordController = TextEditingController();

  Timer? _usernameDebounce;
  late AuthSheetMode _mode;
  UsernameAvailability _usernameAvailability = UsernameAvailability.empty;
  bool _submitting = false;
  bool _acceptedLegal = false;
  bool _createTouched = false;
  String? _emailError;
  String? _usernameError;
  String? _passwordError;
  String? _confirmError;
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
      _setMode(widget.initialMode);
    }
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  bool get _strongPassword {
    final value = _passwordController.text;
    return value.length >= 8 &&
        RegExp(r'[a-z]').hasMatch(value) &&
        RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[0-9]').hasMatch(value);
  }

  bool get _createReady {
    return AuthIdentifier.parse(_emailController.text).email != null &&
        UsernameService.normalize(_usernameController.text) != null &&
        _usernameAvailability == UsernameAvailability.available &&
        _strongPassword &&
        _confirmController.text == _passwordController.text &&
        _confirmController.text.isNotEmpty &&
        _acceptedLegal;
  }

  void _setMode(AuthSheetMode mode) {
    if (_submitting || mode == _mode) return;
    _usernameDebounce?.cancel();
    _passwordController.clear();
    _confirmController.clear();
    _newPasswordController.clear();
    setState(() {
      _mode = mode;
      _createTouched = false;
      _emailError = null;
      _usernameError = null;
      _passwordError = null;
      _confirmError = null;
      _formError = null;
      _infoMessage = null;
    });
  }

  void _onCreateValueChanged(String _) {
    if (_createTouched) {
      _setCreateErrors();
    } else {
      setState(() {});
    }
  }

  void _onUsernameChanged(String _) {
    _usernameDebounce?.cancel();
    final normalized = UsernameService.normalize(_usernameController.text);
    if (normalized == null) {
      setState(() {
        _usernameAvailability = _usernameController.text.trim().isEmpty
            ? UsernameAvailability.empty
            : UsernameAvailability.invalid;
        if (_createTouched) {
          _usernameError = UsernameService.validationMessage(
            _usernameController.text,
          );
        }
      });
      return;
    }
    setState(() {
      _usernameAvailability = UsernameAvailability.checking;
      _usernameError = null;
    });
    _usernameDebounce = Timer(const Duration(milliseconds: 350), () async {
      final result = await UsernameService.checkAvailability(normalized);
      if (!mounted ||
          UsernameService.normalize(_usernameController.text) != normalized) {
        return;
      }
      setState(() {
        _usernameAvailability = result;
        _usernameError = switch (result) {
          UsernameAvailability.taken => 'That username is already taken.',
          UsernameAvailability.error =>
            'Username availability is temporarily unavailable.',
          _ => null,
        };
      });
    });
  }

  void _setCreateErrors() {
    final email = AuthIdentifier.parse(_emailController.text).email;
    final normalized = UsernameService.normalize(_usernameController.text);
    setState(() {
      _emailError = email == null ? 'Enter a valid email address.' : null;
      _usernameError = normalized == null
          ? UsernameService.validationMessage(_usernameController.text)
          : switch (_usernameAvailability) {
              UsernameAvailability.taken => 'That username is already taken.',
              UsernameAvailability.error =>
                'Username availability is temporarily unavailable.',
              _ => null,
            };
      _passwordError = _strongPassword
          ? null
          : 'Use 8+ characters with uppercase, lowercase, and a number.';
      _confirmError =
          _confirmController.text == _passwordController.text &&
              _confirmController.text.isNotEmpty
          ? null
          : 'Passwords do not match.';
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
    if (_passwordController.text.isEmpty) {
      _passwordError = 'Enter your password.';
    }
    setState(() {});
    return _emailError == null && _passwordError == null;
  }

  bool _validateCreate() {
    _createTouched = true;
    _setCreateErrors();
    if (!_acceptedLegal) {
      setState(() {
        _formError = 'Accept the Terms and Privacy Policy to continue.';
      });
      return false;
    }
    if (_usernameAvailability != UsernameAvailability.available) {
      setState(() {
        _formError = _usernameAvailability == UsernameAvailability.checking
            ? 'Wait for the username check to finish.'
            : 'Choose an available username.';
      });
      return false;
    }
    setState(() => _formError = null);
    return _createReady;
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
      if (_validateCreate()) await _createAccount();
      return;
    }
    if (_validateSignIn()) await _signIn();
  }

  Future<void> _signIn() async {
    final identifier = AuthIdentifier.parse(_emailController.text);
    setState(() {
      _submitting = true;
      _formError = null;
      _infoMessage = null;
    });
    try {
      if (identifier.email != null) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: identifier.email!,
          password: _passwordController.text,
        );
      } else {
        final response = await Supabase.instance.client.functions.invoke(
          'username-login',
          body: {
            'username': identifier.username,
            'password': _passwordController.text,
          },
        );
        final data = response.data;
        if (response.status != 200 || data is! Map) {
          throw const AuthException(kGenericAuthError);
        }
        final refreshToken = data['refresh_token'] as String?;
        if (refreshToken == null || refreshToken.isEmpty) {
          throw const AuthException(kGenericAuthError);
        }
        await Supabase.instance.client.auth.setSession(refreshToken);
      }
      await _ensureProfile(Supabase.instance.client.auth.currentUser);
      if (mounted) {
        setState(() => _infoMessage = 'Signed in successfully.');
      }
    } on AuthException {
      if (mounted) setState(() => _formError = kGenericAuthError);
    } catch (_) {
      if (mounted) setState(() => _formError = kGenericAuthError);
    } finally {
      _passwordController.clear();
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _createAccount() async {
    final email = AuthIdentifier.parse(_emailController.text).email!;
    final username = UsernameService.normalize(_usernameController.text)!;
    setState(() {
      _submitting = true;
      _formError = null;
      _infoMessage = null;
    });
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: _passwordController.text,
        emailRedirectTo: approvedAuthCallbackUrl(path: '/auth/confirm'),
        data: {
          'username': username,
          'terms_accepted': true,
          'privacy_accepted': true,
        },
      );
      _passwordController.clear();
      _confirmController.clear();
      if (!mounted) return;
      if (response.session == null) {
        setState(() {
          _mode = AuthSheetMode.signIn;
          _infoMessage =
              'Account created. Check your email to verify it, then sign in.';
          _formError = null;
        });
      } else {
        await _ensureProfile(response.user);
        if (mounted) {
          setState(() => _infoMessage = 'Account created successfully.');
        }
      }
    } on AuthException {
      if (mounted) {
        setState(
          () => _formError =
              'Unable to create this account. Check the fields and try again.',
        );
      }
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
        redirectTo: approvedAuthCallbackUrl(path: '/reset-password'),
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
    final password = _newPasswordController.text;
    final valid = password.length >= 8 &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password);
    if (!valid) {
      setState(
        () => _passwordError =
            'Use 8+ characters with uppercase, lowercase, and a number.',
      );
      return;
    }
    if (password != _confirmController.text) {
      setState(() => _confirmError = 'Passwords do not match.');
      return;
    }
    setState(() {
      _submitting = true;
      _passwordError = null;
      _confirmError = null;
      _formError = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );
      _newPasswordController.clear();
      _confirmController.clear();
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
      await UsernameService.fetchUsername();
    } catch (_) {
      // Profile bootstrap is retried by signed-in feature services.
    }
  }

  Future<void> _oauth(OAuthProvider provider) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _formError = null;
    });
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
    final media = MediaQuery.of(context);
    final height = media.size.height;
    final short = height < 700;
    final reduceMotion = media.disableAnimations;
    final heroHeight = (height * (short ? .34 : .39)).clamp(220.0, 360.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Theme(
        data: FirstVueTheme.elegantDark,
        child: PopScope(
          canPop: widget.allowBack,
          child: Scaffold(
            backgroundColor: const Color(0xFF080D1B),
            resizeToAvoidBottomInset: true,
            body: SafeArea(
              child: Stack(
                children: [
                  SizedBox(
                    height: heroHeight,
                    width: double.infinity,
                    child: _HeroHeader(compact: short),
                  ),
                  Positioned(
                    top: heroHeight - 34,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: Color(0xFF111726),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(38),
                        ),
                        border: Border(
                          top: BorderSide(color: Color(0xFF293148)),
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: AutofillGroup(
                            child: SingleChildScrollView(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_mode != AuthSheetMode.forgotPassword &&
                                      _mode != AuthSheetMode.recovery)
                                    _SegmentedAuthToggle(
                                      mode: _mode,
                                      enabled: !_submitting,
                                      onChanged: _setMode,
                                    )
                                  else
                                    Text(
                                      _mode == AuthSheetMode.recovery
                                          ? 'Choose a new password'
                                          : 'Reset password',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  const SizedBox(height: 20),
                                  AnimatedSize(
                                    duration: Duration(
                                      milliseconds: reduceMotion ? 0 : 220,
                                    ),
                                    curve: Curves.easeOutCubic,
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
            valid: AuthIdentifier.parse(_emailController.text).email != null,
            prefixIcon: Icons.alternate_email_rounded,
            errorText: _emailError,
            keyboardType: TextInputType.emailAddress,
            textInputAction: forgot
                ? TextInputAction.done
                : TextInputAction.next,
            autofillHints: signIn
                ? const [AutofillHints.username, AutofillHints.email]
                : const [AutofillHints.email],
            onChanged: create ? _onCreateValueChanged : (_) => setState(() {}),
            onSubmitted: forgot ? (_) => _submit() : null,
          ),
          const SizedBox(height: 14),
        ],
        if (create) ...[
          FvAuthField(
            key: const ValueKey('auth-username-field'),
            label: 'Unique username',
            controller: _usernameController,
            enabled: !_submitting,
            valid: _usernameAvailability == UsernameAvailability.available,
            prefixIcon: Icons.person_outline_rounded,
            errorText: _usernameError,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newUsername],
            onChanged: _onUsernameChanged,
          ),
          const SizedBox(height: 6),
          _UsernameStatus(availability: _usernameAvailability),
          const SizedBox(height: 8),
        ],
        if (!forgot) ...[
          FvAuthField(
            key: const ValueKey('auth-password-field'),
            label: recovery ? 'New password' : 'Password',
            controller: recovery ? _newPasswordController : _passwordController,
            enabled: !_submitting,
            valid: create && _strongPassword,
            prefixIcon: Icons.lock_outline_rounded,
            isPassword: true,
            obscureText: true,
            errorText: _passwordError,
            textInputAction:
                create || recovery ? TextInputAction.next : TextInputAction.done,
            autofillHints: create || recovery
                ? const [AutofillHints.newPassword]
                : const [AutofillHints.password],
            onChanged: create ? _onCreateValueChanged : (_) => setState(() {}),
            onSubmitted: create || recovery ? null : (_) => _submit(),
          ),
          const SizedBox(height: 10),
        ],
        if (create || recovery) ...[
          FvAuthField(
            key: const ValueKey('auth-confirm-password-field'),
            label: 'Confirm password',
            controller: _confirmController,
            enabled: !_submitting,
            valid: _confirmController.text.isNotEmpty &&
                _confirmController.text ==
                    (recovery
                        ? _newPasswordController.text
                        : _passwordController.text),
            prefixIcon: Icons.lock_reset_rounded,
            isPassword: true,
            obscureText: true,
            errorText: _confirmError,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: create ? _onCreateValueChanged : (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 10),
        ],
        if (signIn)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _submitting
                  ? null
                  : () => _setMode(AuthSheetMode.forgotPassword),
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  color: FirstVueColors.gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (create) ...[
          Text(
            'Password: 8+ characters, uppercase, lowercase, and a number.',
            style: TextStyle(
              color: _strongPassword
                  ? FirstVueColors.teal
                  : Colors.white.withValues(alpha: .62),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                key: const ValueKey('auth-legal-checkbox'),
                value: _acceptedLegal,
                onChanged: _submitting
                    ? null
                    : (value) {
                        setState(() {
                          _acceptedLegal = value ?? false;
                          if (_acceptedLegal) _formError = null;
                        });
                      },
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 11),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'I agree to the ',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .72),
                          fontSize: 13,
                        ),
                      ),
                      _LegalLink(label: 'Terms', route: '/terms'),
                      Text(
                        ' and ',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .72),
                          fontSize: 13,
                        ),
                      ),
                      _LegalLink(
                        label: 'Privacy Policy',
                        route: '/privacy',
                      ),
                      const Text(
                        '.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
        if (_formError != null || _infoMessage != null) ...[
          const SizedBox(height: 4),
          Semantics(
            liveRegion: true,
            child: Text(
              _formError ?? _infoMessage!,
              style: TextStyle(
                color: _formError != null
                    ? const Color(0xFFF2A4A4)
                    : FirstVueColors.teal,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ] else
          const SizedBox(height: 12),
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
          enabled: !_submitting && (!create || _createReady),
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
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Divider(color: Colors.white.withValues(alpha: .16)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR CONTINUE WITH',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .48),
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Divider(color: Colors.white.withValues(alpha: .16)),
              ),
            ],
          ),
          const SizedBox(height: 15),
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
              icon: Icons.g_mobiledata_rounded,
              onPressed: _submitting
                  ? null
                  : () => _oauth(OAuthProvider.google),
            ),
        ],
        if (signIn || create) ...[
          const SizedBox(height: 20),
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  create ? 'Already have an account? ' : 'New to FirstVue? ',
                  style: TextStyle(color: Colors.white.withValues(alpha: .66)),
                ),
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => _setMode(
                          create
                              ? AuthSheetMode.signIn
                              : AuthSheetMode.createAccount,
                        ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    minimumSize: const Size(44, 44),
                  ),
                  child: Text(create ? 'Sign in' : 'Create account'),
                ),
              ],
            ),
          ),
          if (signIn)
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: const [
                  _LegalLink(label: 'Terms', route: '/terms'),
                  Text('  •  ', style: TextStyle(color: Colors.white38)),
                  _LegalLink(
                    label: 'Privacy Policy',
                    route: '/privacy',
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
        const ColoredBox(color: Color(0xFF080D1B)),
        Image.asset(
          'assets/images/auth_hero.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF080D1B)),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, .55, 1],
              colors: [
                Color(0x66040A16),
                Color(0x88070D1A),
                Color(0xFF080D1B),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, compact ? 12 : 22, 20, 42),
          child: Column(
            children: [
              FirstVueEmblem(size: compact ? 54 : 66),
              SizedBox(height: compact ? 10 : 16),
              Text(
                'Welcome to FirstVue',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 23 : 28,
                  height: 1.1,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 12)],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Connect with what’s happening nearby.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .86),
                  fontSize: compact ? 13 : 15,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
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
        child: Semantics(
          button: true,
          selected: selected,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey('auth-segment-$label'),
              borderRadius: BorderRadius.circular(28),
              onTap: enabled ? () => onChanged(value) : null,
              child: AnimatedContainer(
                duration: Duration(milliseconds: reduceMotion ? 0 : 190),
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? FirstVueColors.gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF080D1B)
                        : Colors.white.withValues(alpha: .72),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF141B2B),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF333B50)),
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

class _SocialAuthButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _SocialAuthButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_SocialAuthButton> createState() => _SocialAuthButtonState();
}

class _SocialAuthButtonState extends State<_SocialAuthButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? .98 : 1,
          duration: Duration(milliseconds: reduceMotion ? 0 : 80),
          child: AnimatedContainer(
            duration: Duration(milliseconds: reduceMotion ? 0 : 80),
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF101625),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: _pressed ? .48 : .22),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _pressed ? .12 : .28),
                  blurRadius: _pressed ? 3 : 8,
                  offset: Offset(0, _pressed ? 1 : 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: Colors.white, size: 27),
                const SizedBox(width: 12),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UsernameStatus extends StatelessWidget {
  final UsernameAvailability availability;

  const _UsernameStatus({required this.availability});

  @override
  Widget build(BuildContext context) {
    return switch (availability) {
      UsernameAvailability.checking => const Row(
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: FirstVueColors.teal,
              ),
            ),
            SizedBox(width: 7),
            Text(
              'Checking availability…',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      UsernameAvailability.available => const Row(
          children: [
            Icon(Icons.check_circle_outline, color: FirstVueColors.teal, size: 15),
            SizedBox(width: 6),
            Text(
              'Username is available',
              style: TextStyle(color: FirstVueColors.teal, fontSize: 12),
            ),
          ],
        ),
      _ => const SizedBox(height: 15),
    };
  }
}

class _LegalLink extends StatelessWidget {
  final String label;
  final String route;

  const _LegalLink({required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      label: label,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pushNamed(route),
        child: Text(
          label,
          style: const TextStyle(
            color: FirstVueColors.gold,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: FirstVueColors.gold,
          ),
        ),
      ),
    );
  }
}
