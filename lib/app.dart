import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_theme.dart';
import 'core/session.dart';
import 'core/teacher_notification_service.dart';
import 'features/auth/login_page.dart';
import 'features/auth/teacher_onboarding_page.dart';
import 'localization/app_locale.dart';
import 'features/teacher/teacher_shell.dart';

class MagicalTeacherApp extends StatefulWidget {
  const MagicalTeacherApp({super.key});

  @override
  State<MagicalTeacherApp> createState() => _MagicalTeacherAppState();
}

class _MagicalTeacherAppState extends State<MagicalTeacherApp> {
  final session = SessionController();
  final themeController = AppThemeController();
  late final Stream<User?> _authChanges;
  late final StreamSubscription<User?> _authSubscription;
  late final TeacherNotificationService _notifications;

  @override
  void initState() {
    super.initState();
    themeController.load();
    appLocale.load();
    _notifications = TeacherNotificationService(session.repository);
    unawaited(_notifications.initialize());
    _authChanges = FirebaseAuth.instance.authStateChanges();
    _authSubscription = _authChanges.listen((user) {
      if (user != null) session.bootstrap();
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    unawaited(_notifications.dispose());
    session.dispose();
    themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([themeController, appLocale]),
        builder: (context, _) => MaterialApp(
          title: 'm.teacher',
          locale: appLocale.locale,
          supportedLocales: const [Locale('en'), Locale('si'), Locale('ta')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeController.mode,
          builder: (context, child) => PremiumBackdrop(
            child: child ?? const SizedBox.shrink(),
          ),
          home: StreamBuilder<User?>(
            stream: _authChanges,
            initialData: FirebaseAuth.instance.currentUser,
            builder: (context, authSnapshot) {
              if (authSnapshot.connectionState == ConnectionState.waiting &&
                  authSnapshot.data == null) {
                return const _StartupScreen();
              }
              return AnimatedBuilder(
                animation: session,
                builder: (_, __) {
                  if (authSnapshot.data == null) {
                    return LoginPage(session: session);
                  }
                  if (!session.bootstrapped || session.loading) {
                    return const _StartupScreen();
                  }
                  final profile = session.profile;
                  if (profile == null) {
                    if (session.error != null) {
                      return _ProfileError(
                          session: session, message: session.error!);
                    }
                    return TeacherOnboardingPage(session: session);
                  }
                  if (profile['role'] != 'teacher' &&
                      profile['role'] != 'admin') {
                    return _ProfileError(
                        session: session,
                        message:
                            'This is not a teacher account. Sign in with a teacher account.');
                  }
                  if (profile['role'] == 'teacher' &&
                      profile['status'] == 'pending' &&
                      profile['verificationComplete'] != true) {
                    return TeacherOnboardingPage(session: session);
                  }
                  if (profile['status'] != 'approved' ||
                      profile['workspaceAccessStatus'] == 'pending') {
                    return TeacherApprovalPage(
                        session: session, profile: profile);
                  }
                  return TeacherShell(
                      session: session, themeController: themeController);
                },
              );
            },
          ),
        ),
      );
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.school_rounded, size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                appLocale.tr('Teacher'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      );
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.session, required this.message});
  final SessionController session;
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.cloud_off_rounded,
                        size: 52, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 14),
                    Text('Could not load teacher account',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    Wrap(spacing: 10, children: [
                      FilledButton.icon(
                          onPressed: () =>
                              session.refreshProfile(forceNetwork: true),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry')),
                      OutlinedButton(
                          onPressed: session.signOut,
                          child: const Text('Sign out')),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}
