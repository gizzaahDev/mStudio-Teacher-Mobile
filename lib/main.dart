import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'app.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = FlutterError.presentError;
    ErrorWidget.builder = _errorWidget;
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    } catch (error, stack) {
      debugPrint('Firebase start failed: $error\n$stack');
    }
    runApp(const MagicalTeacherApp());
  }, (error, stack) => debugPrint('Unhandled app error: $error\n$stack'));
}

Widget _errorWidget(FlutterErrorDetails details) => const Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
                'This section could not be displayed. Please go back and try again.',
                textAlign: TextAlign.center),
          ),
        ),
      ),
    );
