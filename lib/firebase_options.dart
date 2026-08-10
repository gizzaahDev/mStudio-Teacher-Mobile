import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Firebase configuration for the registered Android teacher application.
/// Keep this in sync with android/app/google-services.json when regenerated.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => android;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAG3JEj_O3L9lwanRz7SV2peIQd84fFI28',
    appId: '1:309302092776:android:70f0e3d55b25260e673a5d',
    messagingSenderId: '309302092776',
    projectId: 'valentinemagicss',
    storageBucket: 'valentinemagicss.firebasestorage.app',
  );
}
