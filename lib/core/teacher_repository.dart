import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'api_client.dart';

const _defaultTeacherPlans = <Map<String, dynamic>>[
  {
    'id': 'starter-50',
    'label': 'Starter',
    'studentLabel': 'Up to 50 students',
    'maxStudents': 50,
    'monthly': 1500,
    'yearly': 15000,
    'monthlyOffer': 1200,
    'yearlyOffer': 12000
  },
  {
    'id': 'growth-150',
    'label': 'Growth',
    'studentLabel': 'Up to 150 students',
    'maxStudents': 150,
    'monthly': 3500,
    'yearly': 35000,
    'monthlyOffer': 3000,
    'yearlyOffer': 30000
  },
  {
    'id': 'academy-300',
    'label': 'Academy',
    'studentLabel': 'Up to 300 students',
    'maxStudents': 300,
    'monthly': 6500,
    'yearly': 65000,
    'monthlyOffer': 5500,
    'yearlyOffer': 55000
  },
  {
    'id': 'pro-500',
    'label': 'Professional',
    'studentLabel': 'Up to 500 students',
    'maxStudents': 500,
    'monthly': 9500,
    'yearly': 95000,
    'monthlyOffer': 8000,
    'yearlyOffer': 80000
  },
  {
    'id': 'scale-1000',
    'label': 'Scale',
    'studentLabel': 'Up to 1,000 students',
    'maxStudents': 1000,
    'monthly': 15000,
    'yearly': 150000,
    'monthlyOffer': 12500,
    'yearlyOffer': 125000
  },
  {
    'id': 'enterprise',
    'label': 'Enterprise',
    'studentLabel': 'More than 1,000 students',
    'maxStudents': null,
    'monthly': 25000,
    'yearly': 250000,
    'monthlyOffer': 22000,
    'yearlyOffer': 220000
  },
];

class TeacherRepository {
  TeacherRepository(this.api);
  final ApiClient api;
  Future<void> clearCache() => api.clearCache();

  Future<dynamic> dashboard() => api.get('/api/classroom/dashboard-summary');
  Future<dynamic> profile() async {
    dynamic privateResponse;
    try {
      privateResponse = await api.get('/api/users/me', refresh: true);
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      try {
        privateResponse = await api.get('/api/auth/me', refresh: true);
      } on ApiException catch (legacyError) {
        if (legacyError.statusCode != 404) rethrow;
        return {'profile': null};
      }
    }
    final privateRoot = privateResponse is Map ? privateResponse : const {};
    final privateValue = privateRoot['profile'] ?? privateRoot['user'];
    final privateProfile = privateValue is Map
        ? Map<String, dynamic>.from(privateValue)
        : <String, dynamic>{};
    if (privateProfile.isEmpty) return {'profile': null};
    try {
      final publicResponse = await api.get(
        '/api/organization/teacher-profiles/me',
        refresh: true,
      );
      final publicRoot = publicResponse is Map ? publicResponse : const {};
      final publicProfile = publicRoot['profile'] is Map
          ? Map<String, dynamic>.from(publicRoot['profile'] as Map)
          : <String, dynamic>{};
      return {
        'profile': {
          ...privateProfile,
          ...publicProfile,
          // Merge both authenticated sources. Older accounts may keep their
          // additional contacts on either the user document or teacher
          // profile, so replacing one list with the other loses saved data.
          'whatsappNumber':
              '${publicProfile['whatsappNumber'] ?? publicProfile['whatsapp'] ?? privateProfile['whatsappNumber'] ?? privateProfile['whatsapp'] ?? ''}',
          'phones': <String>{
            ..._contactStrings(privateProfile['phones']),
            ..._contactStrings(privateProfile['otherPhones']),
            ..._contactStrings(privateProfile['otherPhoneNumbers']),
            ..._contactStrings(publicProfile['phones']),
            ..._contactStrings(publicProfile['otherPhones']),
            ..._contactStrings(publicProfile['otherPhoneNumbers']),
          }.toList(),
          'emails': <String>{
            ..._contactStrings(privateProfile['emails']),
            ..._contactStrings(privateProfile['otherEmails']),
            ..._contactStrings(privateProfile['otherEmailAddresses']),
            ..._contactStrings(publicProfile['emails']),
            ..._contactStrings(publicProfile['otherEmails']),
            ..._contactStrings(publicProfile['otherEmailAddresses']),
          }.toList(),
          if ('${publicProfile['imageUrl'] ?? ''}'.isNotEmpty &&
              '${privateProfile['profileImageUrl'] ?? ''}'.isEmpty)
            'profileImageUrl': publicProfile['imageUrl'],
        }
      };
    } on ApiException catch (error) {
      if (error.statusCode != 404 && error.statusCode != 403) rethrow;
      return {'profile': privateProfile};
    }
  }

