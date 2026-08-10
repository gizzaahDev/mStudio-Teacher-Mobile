import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'teacher_repository.dart';

class SessionController extends ChangeNotifier {
  SessionController() : repository = TeacherRepository(ApiClient());

  final TeacherRepository repository;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  User? get user => FirebaseAuth.instance.currentUser;
  bool loading = false;
  String? error;
  Map<String, dynamic>? profile;
  String? _bootstrappedUid;
  bool bootstrapped = false;
  int _contentRevision = 0;

  int get contentRevision => _contentRevision;

  void markContentChanged() {
    _contentRevision += 1;
    notifyListeners();
  }

  String _profileKey(String uid) => 'teacher_profile_cache_$uid';

  Future<void> bootstrap() async {
    final activeUser = user;
    if (activeUser == null || _bootstrappedUid == activeUser.uid) return;
    _bootstrappedUid = activeUser.uid;
    bootstrapped = false;
    loading = true;
    error = null;
    notifyListeners();

    try {
      final cached = await _storage.read(key: _profileKey(activeUser.uid)) ??
          await _storage.read(key: 'teacher_profile_cache');
      if (cached != null) {
        profile = (jsonDecode(cached) as Map).cast<String, dynamic>();
        notifyListeners();
      }
      await _storage.write(
        key: 'teacher_logged_in_uid',
        value: activeUser.uid,
      );
    } catch (_) {
      // A malformed legacy cache is ignored and replaced once data is loaded.
    }

    // Keep normal startup cache-first, but pending registrations and legacy
    // approved profiles without a teacher ID must be checked immediately.
    final teacherId =
        '${profile?['teacherPublicId'] ?? profile?['teacherCode'] ?? profile?['teacherId'] ?? ''}'
            .trim();
    final needsApprovalRefresh = profile?['status'] != 'approved';
    final needsTeacherIdRepair =
        profile?['role'] == 'teacher' && teacherId.isEmpty;
    if (profile == null || needsApprovalRefresh || needsTeacherIdRepair) {
      await refreshProfile(forceNetwork: profile != null);
    }
    bootstrapped = true;
    loading = false;
    notifyListeners();
    if (profile?['status'] == 'approved') {
      unawaited(repository
          .warmStartupData()
          .then((_) => markContentChanged())
          .catchError((_) {}));
    }
  }

  Future<void> refreshProfile({bool forceNetwork = true}) async {
    final activeUser = user;
    if (activeUser == null) return;

    loading = true;
    error = null;
    notifyListeners();
    try {
      if (forceNetwork) await repository.clearCache();
      final response = await repository.profile();
      final value = response is Map ? response['profile'] : null;
      profile = value is Map ? value.cast<String, dynamic>() : null;
      await _storage.write(
        key: _profileKey(activeUser.uid),
        value: jsonEncode(profile),
      );
      await _storage.delete(key: 'teacher_profile_cache');
    } catch (exception) {
      error = '$exception';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    final uid = user?.uid;
    await repository.clearCache();
    if (uid != null) await _storage.delete(key: _profileKey(uid));
    await _storage.delete(key: 'teacher_profile_cache');
    await _storage.delete(key: 'teacher_logged_in_uid');
    profile = null;
    _bootstrappedUid = null;
    bootstrapped = false;
    await FirebaseAuth.instance.signOut();
    notifyListeners();
  }
}
