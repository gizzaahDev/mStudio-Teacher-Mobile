import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/app_theme.dart';
import '../../core/session.dart';
import '../../localization/app_locale.dart';
import 'teacher_pages.dart';

enum TeacherPage {
  dashboard,
  classes,
  students,
  attendance,
  qr,
  manageBatches,
  assignments,
  messages,
  reports,
  calendar,
  payments,
  curriculum,
  quotes,
  institute,
  profile,
  notifications,
  stManage,
  subscription,
  help,
  settings,
  about,
}

const _navigation = <({TeacherPage page, String label, IconData icon})>[
  (
    page: TeacherPage.dashboard,
    label: 'Dashboard',
    icon: Icons.dashboard_outlined
  ),
  (
    page: TeacherPage.classes,
    label: 'Classes & batches',
    icon: Icons.class_outlined
  ),
  (
    page: TeacherPage.manageBatches,
    label: 'My learning space',
    icon: Icons.space_dashboard_outlined
  ),
  (page: TeacherPage.students, label: 'Students', icon: Icons.groups_outlined),
  (
    page: TeacherPage.attendance,
    label: 'Attendance',
    icon: Icons.how_to_reg_outlined
  ),
  (
    page: TeacherPage.qr,
    label: 'QR quick attendance',
    icon: Icons.qr_code_scanner_outlined
  ),
  (
    page: TeacherPage.assignments,
    label: 'Assignments & quizzes',
    icon: Icons.assignment_outlined
  ),
  (
    page: TeacherPage.messages,
    label: 'Messages',
    icon: Icons.chat_bubble_outline
  ),
  (
    page: TeacherPage.curriculum,
    label: 'Curriculum',
    icon: Icons.menu_book_outlined
  ),
  (page: TeacherPage.reports, label: 'Reports', icon: Icons.analytics_outlined),
  (
    page: TeacherPage.calendar,
    label: 'Calendar',
    icon: Icons.calendar_month_outlined
  ),
  (
    page: TeacherPage.payments,
    label: 'Payments',
    icon: Icons.payments_outlined
  ),
  (
    page: TeacherPage.quotes,
    label: 'Quotes & notices',
    icon: Icons.campaign_outlined
  ),
  (
    page: TeacherPage.notifications,
    label: 'Notifications',
    icon: Icons.notifications_outlined
  ),
  (
    page: TeacherPage.profile,
    label: 'My profile',
    icon: Icons.account_circle_outlined
  ),
  (page: TeacherPage.stManage, label: 'ST Manage', icon: Icons.tune_outlined),
  (
    page: TeacherPage.subscription,
    label: 'Subscription plans',
    icon: Icons.workspace_premium_outlined
  ),
  (
    page: TeacherPage.help,
    label: 'Help & admin support',
    icon: Icons.help_outline_rounded
  ),
  (
    page: TeacherPage.settings,
    label: 'Settings',
    icon: Icons.settings_outlined
  ),
  (page: TeacherPage.about, label: 'About', icon: Icons.info_outline_rounded),
];

class TeacherShell extends StatefulWidget {
  const TeacherShell({
    super.key,
    required this.session,
    required this.themeController,
  });

  final SessionController session;
  final AppThemeController themeController;

