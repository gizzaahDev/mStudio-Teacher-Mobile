import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/session.dart';
import '../../localization/app_locale.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.session});

  final SessionController session;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginLanguageButton extends StatelessWidget {
  const _LoginLanguageButton();

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: appLocale.tr('Language'),
        initialValue: appLocale.code,
        onSelected: appLocale.setLanguage,
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'en', child: Text('English')),
          PopupMenuItem(value: 'si', child: Text('සිංහල')),
          PopupMenuItem(value: 'ta', child: Text('தமிழ்')),
        ],
        child: Material(
          elevation: 4,
          shape: const CircleBorder(),
          color: Theme.of(context).colorScheme.surface,
          child: const Padding(
            padding: EdgeInsets.all(13),
            child: Icon(Icons.language_rounded),
          ),
        ),
      );
}

class _LoginPageState extends State<LoginPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isBusy = false;
  bool _createMode = false;
  bool _hidePassword = true;
  int _trialDays = 30;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    widget.session.repository.appSettings().then((response) {
      final root = response is Map ? response : const {};
      final settings =
          root['settings'] is Map ? root['settings'] as Map : const {};
      final deployment = settings['deployment'] is Map
          ? settings['deployment'] as Map
          : const {};
      if (mounted) {
        setState(() => _trialDays =
            (deployment['teacherTrialDays'] as num?)?.toInt() ?? 30);
      }
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Enter your email address and password.');
      return;
    }
    await _runSignIn(() => FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        ));
  }

  Future<void> _createAccount() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (name.isEmpty || email.isEmpty || password.length < 8) {
      setState(() => _errorMessage =
          'Enter your name, email, and a password of at least 8 characters.');
      return;
    }
    if (password != _confirmController.text) {
      setState(() => _errorMessage = 'The passwords do not match.');
      return;
    }
    await _runSignIn(() async {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      await credential.user?.updateDisplayName(name);
    });
  }

  Future<void> _signInWithGoogle() async {
    await _runSignIn(() async {
      final account = await GoogleSignIn().signIn();
      if (account == null) return;
      final authentication = await account.authentication;
      await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(
          accessToken: authentication.accessToken,
          idToken: authentication.idToken,
        ),
      );
    });
  }

  Future<void> _runSignIn(Future<void> Function() action) async {
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      await action();
      // Firebase Auth persists the authenticated user on Android. The root
      // auth listener opens the dashboard and hydrates the local profile.
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message ?? 'Sign-in failed.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not sign in. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      floatingActionButton: const _LoginLanguageButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 52),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: .82),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: .2),
                          ),
                        ),
                        child: Text(
                          'MAGICAL ICT · TEACHER STUDIO',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: scheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.05,
                                  ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [scheme.primary, scheme.tertiary],
                          ),
                          borderRadius: BorderRadius.circular(27),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: .25),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.school_rounded,
                          size: 43,
                          color: scheme.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        appLocale.tr('Welcome back'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        appLocale.tr(
                            'Your classes, students, and learning spaces\nare ready when you are.'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                      ),
                      const SizedBox(height: 26),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: AutofillGroup(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _createMode
                                      ? appLocale.tr('Create teacher login')
                                      : appLocale.tr('Sign in'),
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  appLocale.tr(
                                      'Your login stays securely saved on this device.'),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 20),
                                if (_createMode) ...[
                                  TextField(
                                    controller: _nameController,
                                    textInputAction: TextInputAction.next,
                                    decoration: InputDecoration(
                                      labelText: appLocale.tr('Full name'),
                                      prefixIcon:
                                          const Icon(Icons.person_outline),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                TextField(
                                  controller: _emailController,
                                  autofillHints: const [
                                    AutofillHints.username,
                                    AutofillHints.email,
                                  ],
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autocorrect: false,
                                  decoration: InputDecoration(
                                    labelText: appLocale.tr('Email address'),
                                    prefixIcon:
                                        const Icon(Icons.alternate_email),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _passwordController,
                                  autofillHints: const [AutofillHints.password],
                                  obscureText: _hidePassword,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) =>
                                      _isBusy ? null : _signInWithEmail(),
                                  decoration: InputDecoration(
                                    labelText: appLocale.tr('Password'),
                                    prefixIcon:
                                        const Icon(Icons.lock_outline_rounded),
                                    suffixIcon: IconButton(
                                      tooltip: _hidePassword
                                          ? 'Show password'
                                          : 'Hide password',
                                      icon: Icon(
                                        _hidePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () => setState(
                                        () => _hidePassword = !_hidePassword,
                                      ),
                                    ),
                                  ),
                                ),
                                if (_createMode) ...[
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _confirmController,
                                    obscureText: _hidePassword,
                                    textInputAction: TextInputAction.done,
                                    decoration: InputDecoration(
                                      labelText:
                                          appLocale.tr('Confirm password'),
                                      prefixIcon:
                                          const Icon(Icons.lock_reset_rounded),
                                    ),
                                  ),
                                ],
                                if (_errorMessage != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: scheme.errorContainer,
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: scheme.onErrorContainer,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _isBusy
                                      ? null
                                      : (_createMode
                                          ? _createAccount
                                          : _signInWithEmail),
                                  icon: _isBusy
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.arrow_forward_rounded),
                                  label: Text(
                                    _isBusy ? 'Signing in…' : 'Continue',
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Row(
                                    children: [
                                      Expanded(child: Divider()),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 10),
                                        child: Text('or'),
                                      ),
                                      Expanded(child: Divider()),
                                    ],
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _isBusy ? null : _signInWithGoogle,
                                  icon: const Text(
                                    'G',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                  label: Text(
                                      appLocale.tr('Continue with Google')),
                                ),
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: _isBusy
                                      ? null
                                      : () => setState(() {
                                            _createMode = !_createMode;
                                            _errorMessage = null;
                                          }),
                                  child: Text(_createMode
                                      ? appLocale.tr(
                                          'Already have a teacher account? Sign in')
                                      : appLocale.tr(
                                          'New teacher? Create an account')),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'New approved teacher accounts include a $_trialDays-day free trial. No payment is required during the trial.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
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
        ),
      ),
    );
  }
}
