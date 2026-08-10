class AppConfig {
  /// Provide a reachable HTTPS backend when building/running a device app:
  /// flutter run --dart-define=BACKEND_URL=https://api.example.com
  /// Android emulators can use http://10.0.2.2:4000 during local development.
  static const backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:4000',
    ),
  );

  static const apiBaseUrl = backendUrl;
  static const teacherWebUrl = String.fromEnvironment(
    'TEACHER_WEB_URL',
    defaultValue: 'https://teacher.magicalict.com',
  );
  static const appName = 'Magical LMS.teacher';
}