  @override
  State<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends State<TeacherShell> {
  TeacherPage _page = TeacherPage.dashboard;
  final Map<TeacherPage, Widget> _openedPages = {};
  String _logoUrl = '';
  Map<String, dynamic>? _subscription;
  StreamSubscription<String>? _liveUpdates;
  final ScrollController _drawerScrollController = ScrollController();
  TeacherPage? _drawerPageAtLastOpen;
  bool _setupIncomplete = false;
  bool _setupStatusLoaded = false;
  bool _setupGuideOpen = false;
  bool _helpIntroScheduled = false;
  int _unreadMessages = 0;
  int _unreadNotifications = 0;
  static const _guideStorage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadBranding();
    _loadSubscription();
    _loadUnreadCounts();
    _connectLiveUpdates();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final maintenanceActive = await _checkMaintenance();
        if (!maintenanceActive && mounted) {
          unawaited(_initializeEntryFlow());
        }
      }
    });
  }

  Future<void> _loadUnreadCounts() async {
    try {
      final responses = await Future.wait([
        widget.session.repository.dashboard(),
        widget.session.repository.notifications(refresh: true),
      ]);
      final dashboard = responses[0] is Map ? responses[0] as Map : const {};
      final summary =
          dashboard['summary'] is Map ? dashboard['summary'] as Map : dashboard;
      final notificationRoot =
          responses[1] is Map ? responses[1] as Map : const {};
      final notifications = notificationRoot['notifications'] is List
          ? notificationRoot['notifications'] as List
          : const [];
      if (mounted) {
        setState(() {
          _unreadMessages = _page == TeacherPage.messages
              ? 0
              : (summary['unreadMessages'] as num?)?.toInt() ?? 0;
          _unreadNotifications = _page == TeacherPage.notifications
              ? 0
              : notifications
                  .where((item) => item is Map && item['readAt'] == null)
                  .length;
        });
      }
    } catch (_) {}
  }

  Future<bool> _checkMaintenance() async {
    try {
      final response =
          await widget.session.repository.appSettings(refresh: true);
      final root = response is Map ? response : const {};
      final settings = root['settings'] is Map ? root['settings'] as Map : root;
      final maintenance = settings['maintenance'] is Map
          ? settings['maintenance'] as Map
          : const {};
      final schedule = maintenance['teacher'] is Map
          ? maintenance['teacher'] as Map
          : const {};
      if (schedule['enabled'] != true || !mounted) return false;
      final start = DateTime.tryParse('${schedule['startsAt'] ?? ''}');
      final end = DateTime.tryParse('${schedule['endsAt'] ?? ''}');
      // The Admin toggle is authoritative. Dates are displayed information;
      // Admin explicitly restores access by switching maintenance off.
      unawaited(showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: Dialog.fullscreen(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.build_circle_rounded,
                              size: 76,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 18),
                          Text('System maintenance',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          const Text('Teacher app is temporarily unavailable',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          const Text(
                            'Sorry for the inconvenience. We are improving the system and will restore access as soon as possible.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text('${schedule['reason'] ?? 'We are improving the system.'}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 18),
                          if (start != null)
                            Text('Starts: ${start.toLocal()}'),
                          if (end != null)
                            Text('Expected end: ${end.toLocal()}'),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _initializeEntryFlow() async {
    await _showSetupGuide();
    if (!mounted) return;
    if (!_setupIncomplete) {
      await _showHelpIntroduction();
    }
  }

  Future<void> _showHelpIntroduction() async {
    if (_helpIntroScheduled) return;
    _helpIntroScheduled = true;
    final uid = widget.session.user?.uid ?? 'teacher';
    final key = 'teacher_help_introduction_v1_$uid';
    if (await _guideStorage.read(key: key) == 'yes' || !mounted) return;
    final follow = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.ondemand_video_rounded),
        title: const Text('Need help using m.teacher?'),
        content: const Text(
          'For detailed guidance, follow the complete video series in Help & admin support.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.play_circle_outline_rounded),
            label: const Text('Follow guidance'),
          ),
        ],
      ),
    );
    await _guideStorage.write(key: key, value: 'yes');
    if (follow == true && mounted) _open(TeacherPage.help);
  }

  String get _setupBannerStorageKey =>
      'teacher_setup_banner_hidden_until_${widget.session.user?.uid ?? 'teacher'}';

  String get _setupCompleteStorageKey =>
      'teacher_setup_completed_${widget.session.user?.uid ?? 'teacher'}';

  Future<void> _rememberSetupComplete([Map<String, dynamic>? profile]) async {
    await _guideStorage.write(key: _setupCompleteStorageKey, value: 'yes');
    await _guideStorage.delete(key: _setupBannerStorageKey);
    if (mounted) {
      setState(() {
        _setupIncomplete = false;
        _setupStatusLoaded = true;
      });
    }
    if (profile != null && profile['setupCompleted'] != true) {
      try {
        final payload = Map<String, dynamic>.from(profile)
          ..['setupCompleted'] = true;
        await widget.session.repository.saveProfile(payload);
        await widget.session.refreshProfile(forceNetwork: true);
      } catch (_) {
        // The device flag still prevents a completed setup from reappearing
        // while an older backend version is being upgraded.
      }
    }
  }

  String _guideText(String english, String sinhala, String tamil) =>
      switch (appLocale.code) { 'si' => sinhala, 'ta' => tamil, _ => english };

  // Kept for accounts that may still use the earlier guided-setup entry point.
  // ignore: unused_element
  Future<void> _runFirstUseGuide() async {
    final uid = widget.session.user?.uid ?? 'teacher';
    final tourKey = 'teacher_full_tour_seen_$uid';
    if (await _guideStorage.read(key: tourKey) != 'yes' && mounted) {
      var page = 0;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) {
            final pages = [
              (
                Icons.school_rounded,
                _guideText(
                    'Welcome to m.teacher',
                    'm.teacher වෙත සාදරයෙන් පිළිගනිමු',
                    'm.teacher-க்கு வரவேற்கிறோம்'),
                _guideText(
                    'Manage your profile, students, batches and learning spaces from one app.',
                    'ඔබගේ පැතිකඩ, සිසුන්, පන්ති සහ ඉගෙනුම් අවකාශ එකම යෙදුමකින් කළමනාකරණය කරන්න.',
                    'உங்கள் சுயவிவரம், மாணவர்கள், வகுப்புகள் மற்றும் கற்றல் இடங்களை ஒரே செயலியில் நிர்வகிக்கவும்.')
              ),
              (
                Icons.account_circle_rounded,
                _guideText('Complete My Profile', 'මගේ පැතිකඩ සම්පූර්ණ කරන්න',
                    'என் சுயவிவரத்தை நிறைவு செய்யவும்'),
                _guideText(
                    'Add your phone, WhatsApp, teaching grades, subjects, class types and result categories.',
                    'දුරකථන අංකය, WhatsApp, ශ්‍රේණි, විෂයයන්, පන්ති වර්ග සහ ප්‍රතිඵල කාණ්ඩ එක් කරන්න.',
                    'தொலைபேசி, WhatsApp, வகுப்புகள், பாடங்கள், வகுப்பு வகைகள் மற்றும் முடிவு பிரிவுகளைச் சேர்க்கவும்.')
              ),
              (
                Icons.tune_rounded,
                _guideText('Configure ST Manage', 'ST Manage සකසන්න',
                    'ST Manage-ஐ அமைக்கவும்'),
                _guideText(
                    'Set the main subject, a unique student ID prefix, reception details and student app options.',
                    'ප්‍රධාන විෂයය, අනන්‍ය ශිෂ්‍ය ID උපසර්ගය, පිළිගැනීමේ තොරතුරු සහ ශිෂ්‍ය යෙදුම් විකල්ප සකසන්න.',
                    'முதன்மை பாடம், தனித்துவமான மாணவர் ID முன்னொட்டு, வரவேற்பு விவரங்கள் மற்றும் மாணவர் செயலி விருப்பங்களை அமைக்கவும்.')
              ),
              (
                Icons.class_rounded,
                _guideText('Create your first class', 'ඔබගේ පළමු පන්තිය සාදන්න',
                    'உங்கள் முதல் வகுப்பை உருவாக்கவும்'),
                _guideText(
                    'After profile and ST Manage are complete, create at least one class and batch.',
                    'පැතිකඩ සහ ST Manage සම්පූර්ණ කළ පසු අවම වශයෙන් එක් පන්තියක් සහ කණ්ඩායමක් සාදන්න.',
                    'சுயவிவரம் மற்றும் ST Manage முடிந்ததும் குறைந்தது ஒரு வகுப்பு மற்றும் batch உருவாக்கவும்.')
              ),
            ];
            final item = pages[page];
            return AlertDialog(
              title: Row(children: [
                Expanded(child: Text(item.$2)),
                PopupMenuButton<String>(
                    icon: const Icon(Icons.translate_rounded),
                    onSelected: (value) async {
                      await appLocale.setLanguage(value);
                      update(() {});
                    },
                    itemBuilder: (_) => const [
                          PopupMenuItem(value: 'en', child: Text('English')),
                          PopupMenuItem(value: 'si', child: Text('සිංහල')),
                          PopupMenuItem(value: 'ta', child: Text('தமிழ்'))
                        ])
              ]),
              content: SizedBox(
                  width: 440,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(item.$1,
                        size: 64, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 18),
                    Text(item.$3, textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    Text('${page + 1} / ${pages.length}')
                  ])),
              actions: [
                if (page > 0)
                  TextButton(
                      onPressed: () => update(() => page--),
                      child: Text(_guideText('Back', 'ආපසු', 'பின்'))),
                FilledButton(
                    onPressed: () {
                      if (page < pages.length - 1) {
                        update(() => page++);
                      } else {
                        Navigator.pop(dialogContext);
                      }
                    },
                    child: Text(page < pages.length - 1
                        ? _guideText('Next', 'ඊළඟ', 'அடுத்து')
                        : _guideText('Start setup', 'සැකසීම අරඹන්න',
                            'அமைப்பைத் தொடங்கு'))),
              ],
            );
          },
        ),
      );
      await _guideStorage.write(key: tourKey, value: 'yes');
    }
    if (mounted) await _showSetupGuide();
  }

  Future<void> _showSetupGuide() async {
    if (_setupGuideOpen) return;
    setState(() => _setupGuideOpen = true);
    try {
      final responses = await Future.wait([
        widget.session.repository.teacherPortalSettings(),
        widget.session.repository.batches(),
        widget.session.repository.profile(),
      ]);
      if (!mounted) return;
      final profileRoot = responses[2] is Map ? responses[2] as Map : const {};
      final profile = profileRoot['profile'] is Map
          ? profileRoot['profile'] as Map
          : const <String, dynamic>{};
      final settingsRoot = responses[0] is Map ? responses[0] as Map : const {};
      final settings = settingsRoot['settings'] is Map
          ? settingsRoot['settings'] as Map
          : settingsRoot;
      final batchRoot = responses[1] is Map ? responses[1] as Map : const {};
      final batches = batchRoot['batches'] is List
          ? batchRoot['batches'] as List
          : const [];
      bool filled(Object? value) => '$value'.trim().isNotEmpty;
      bool listFilled(Object? value) => value is List && value.isNotEmpty;
      final profileDone =
          filled(profile['phone']) && filled(profile['whatsappNumber']);
      final stDone = filled(settings['idPrefix']) &&
          listFilled(profile['subjects']) &&
          listFilled(profile['grades']) &&
          listFilled(profile['classTypes']) &&
          listFilled(profile['resultCategories']) &&
          settings['reception'] is Map &&
          listFilled((settings['reception'] as Map)['institutions']);
      final classDone = batches.isNotEmpty;
      final incomplete = !(profileDone && stDone && classDone);
      if (incomplete) {
        await _guideStorage.delete(key: _setupCompleteStorageKey);
      }
      if (mounted) {
        setState(() {
          _setupIncomplete = incomplete;
          _setupStatusLoaded = true;
        });
      }
      if (!incomplete) {
        await _rememberSetupComplete(Map<String, dynamic>.from(profile));
        return;
      }
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Expanded(
                        child: Text(
                            _guideText(
                                'Complete teacher setup',
                                'ගුරු සැකසීම සම්පූර්ණ කරන්න',
                                'ஆசிரியர் அமைப்பை நிறைவு செய்யவும்'),
                            style: Theme.of(context).textTheme.titleLarge)),
                    PopupMenuButton<String>(
                        icon: const Icon(Icons.translate_rounded),
                        onSelected: appLocale.setLanguage,
                        itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: 'en', child: Text('English')),
                              PopupMenuItem(value: 'si', child: Text('සිංහල')),
                              PopupMenuItem(value: 'ta', child: Text('தமிழ்'))
                            ])
                  ]),
                  const SizedBox(height: 8),
                  ListTile(
                      leading: Icon(
                          profileDone
                              ? Icons.check_circle
                              : Icons.looks_one_rounded,
                          color: profileDone ? Colors.green : null),
                      title: Text(_guideText(
                          'Complete My Profile',
                          'මගේ පැතිකඩ සම්පූර්ණ කරන්න',
                          'என் சுயவிவரத்தை நிறைவு செய்யவும்')),
                      subtitle: Text(_guideText(
                          'Phone number and WhatsApp number.',
                          'දුරකථන, WhatsApp, ශ්‍රේණි, විෂය, පන්ති වර්ග සහ ප්‍රතිඵල.',
                          'தொலைபேசி, WhatsApp, வகுப்புகள், பாடங்கள், வகுப்பு வகைகள் மற்றும் முடிவுகள்.')),
                      onTap: profileDone
                          ? null
                          : () {
                              Navigator.pop(sheetContext);
                              _open(TeacherPage.profile);
                            }),
                  ListTile(
                      enabled: profileDone,
                      leading: Icon(
                          stDone ? Icons.check_circle : Icons.looks_two_rounded,
                          color: stDone ? Colors.green : null),
                      title: Text(_guideText('Configure ST Manage',
                          'ST Manage සකසන්න', 'ST Manage-ஐ அமைக்கவும்')),
                      subtitle: Text(_guideText(
                          'Select subjects, then configure grades, class types, results, institutes and student IDs.',
                          'ප්‍රධාන විෂයය, අනන්‍ය ID උපසර්ගය සහ පිළිගැනීම.',
                          'முதன்மை பாடம், தனித்துவமான ID முன்னொட்டு மற்றும் வரவேற்பு.')),
                      onTap: !profileDone || stDone
                          ? null
                          : () {
                              Navigator.pop(sheetContext);
                              _open(TeacherPage.stManage);
                            }),
                  ListTile(
                      enabled: profileDone && stDone,
                      leading: Icon(
                          classDone
                              ? Icons.check_circle
                              : Icons.looks_3_rounded,
                          color: classDone ? Colors.green : null),
                      title: Text(_guideText(
                          'Create a class and batch',
                          'පන්තියක් සහ කණ්ඩායමක් සාදන්න',
                          'ஒரு வகுப்பு மற்றும் batch உருவாக்கவும்')),
                      onTap: !profileDone || !stDone || classDone
                          ? null
                          : () {
                              Navigator.pop(sheetContext);
                              _open(TeacherPage.classes);
                            }),
                  Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: Text(_guideText('Continue later',
                              'පසුව කරගෙන යන්න', 'பின்னர் தொடரவும்')))),
                ]))),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _setupIncomplete = true;
          _setupStatusLoaded = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not load teacher setup: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _setupGuideOpen = false);
    }
  }

  void _keepSelectedDrawerItemVisible(bool opened) {
    if (!opened || _drawerPageAtLastOpen == _page) return;
    _drawerPageAtLastOpen = _page;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_drawerScrollController.hasClients) return;
      final index = _navigation.indexWhere((item) => item.page == _page);
      final target = (index * 55.0 - 120).clamp(
        0.0,
        _drawerScrollController.position.maxScrollExtent,
      );
      _drawerScrollController.animateTo(target,
          duration: const Duration(milliseconds: 240), curve: Curves.easeOut);
    });
  }

  Future<void> _refreshSetupStatus() async {
    try {
      final responses = await Future.wait([
        widget.session.repository.teacherPortalSettings(),
        widget.session.repository.batches(),
        widget.session.repository.profile(),
      ]);
      final profileRoot = responses[2] is Map ? responses[2] as Map : const {};
      final profile = profileRoot['profile'] is Map
          ? profileRoot['profile'] as Map
          : const <String, dynamic>{};
      final settingsRoot = responses[0] is Map ? responses[0] as Map : const {};
      final settings = settingsRoot['settings'] is Map
          ? settingsRoot['settings'] as Map
          : settingsRoot;
      final batchRoot = responses[1] is Map ? responses[1] as Map : const {};
      bool filled(Object? value) => '$value'.trim().isNotEmpty;
      bool listFilled(Object? value) => value is List && value.isNotEmpty;
      final complete = filled(profile['phone']) &&
          filled(profile['whatsappNumber']) &&
          filled(settings['idPrefix']) &&
          listFilled(profile['subjects']) &&
          listFilled(profile['grades']) &&
          listFilled(profile['classTypes']) &&
          listFilled(profile['resultCategories']) &&
          settings['reception'] is Map &&
          listFilled((settings['reception'] as Map)['institutions']) &&
          batchRoot['batches'] is List &&
          (batchRoot['batches'] as List).isNotEmpty;
      if (complete) {
        await _rememberSetupComplete(Map<String, dynamic>.from(profile));
      } else {
        await _guideStorage.delete(key: _setupCompleteStorageKey);
        if (mounted) {
          setState(() {
            _setupIncomplete = true;
            _setupStatusLoaded = true;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _setupIncomplete = true;
          _setupStatusLoaded = true;
        });
      }
    }
  }

  void _connectLiveUpdates() {
    _liveUpdates?.cancel();
    _liveUpdates = widget.session.repository.liveUpdates().listen((payload) {
      try {
        final event = jsonDecode(payload);
        final path = event is Map ? '${event['path'] ?? ''}' : '';
        if (path.isEmpty) return;
        if (path.startsWith('/api/messages') ||
            path.startsWith('/api/notifications')) {
          unawaited(_loadUnreadCounts());
        }
        if (path.startsWith('/api/subscriptions')) {
          unawaited(_loadSubscription());
        }
        unawaited(widget.session.repository.prefetchForUpdate(path).then((_) {
          if (!mounted) return;
          widget.session.markContentChanged();
          final keepActivePage = (_page == TeacherPage.stManage &&
                  (path.startsWith('/api/settings') ||
                      path.startsWith('/api/organization/teacher-profiles'))) ||
              (_page == TeacherPage.classes &&
                  path.startsWith('/api/classroom/batches'));
          if (!keepActivePage) setState(() => _openedPages.clear());
          if (path.startsWith('/api/classroom/batches') ||
              path.startsWith('/api/settings') ||
              path.startsWith('/api/users')) {
            unawaited(_refreshSetupStatus());
          }
        }));
      } catch (_) {}
    }, onError: (_) {
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) _connectLiveUpdates();
      });
    }, onDone: () {
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) _connectLiveUpdates();
      });
    });
  }

  @override
  void dispose() {
    _liveUpdates?.cancel();
    _drawerScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadBranding() async {
    try {
      final response = await widget.session.repository.appSettings();
      final root = response is Map ? response : const {};
      final settings = root['settings'] is Map ? root['settings'] as Map : root;
      widget.themeController
          .applyRemoteSettings(Map<String, dynamic>.from(settings));
      final logoUrl = '${settings['logoUrl'] ?? ''}'.trim();
      if (mounted && logoUrl != _logoUrl) setState(() => _logoUrl = logoUrl);
    } catch (_) {
      // Keep the bundled fallback logo while settings reconnect.
    }
  }

  Future<void> _loadSubscription() async {
    try {
      final response = await widget.session.repository.teacherSubscription();
      final root = response is Map ? response : const {};
      final value = root['subscription'];
      if (mounted) {
        setState(() => _subscription =
            value is Map ? Map<String, dynamic>.from(value) : null);
      }
    } catch (_) {}
  }

  String get _teacherId =>
      '${widget.session.profile?['teacherPublicId'] ?? widget.session.profile?['teacherCode'] ?? widget.session.profile?['teacherId'] ?? 'Teacher'}';

  String get _teacherName =>
      '${widget.session.profile?['displayName'] ?? widget.session.user?.displayName ?? 'Teacher'}';

  String? get _photoUrl => (widget.session.profile?['profileImageUrl'] ??
          widget.session.profile?['imageUrl'])
      ?.toString();

  Future<void> _copyTeacherId() async {
    await Clipboard.setData(ClipboardData(text: _teacherId));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Teacher ID copied')));
  }

  void _open(TeacherPage page) {
    final leavingSetup = _page == TeacherPage.stManage && page != _page;
    setState(() {
      _page = page;
      if (page == TeacherPage.messages) _unreadMessages = 0;
      if (page == TeacherPage.notifications) _unreadNotifications = 0;
    });
    if (page == TeacherPage.messages) {
      unawaited(widget.session.repository.markAllMessagesRead());
    }
    if (page == TeacherPage.notifications) {
      unawaited(widget.session.repository.markAllNotificationsRead());
    }
    if (leavingSetup) unawaited(_refreshSetupStatus());
  }

  Widget _pageBody() {
    _openedPages.putIfAbsent(
      _page,
      () => KeyedSubtree(
        key: PageStorageKey<TeacherPage>(_page),
        child: TeacherPageView(
          page: _page,
          session: widget.session,
          onNavigate: _open,
        ),
      ),
    );
    return Stack(
      children: _openedPages.entries
          .map(
            (entry) => Positioned.fill(
              child: Offstage(
                offstage: entry.key != _page,
                child: TickerMode(
                  enabled: entry.key == _page,
                  child: entry.value,
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  void _openFromDrawer(TeacherPage page) {
    Navigator.of(context).pop();
    _open(page);
  }

  Future<void> _showThemeChoices() async {
    await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final item in const [
                (ThemeMode.system, 'Device theme', Icons.brightness_auto),
                (ThemeMode.light, 'Light theme', Icons.light_mode_outlined),
                (ThemeMode.dark, 'Dark theme', Icons.dark_mode_outlined)
              ])
                RadioListTile<ThemeMode>(
                    value: item.$1,
                    groupValue: widget.themeController.mode,
                    secondary: Icon(item.$3),
                    title: Text(appLocale.tr(item.$2)),
                    onChanged: (value) {
                      if (value != null) widget.themeController.setMode(value);
                      Navigator.pop(context);
                    }),
            ])));
  }

  Future<void> _showLanguageChoices() async {
    await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final item in const [
                ('en', 'English'),
                ('si', 'Sinhala'),
                ('ta', 'Tamil')
              ])
                RadioListTile<String>(
                    value: item.$1,
                    groupValue: appLocale.code,
                    secondary: const Icon(Icons.translate_rounded),
                    title: Text(appLocale.tr(item.$2)),
                    onChanged: (value) {
                      if (value != null) appLocale.setLanguage(value);
                      Navigator.pop(context);
                    }),
            ])));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      onDrawerChanged: _keepSelectedDrawerItemVisible,
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 8,
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [scheme.primary, scheme.tertiary],
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: _logoUrl.isEmpty
                    ? Image.asset('assets/app_logo.png', fit: BoxFit.cover)
                    : Image.network(
                        _logoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset(
                            'assets/app_logo.png',
                            fit: BoxFit.cover),
                      ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appLocale.tr('Teacher'),
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Semantics(
                    button: true,
                    label: 'Copy teacher ID $_teacherId',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: _copyTeacherId,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                '$_teacherName · $_teacherId',
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.1,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Icon(Icons.copy_rounded,
                                size: 13, color: scheme.primary),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  _open(TeacherPage.settings);
                case 'profile':
                  _open(TeacherPage.profile);
                case 'theme':
                  _showThemeChoices();
                case 'help':
                  _open(TeacherPage.help);
                case 'translate':
                  _showLanguageChoices();
                case 'signout':
                  widget.session.signOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                  value: 'settings', child: Text(appLocale.tr('Settings'))),
              PopupMenuItem(
                  value: 'profile', child: Text(appLocale.tr('My Profile'))),
              PopupMenuItem(value: 'theme', child: Text(appLocale.tr('Theme'))),
              PopupMenuItem(value: 'help', child: Text(appLocale.tr('Help'))),
              PopupMenuItem(
                  value: 'translate', child: Text(appLocale.tr('Translate'))),
              const PopupMenuDivider(),
              PopupMenuItem(
                  value: 'signout', child: Text(appLocale.tr('Sign out'))),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary,
                      scheme.tertiary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: scheme.surface,
                      child: _photoUrl == null || _photoUrl!.isEmpty
                          ? const Icon(Icons.person_rounded, size: 32)
                          : Padding(
                              padding: const EdgeInsets.all(4),
                              child: ClipOval(
                                child: Image.network(
                                  _photoUrl!,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.person_rounded,
                                      size: 30),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appLocale.tr('Teacher'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Teacher · $_teacherId',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: .84),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  key: const PageStorageKey<String>('teacher-drawer-scroll'),
                  controller: _drawerScrollController,
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 12),
                  children: _navigation
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: ListTile(
                            selected: _page == item.page,
                            leading: Icon(item.icon),
                            title: Text(
                              appLocale.tr(item.label),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            onTap: () => _openFromDrawer(item.page),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity.abs() < 450) return;
          const pages = [
            TeacherPage.dashboard,
            TeacherPage.messages,
            TeacherPage.notifications,
            TeacherPage.profile
          ];
          final current = pages.contains(_page) ? pages.indexOf(_page) : 0;
          final next = velocity < 0 ? current + 1 : current - 1;
          if (next >= 0 && next < pages.length) _open(pages[next]);
        },
        child: Stack(children: [
          Positioned.fill(child: _pageBody()),
          if (_setupStatusLoaded &&
              _setupIncomplete &&
              !_setupGuideOpen &&
              _page != TeacherPage.profile &&
              _page != TeacherPage.stManage &&
              _page != TeacherPage.classes &&
              '${_subscription?['status'] ?? ''}' != 'unavailable' &&
              '${_subscription?['status'] ?? ''}' != 'expired')
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Material(
                elevation: 8,
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  leading: Icon(Icons.checklist_rounded, color: scheme.primary),
                  title: Text(_guideText(
                      'Complete the required 3-step teacher setup',
                      'අවශ්‍ය පියවර 3 ගුරු සැකසුම සම්පූර්ණ කරන්න',
                      'தேவையான 3-படி ஆசிரியர் அமைப்பை முடிக்கவும்')),
                  subtitle: Text(_guideText(
                      'Profile, ST Manage, then your first class and batch.',
                      'පැතිකඩ, ST Manage, පසුව පළමු පන්තිය සහ batch එක.',
                      'சுயவிவரம், ST Manage, பின்னர் முதல் வகுப்பு மற்றும் batch.')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _showSetupGuide,
                ),
              ),
            ),
          if ('${_subscription?['status'] ?? ''}' == 'expired')
            Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: Material(
                    elevation: 8,
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                    child: ListTile(
                        leading: Icon(Icons.warning_amber_rounded,
                            color: scheme.error),
                        title: const Text(
                            'Your free trial or subscription has ended',
                            style: TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: const Text(
                            'You have a 2-day grace period. Submit your payment slip now.'),
                        trailing: TextButton(
                            onPressed: () => _open(TeacherPage.subscription),
                            child: const Text('Subscribe'))))),
          if ('${_subscription?['status'] ?? ''}' == 'unavailable' &&
              _page != TeacherPage.subscription) ...[
            const Positioned.fill(
                child:
                    ModalBarrier(dismissible: false, color: Color(0xc9080d1a))),
            Positioned.fill(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Padding(
                        padding: const EdgeInsets.all(26),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.workspace_premium_rounded,
                              size: 58, color: scheme.primary),
                          const SizedBox(height: 16),
                          const Text('Subscription required',
                              style: TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),
                          const Text(
                              'The 2-day renewal grace period has ended. Choose a plan and send your payment slip for administrator approval.',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                              onPressed: () => _open(TeacherPage.subscription),
                              icon: const Icon(Icons.arrow_forward_rounded),
                              label: const Text('Open subscription plans')),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ]),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: .55),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? .18
                        : .07,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: NavigationBar(
                selectedIndex: _bottomIndex(_page),
                onDestinationSelected: (index) => _open(
                  [
                    TeacherPage.dashboard,
                    TeacherPage.messages,
                    TeacherPage.notifications,
                    TeacherPage.profile,
                  ][index],
                ),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.dashboard_outlined),
                    selectedIcon: const Icon(Icons.dashboard_rounded),
                    label: appLocale.tr('Dashboard'),
                  ),
                  NavigationDestination(
                    icon: Badge.count(
                      count: _unreadMessages,
                      isLabelVisible: _unreadMessages > 0,
                      child: const Icon(Icons.chat_bubble_outline),
                    ),
                    selectedIcon: const Icon(Icons.chat_bubble_rounded),
                    label: appLocale.tr('Messages'),
                  ),
                  NavigationDestination(
                    icon: Badge.count(
                      count: _unreadNotifications,
                      isLabelVisible: _unreadNotifications > 0,
                      child: const Icon(Icons.notifications_outlined),
                    ),
                    selectedIcon: const Icon(Icons.notifications_rounded),
                    label: appLocale.tr('Notifications'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.account_circle_outlined),
                    selectedIcon: const Icon(Icons.account_circle_rounded),
                    label: appLocale.tr('My profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _bottomIndex(TeacherPage page) {
    const pages = [
      TeacherPage.dashboard,
      TeacherPage.messages,
      TeacherPage.notifications,
      TeacherPage.profile,
    ];
    final index = pages.indexOf(page);
    return index < 0 ? 0 : index;
  }

  void _showSecurity(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('Secure connection'),
        content: Text(
          'Firebase keeps your sign-in securely on this device. Cached profile '
          'and page data are app-private and are removed when you sign out.',
        ),
      ),
    );
  }
}