  static List<String> _contactStrings(dynamic value) {
    final values = value is List
        ? value
        : value is String
            ? value.split(RegExp(r'[,;\n]'))
            : const <dynamic>[];
    return values
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<dynamic> saveProfile(Map<String, dynamic> data) =>
      api.put('/api/organization/teacher-profiles/me', body: data);
  Future<dynamic> saveTeacherContacts(Map<String, dynamic> data) =>
      api.put('/api/organization/teacher-contacts/me', body: data);
  Future<dynamic> requestPrimaryProfileChange(Map<String, dynamic> data) =>
      api.post('/api/organization/teacher-profile-change-requests', body: data);
  Future<dynamic> teacherUrlAvailability(String slug) => api.get(
        '/api/organization/teacher-url/availability',
        query: {'slug': slug},
        refresh: true,
      );
  Future<dynamic> saveTeacherUrl(String slug) =>
      api.put('/api/organization/teacher-url/me', body: {'slug': slug});

  Future<dynamic> batches() => api.get('/api/classroom/batches');
  Future<dynamic> createBatch(Map<String, dynamic> data) =>
      api.post('/api/classroom/batches', body: data);
  Future<dynamic> updateBatch(String id, Map<String, dynamic> data) =>
      api.patch('/api/classroom/batches/$id', body: data);
  Future<dynamic> deleteBatch(String id) =>
      api.delete('/api/classroom/batches/$id');
  Future<dynamic> startClassSession(String id, {String? classDate}) =>
      api.post('/api/classroom/batches/$id/class-session/start', body: {
        if (classDate != null) 'classDate': classDate,
      });
  Future<dynamic> endClassSession(String id, {String? classDate}) =>
      api.post('/api/classroom/batches/$id/class-session/end', body: {
        if (classDate != null) 'classDate': classDate,
      });
  Future<dynamic> classSchedule(String from, String to) => api.get(
        '/api/classroom/class-schedule',
        query: {'from': from, 'to': to},
        refresh: true,
      );
  Future<dynamic> saveClassScheduleOverride(
          String batchId, Map<String, dynamic> data) =>
      api.put('/api/classroom/batches/$batchId/class-schedule/override',
          body: data);
  Future<dynamic> batchContent(String batchId) =>
      api.get('/api/classroom/batches/$batchId/content');
  Future<dynamic> createBatchContent(
          String batchId, Map<String, dynamic> data) =>
      api.post('/api/classroom/batches/$batchId/content', body: data);
  Future<dynamic> updateBatchContent(
          String batchId, String contentId, Map<String, dynamic> data) =>
      api.patch('/api/classroom/batches/$batchId/content/$contentId',
          body: data);
  Future<dynamic> deleteBatchContent(String batchId, String contentId) =>
      api.delete('/api/classroom/batches/$batchId/content/$contentId');

  Future<dynamic> students() => api.get('/api/users/teacher-students');
  Future<dynamic> pendingStudents() =>
      api.get('/api/users/teacher-student-requests');
  Future<dynamic> approveStudent(String uid) =>
      api.post('/api/users/students/$uid/teacher-access');
  Future<dynamic> updateStudent(String uid, Map<String, dynamic> data) =>
      api.patch('/api/organization/students/$uid/payment-profile', body: data);
  Future<dynamic> assignStudent(String uid, String batchId, String batchName) =>
      api.post('/api/users/$uid/batches/$batchId',
          body: {'batchName': batchName});
  Future<dynamic> createResultSheet(
          String batchId, Map<String, dynamic> data) =>
      api.post('/api/classroom/batches/$batchId/result-sheets', body: data);

  Future<dynamic> getAttendance(
          String batchId, String classType, String date) =>
      api.get('/api/classroom/batches/$batchId/attendance',
          query: {'classType': classType, 'date': date});
  Future<dynamic> saveAttendance(String batchId, Map<String, dynamic> data) =>
      api.put('/api/classroom/batches/$batchId/attendance', body: data);
  Future<dynamic> markQrAttendance(String token, Map<String, dynamic> data) =>
      api.post('/api/qr/attendance/$token', body: data);
  Future<dynamic> batchQrCards(String batchId, {bool refresh = false}) =>
      api.get('/api/qr/batch/${Uri.encodeComponent(batchId)}/cards',
          refresh: refresh);

  Future<dynamic> assignments() =>
      api.get('/api/classroom/assignment-submissions');
  Future<dynamic> messages() => api.get('/api/messages/conversations');
  Future<dynamic> conversation(String studentUid) =>
      api.get('/api/messages/conversations/$studentUid/messages');
  Future<dynamic> sendMessage(String studentUid, Map<String, dynamic> data) =>
      api.post('/api/messages/conversations/$studentUid/messages', body: data);
  Future<dynamic> editMessage(
          String studentUid, String messageId, String text) =>
      api.patch('/api/messages/conversations/$studentUid/messages/$messageId',
          body: {'text': text});
  Future<dynamic> deleteMessage(String studentUid, String messageId) =>
      api.delete('/api/messages/conversations/$studentUid/messages/$messageId');

  Future<dynamic> notifications({bool refresh = false}) =>
      api.get('/api/notifications', refresh: refresh);
  Future<dynamic> registerPushToken(String token) =>
      api.post('/api/notifications/devices',
          body: {'token': token, 'platform': 'android'});
  Future<dynamic> markNotificationRead(String id) =>
      api.patch('/api/notifications/${Uri.encodeComponent(id)}/read');
  Future<dynamic> markAllNotificationsRead() =>
      api.patch('/api/notifications/read-all');
  Future<dynamic> markAllMessagesRead() => api.patch('/api/messages/read-all');
  Future<dynamic> notificationPreferences() =>
      api.get('/api/notifications/preferences');
  Future<dynamic> saveNotificationPreferences(Map<String, dynamic> data) =>
      api.put('/api/notifications/preferences', body: data);
  Future<dynamic> reminders({bool history = false, bool refresh = false}) => api
      .get('/api/reminders', query: {'history': '$history'}, refresh: refresh);
  Future<dynamic> createReminder(Map<String, dynamic> data) =>
      api.post('/api/reminders', body: data);
  Future<dynamic> updateReminder(String id, Map<String, dynamic> data) =>
      api.put('/api/reminders/${Uri.encodeComponent(id)}', body: data);
  Future<dynamic> deleteReminder(String id) =>
      api.delete('/api/reminders/${Uri.encodeComponent(id)}');
  Future<dynamic> snoozeReminder(String id) =>
      api.post('/api/reminders/${Uri.encodeComponent(id)}/snooze');
  Future<dynamic> dismissReminder(String id) =>
      api.post('/api/reminders/${Uri.encodeComponent(id)}/dismiss');
  Future<dynamic> reports([Map<String, String>? query]) =>
      api.get('/api/reports', query: query);
  Future<dynamic> batchPaymentRegister(int year, int month) =>
      reports({'year': '$year', 'month': '$month'});
  Future<dynamic> markBatchPayment(
          String batchId, String studentUid, String date) =>
      api.post('/api/qr/payments', body: {
        'batchId': batchId,
        'studentUid': studentUid,
        'date': date,
      });
  Future<dynamic> payments(String instituteId, int year, int month) => api.get(
      '/api/organization/payments',
      query: {'instituteId': instituteId, 'year': '$year', 'month': '$month'});
  Future<dynamic> savePayment(String studentUid, Map<String, dynamic> data) =>
      api.put('/api/organization/payments/$studentUid', body: data);

  Future<dynamic> curriculum() => api.get('/api/curriculum');
  Future<dynamic> createCurriculum(Map<String, dynamic> data) =>
      api.post('/api/curriculum', body: data);
  Future<dynamic> updateCurriculum(String id, Map<String, dynamic> data) =>
      api.put('/api/curriculum/$id', body: data);
  Future<dynamic> deleteCurriculum(String id) =>
      api.delete('/api/curriculum/$id');

  Future<dynamic> dashboardContent() => api.get('/api/dashboard-content');
  Future<dynamic> createDashboardContent(Map<String, dynamic> data) =>
      api.post('/api/dashboard-content', body: data);
  Future<dynamic> updateDashboardContent(
          String id, Map<String, dynamic> data) =>
      api.patch('/api/dashboard-content/$id', body: data);
  Future<dynamic> deleteDashboardContent(String id) =>
      api.delete('/api/dashboard-content/$id');

  Future<dynamic> appSettings({bool refresh = false}) async {
    try {
      return await api.get('/api/settings', refresh: refresh);
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      return {
        'settings': {
          'appName': 'm.teacher',
          'subjectName': 'ICT',
          'logoUrl': '',
          'classTypes': [
            'ICT Theory',
            'Paper Class',
            'ICT Practical',
            'Revision'
          ],
          'teacherGrades': List.generate(13, (index) => 'Grade ${index + 1}'),
        }
      };
    }
  }

  Future<dynamic> teacherPlans() async {
    try {
      return await api.get('/api/subscriptions/teacher-plans', refresh: true);
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      try {
        final response = await api.get('/api/settings', refresh: true);
        final root = response is Map ? response : const {};
        final settings =
            root['settings'] is Map ? root['settings'] as Map : const {};
        final deployment = settings['deployment'] is Map
            ? settings['deployment'] as Map
            : const {};
        final configured = deployment['teacherSubscriptionPlans'] is Map
            ? deployment['teacherSubscriptionPlans'] as Map
            : const {};
        return {
          'plans': _defaultTeacherPlans.map((plan) {
            final prices = configured[plan['id']];
            return {
              ...plan,
              if (prices is Map) ...Map<String, dynamic>.from(prices),
            };
          }).toList(),
        };
      } catch (_) {
        return {'plans': _defaultTeacherPlans};
      }
    }
  }

  Future<dynamic> teacherSubscription() async {
    try {
      return await api.get('/api/subscriptions/teacher/me', refresh: true);
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      return {'subscription': null, 'teacher': const {}};
    }
  }

  Future<dynamic> submitTeacherSubscription(Map<String, dynamic> data) =>
      api.post('/api/subscriptions/teacher/submit', body: data);
  Future<dynamic> registerTeacher(Map<String, dynamic> data) async {
    const paths = [
      '/api/users/staff-registration',
      '/api/user/staff-registration',
      '/api/users/teacher-registration',
      '/api/user/teacher-registration',
      '/api/users/register-teacher',
    ];
    ApiException? lastError;
    for (final path in paths) {
      try {
        return await api.post(path, body: data);
      } on ApiException catch (error) {
        if (error.statusCode != 404) rethrow;
        lastError = error;
      }
    }
    throw ApiException(
      'Teacher registration is unavailable on this backend. Restart or deploy the backend connected to this app.',
      statusCode: lastError?.statusCode,
    );
  }

  Future<Map<String, dynamic>> uploadTeacherVerification(File file) async {
    try {
      return await api.uploadRaw(
          '/api/users/teacher-registration-upload', file);
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      try {
        return await api.uploadRaw('/api/users/teacher-upload', file);
      } on ApiException catch (legacyError) {
        if (legacyError.statusCode != 404) rethrow;
        return _uploadTeacherVerificationToStorage(file);
      }
    }
  }

  Future<Map<String, dynamic>> _uploadTeacherVerificationToStorage(
      File file) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw ApiException('Sign in before uploading NIC images');
    final originalName = file.path.split(Platform.pathSeparator).last;
    final safeName = originalName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '-');
    final fileName = '${DateTime.now().millisecondsSinceEpoch}-$safeName';
    final reference =
        FirebaseStorage.instance.ref('teacher-verification/$uid/$fileName');
    await reference.putFile(file);
    return {
      'url': await reference.getDownloadURL(),
      'fileName': fileName,
    };
  }

  Future<dynamic> helpVideos() => api.get('/api/support/help-videos');
  Future<dynamic> supportMessages({bool refresh = false}) =>
      api.get('/api/support/me/messages', refresh: refresh);
  Future<dynamic> sendSupportMessage(String text) async {
    final paths = <String>[
      '/api/support/me/messages',
      '/api/support/contact-admin',
      '/api/support/me/contact-admin',
    ];
    ApiException? lastError;
    for (final path in paths) {
      try {
        return await api.post(path, body: {'text': text});
      } on ApiException catch (error) {
        lastError = error;
        if (error.statusCode != 404) rethrow;
      }
    }
    throw lastError ?? ApiException('Administrator messaging is unavailable.');
  }

  Future<dynamic> saveTeacherPortalSettings(Map<String, dynamic> data) =>
      api.put('/api/settings/teacher-portal', body: data);
  Future<dynamic> saveTeacherSetupSettings(Map<String, dynamic> data) =>
      api.put('/api/settings/teacher-portal/setup', body: data);
  Future<dynamic> teacherPortalSettings() =>
      api.get('/api/settings/teacher-portal', refresh: true);
  Future<dynamic> checkStudentIdPrefix(String prefix) =>
      api.get('/api/settings/teacher-prefix-availability',
          query: {'prefix': prefix}, refresh: true);

  Future<dynamic> ownerWorkspace() =>
      api.get('/api/subscriptions/owner-workspace');
  Future<dynamic> createInstituteInvitation(Map<String, dynamic> data) =>
      api.post('/api/subscriptions/owner/invitations', body: data);
  Future<dynamic> switchWorkspace(String workspaceId) =>
      api.post('/api/subscriptions/owner/switch-workspace',
          body: {'workspaceId': workspaceId});
  Future<dynamic> removeInstituteTeacher(
          String instituteId, String teacherUid) =>
      api.delete(
          '/api/subscriptions/owner/partners/$teacherUid?instituteId=${Uri.encodeQueryComponent(instituteId)}');
  Future<dynamic> invitations() => api.get('/api/subscriptions/invitations/me');
  Future<dynamic> respondInvitation(String id, bool accept) =>
      api.post('/api/subscriptions/invitations/$id/respond',
          body: {'accept': accept});

  Future<Map<String, dynamic>> uploadFile(File file) =>
      api.uploadRaw('/api/classroom/uploads', file);

  Stream<String> liveUpdates() => api.liveUpdates();

  Future<void> _ignore(Future<dynamic> request) async {
    try {
      await request;
    } catch (_) {}
  }

  Future<void> warmStartupData() async {
    await clearCache();
    final now = DateTime.now();
    String date(DateTime value) =>
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final batchResponse =
        await batches().catchError((_) => <String, dynamic>{});
    await Future.wait([
      _ignore(dashboard()),
      _ignore(students()),
      _ignore(pendingStudents()),
      _ignore(assignments()),
      _ignore(messages()),
      _ignore(notifications(refresh: true)),
      _ignore(reminders(refresh: true)),
      _ignore(curriculum()),
      _ignore(dashboardContent()),
      _ignore(appSettings()),
      _ignore(teacherSubscription()),
      _ignore(supportMessages(refresh: true)),
      _ignore(classSchedule(date(now.subtract(const Duration(days: 30))),
          date(now.add(const Duration(days: 90))))),
    ]);
    final root = batchResponse is Map ? batchResponse : const {};
    final items = root['batches'] is List ? root['batches'] as List : const [];
    await Future.wait(items.whereType<Map>().map((batch) {
      final id = '${batch['id'] ?? ''}';
      return id.isEmpty ? Future<void>.value() : _ignore(batchContent(id));
    }));
  }

  Future<void> prefetchForUpdate(String path) async {
    await clearCache();
    if (path.startsWith('/api/classroom/batches')) {
      await Future.wait([_ignore(dashboard()), _ignore(batches())]);
    } else if (path.startsWith('/api/messages')) {
      await Future.wait([_ignore(dashboard()), _ignore(messages())]);
    } else if (path.startsWith('/api/notifications')) {
      await _ignore(notifications(refresh: true));
    } else if (path.startsWith('/api/curriculum')) {
      await _ignore(curriculum());
    } else if (path.startsWith('/api/dashboard-content')) {
      await Future.wait([_ignore(dashboard()), _ignore(dashboardContent())]);
    } else {
      await _ignore(dashboard());
    }
  }
}
