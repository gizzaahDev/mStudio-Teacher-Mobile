import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'teacher_repository.dart';

const _learningChannel = AndroidNotificationChannel(
  'magical_learning_updates',
  'Teacher updates',
  description:
      'Messages, class activity, approvals, fees and learning updates.',
  importance: Importance.high,
);
const _reminderChannel = AndroidNotificationChannel(
  'magical_reminders',
  'Teacher reminders',
  description: 'Calendar reminders created by the teacher.',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  audioAttributesUsage: AudioAttributesUsage.alarm,
);
const _silentChannel = AndroidNotificationChannel(
  'magical_silent_updates',
  'Silent teacher updates',
  description: 'Teacher notifications without a sound.',
  importance: Importance.high,
  playSound: false,
);

@pragma('vm:entry-point')
Future<void> teacherMessagingBackgroundHandler(RemoteMessage message) async {
  // Notification-payload messages are displayed by Android using the channel
  // already created during app startup.
}

class TeacherNotificationService {
  TeacherNotificationService(this.repository);
  final TeacherRepository repository;
  final _local = FlutterLocalNotificationsPlugin();
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;

  Future<void> initialize() async {
    const initialization = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(),
    );
    await _local.initialize(settings: initialization);
    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_learningChannel);
    await android?.createNotificationChannel(_reminderChannel);
    await android?.createNotificationChannel(_silentChannel);
    await FirebaseMessaging.instance
        .requestPermission(alert: true, badge: true, sound: true);
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
            alert: true, badge: true, sound: true);
    FirebaseMessaging.onBackgroundMessage(teacherMessagingBackgroundHandler);
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) _registerCurrentToken();
    });
    _tokenSubscription =
        FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);
    _messageSubscription = FirebaseMessaging.onMessage.listen(_showForeground);
    if (FirebaseAuth.instance.currentUser != null) {
      await _registerCurrentToken();
    }
  }

  Future<void> _registerCurrentToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) await _registerToken(token);
    } catch (_) {
      // Push registration retries automatically when Firebase refreshes token.
    }
  }

  Future<void> _registerToken(String token) async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      await repository.registerPushToken(token);
    } catch (_) {}
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final data = Map<String, dynamic>.from(message.data);
    final type = '${data['type'] ?? ''}';
    final sound = '${data['sound'] ?? 'system_default'}';
    final reminder = type.startsWith('reminder');
    final silent = sound == 'silent';
    final channel = silent
        ? _silentChannel
        : reminder
            ? _reminderChannel
            : _learningChannel;
    await _local.show(
      id: '${data['notificationId'] ?? message.messageId ?? DateTime.now().microsecondsSinceEpoch}'
              .hashCode &
          0x7fffffff,
      title: message.notification?.title ??
          '${data['title'] ?? (reminder ? 'Reminder' : 'Teacher update')}',
      body: message.notification?.body ??
          '${data['body'] ?? 'Open m.teacher to view it.'}',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: reminder ? Importance.max : Importance.high,
          priority: reminder ? Priority.max : Priority.high,
          playSound: !silent,
          audioAttributesUsage: reminder
              ? AudioAttributesUsage.alarm
              : AudioAttributesUsage.notification,
          icon: 'ic_notification',
          category: reminder ? AndroidNotificationCategory.alarm : null,
          styleInformation: BigTextStyleInformation(
              '${message.notification?.body ?? data['body'] ?? ''}'),
        ),
        iOS: DarwinNotificationDetails(presentSound: !silent),
      ),
      payload: jsonEncode(data),
    );
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
  }
}
