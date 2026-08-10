part of 'teacher_pages.dart';

enum _StudentSettingsTab { dashboard, ids, setup, visual, sidebar }

const _studentPortalKeys = [
  'dashboard',
  'reception',
  'space',
  'curriculum',
  'progress',
  'attendance',
  'assignments',
  'messages',
  'calendar',
  'profile',
  'settings',
];

const _teacherPortalKeys = [
  'dashboard',
  'classes',
  'manageBatches',
  'students',
  'attendance',
  'scan',
  'curriculum',
  'assignments',
  'messages',
  'reports',
  'dashboardContent',
  'calendar',
  'payments',
  'organization',
  'instituteOwner',
  'studentPortalSettings',
  'settings',
];

const _portalNames = <String, String>{
  'dashboard': 'Dashboard',
  'reception': 'Reception',
  'space': 'Learning space',
  'curriculum': 'Curriculum',
  'progress': 'Progress and grades',
  'attendance': 'Attendance',
  'assignments': 'Assignments',
  'messages': 'Messages',
  'calendar': 'Calendar',
  'profile': 'My profile',
  'settings': 'Settings',
  'classes': 'Classes',
  'manageBatches': 'Manage batches',
  'students': 'Students',
  'scan': 'QR and quick update',
  'reports': 'Reports',
  'dashboardContent': 'Quotes and notices',
  'payments': 'Payments',
  'organization': 'My profile',
  'instituteOwner': 'Institute access and subscription',
  'studentPortalSettings': 'ST Manage',
};

const _backgroundEffects = [
  'none',
  'rectangle-mesh',
  'hex-lattice',
  'blueprint',
  'circuit-board',
  'radial-rings',
  'aurora',
  'waves',
  'starfield',
  'diagonal-stripes',
  'soft-orbs',
];

const _pointerEffects = [
  'none',
  'sparkles',
  'glow',
  'bubbles',
  'comet',
  'confetti',
  'stars',
  'rings',
  'fireflies',
  'pixel',
  'ripple',
];

class _StudentPortalSettingsPage extends StatefulWidget {
  const _StudentPortalSettingsPage(
      {required this.session, required this.onNavigate});

  final SessionController session;
  final ValueChanged<TeacherPage> onNavigate;

  @override
  State<_StudentPortalSettingsPage> createState() =>
      _StudentPortalSettingsPageState();
}

class _StudentPortalSettingsPageState
    extends State<_StudentPortalSettingsPage> {
  Map<String, dynamic>? settings;
  Object? error;
  bool loading = true;
  bool saving = false;
  final prefixStatus = <String, Map<String, dynamic>>{};
  final _prefixTimers = <String, Timer>{};
  _StudentSettingsTab activeTab = _StudentSettingsTab.setup;
  late int _contentRevision;

  @override
  void initState() {
    super.initState();
    _contentRevision = widget.session.contentRevision;
    _load();
  }

  @override
  void didUpdateWidget(covariant _StudentPortalSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_contentRevision == widget.session.contentRevision) return;
    _contentRevision = widget.session.contentRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load(refresh: true);
    });
  }

  @override
  void dispose() {
    for (final timer in _prefixTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  void _schedulePrefixCheck(String key, String value) {
    _prefixTimers.remove(key)?.cancel();
    final normalized = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z][A-Z0-9]{0,9}$').hasMatch(normalized)) {
      setState(() => prefixStatus[key] = {
            'available': false,
            'reason': normalized.isEmpty
                ? 'A prefix is required'
                : 'Use 1-10 letters or numbers, starting with a letter',
          });
      return;
    }
    _prefixTimers[key] = Timer(
      const Duration(milliseconds: 450),
      () => _checkPrefix(key, normalized),
    );
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final responses = await Future.wait<dynamic>([
        widget.session.repository.teacherPortalSettings(),
        widget.session.repository.profile(),
      ]);
      final loaded = _map(_map(responses[0])['settings']);
      final privateProfile = _map(_map(responses[1])['profile']);
      final copy = _map(jsonDecode(jsonEncode(loaded)));
      final reception = _map(copy['reception']);
      final profilePhones = _strings(privateProfile['phones']);
      final primaryPhone = '${privateProfile['phone'] ?? ''}'.trim();
      final profileEmails = _strings(privateProfile['emails']);
      final primaryEmail = '${privateProfile['email'] ?? ''}'.trim();
      reception['teacherPhone'] = primaryPhone;
      reception['teacherWhatsapp'] =
          '${privateProfile['whatsappNumber'] ?? ''}'.trim();
      reception['teacherEmail'] = primaryEmail;
      reception['teacherOtherPhones'] = profilePhones
          .where((value) => value.isNotEmpty && value != primaryPhone)
          .toList();
      reception['teacherOtherEmails'] = profileEmails
          .where((value) =>
              value.isNotEmpty &&
              value.toLowerCase() != primaryEmail.toLowerCase())
          .toList();
      final savedInstitutions = reception['institutions'];
      if (savedInstitutions is! List || savedInstitutions.isEmpty) {
        reception['institutions'] = [
          {
            'name': '',
            'mapUrl': '',
            'address': '',
            'phone': '',
            'grades': <String>[],
            'subjects': <String>[],
          }
        ];
      }
      copy['reception'] = reception;
      copy['teachingGrades'] = _strings(widget.session.profile?['grades']);
      copy['teachingSubjects'] = _strings(widget.session.profile?['subjects']);
      copy['teachingClassTypes'] =
          _strings(widget.session.profile?['classTypes']);
      copy['teachingResultCategories'] =
          _strings(widget.session.profile?['resultCategories']);
      copy['subjectGrades'] = _map(widget.session.profile?['subjectGrades']);
      copy['subjectClassTypes'] =
          _map(widget.session.profile?['subjectClassTypes']);
      copy['subjectResultCategories'] =
          _map(widget.session.profile?['subjectResultCategories']);
      copy['subjectGradeIdPrefixes'] =
          _map(widget.session.profile?['subjectGradeIdPrefixes']);
      _normalizeNavigation(copy);
      if (mounted) {
        setState(() {
          settings = copy;
          error = null;
          loading = false;
        });
      }
    } catch (caught) {
      if (mounted) {
        setState(() {
          error = caught;
          loading = false;
        });
      }
    }
  }

  void _normalizeNavigation(Map<String, dynamic> data) {
    final navigation = _map(data['navigationOrder']);
    final existing = _strings(navigation['student'])
        .where(_studentPortalKeys.contains)
        .toList();
    for (final key in _studentPortalKeys) {
      if (!existing.contains(key)) existing.add(key);
    }
    navigation['student'] = existing;
    data['navigationOrder'] = navigation;
  }

  Map<String, dynamic> _section(String key) {
    final value = _map(settings?[key]);
    settings![key] = value;
    return value;
  }

  Map<String, dynamic> _nested(String parent, String child) {
    final parentMap = _section(parent);
    final value = _map(parentMap[child]);
    parentMap[child] = value;
    return value;
  }

  String _text(String key) => '${settings?[key] ?? ''}';

  Future<void> _continueSetup() async {
    final subjects = _strings(settings?['teachingSubjects']);
    final subjectGrades = _section('subjectGrades');
    final subjectClasses = _section('subjectClassTypes');
    final subjectResults = _section('subjectResultCategories');
    final grades = <String>{};
    final classes = <String>{};
    final results = <String>{};
    var subjectSetupInvalid = subjects.isEmpty;
    for (final subject in subjects) {
      final configuredGrades = _strings(subjectGrades[subject]);
      final configuredClasses = _strings(subjectClasses[subject]);
      final configuredResults = _strings(subjectResults[subject]);
      if (configuredGrades.isEmpty ||
          configuredClasses.isEmpty ||
          configuredResults.isEmpty) subjectSetupInvalid = true;
      grades.addAll(configuredGrades);
      classes.addAll(configuredClasses);
      results.addAll(configuredResults);
    }
    settings!['teachingGrades'] = grades.toList();
    settings!['teachingClassTypes'] = classes.toList();
    settings!['teachingResultCategories'] = results.toList();
    final reception = _section('reception');
    final institutions = (reception['institutions'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final invalidInstitute = institutions.isEmpty ||
        institutions.any((item) =>
            '${item['name'] ?? ''}'.trim().isEmpty ||
            '${item['address'] ?? ''}'.trim().isEmpty ||
            '${item['phone'] ?? ''}'.trim().isEmpty ||
            _strings(item['grades']).isEmpty ||
            _strings(item['subjects']).isEmpty);
    if (subjectSetupInvalid || invalidInstitute) {
      _snack(context,
          'Open every selected subject and choose its grades, class types and result categories. Also complete at least one institute.',
          error: true);
      return;
    }
    setState(() => saving = true);
    try {
      final profile = Map<String, dynamic>.from(widget.session.profile ?? {});
      profile['grades'] = grades.toList();
      profile['subjects'] = subjects;
      profile['classTypes'] = classes.toList();
      profile['resultCategories'] = results.toList();
      profile['subjectGrades'] = _map(settings?['subjectGrades']);
      profile['subjectClassTypes'] = _map(settings?['subjectClassTypes']);
      profile['subjectResultCategories'] =
          _map(settings?['subjectResultCategories']);
      profile['subjectGradeIdPrefixes'] =
          _map(settings?['subjectGradeIdPrefixes']);
      await widget.session.repository.saveProfile(profile);
      await widget.session.repository.saveTeacherSetupSettings({
        'reception': reception,
      });
      await widget.session.refreshProfile(forceNetwork: true);
      widget.session.markContentChanged();
    } catch (caught) {
      if (mounted) {
        _snack(context, 'Could not save subject and institute details: $caught',
            error: true);
      }
      return;
    } finally {
      if (mounted) setState(() => saving = false);
    }
    if (!mounted) return;
    setState(() => activeTab = _StudentSettingsTab.ids);
    _snack(context,
        'Subject and institute details saved. Now configure student IDs.');
  }

  Future<void> _checkPrefix(String key, String value) async {
    try {
      final response =
          await widget.session.repository.checkStudentIdPrefix(value);
      if (mounted) {
        setState(() => prefixStatus[key] = _map(response));
      }
    } catch (caught) {
      if (mounted) {
        setState(() =>
            prefixStatus[key] = {'available': false, 'reason': '$caught'});
      }
    }
  }

  Future<bool> _save(_StudentSettingsTab tab) async {
    final subjects = _strings(settings?['teachingSubjects']);
    final subject = _text('subjectName').trim().isEmpty && subjects.isNotEmpty
        ? subjects.first
        : _text('subjectName').trim();
    final prefix = _text('idPrefix').trim().toUpperCase();
    final space = _text('spaceName').trim();
    if (prefix.isEmpty || space.isEmpty) {
      _snack(
        context,
        'Complete the student ID prefix and learning-space title',
        error: true,
      );
      return false;
    }
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9]{0,9}$').hasMatch(prefix)) {
      _snack(
        context,
        'Student ID prefixes must use 1-10 letters or numbers and start with a letter',
        error: true,
      );
      return false;
    }
    if (tab == _StudentSettingsTab.ids) {
      final prefixesToCheck = <String, String>{'default': prefix};
      _section('gradeIdPrefixes').forEach((grade, value) {
        final normalized = '$value'.trim().toUpperCase();
        prefixesToCheck['$grade'] = normalized;
      });
      for (final entry in prefixesToCheck.entries) {
        if (entry.value.isEmpty) {
          _snack(context,
              '${entry.key}: enter an ID prefix or turn on Use default ID',
              error: true);
          return false;
        }
        final response = _map(
            await widget.session.repository.checkStudentIdPrefix(entry.value));
        if (mounted) setState(() => prefixStatus[entry.key] = response);
        if (response['available'] != true) {
          if (mounted) {
            _snack(context,
                '${entry.key == 'default' ? 'Default prefix' : entry.key}: ${response['reason'] ?? 'This ID prefix cannot be used'}',
                error: true);
          }
          return false;
        }
      }
    }

    settings!['subjectName'] = subject.isEmpty ? 'General' : subject;
    settings!['idPrefix'] = prefix;
    final prefixes = _section('gradeIdPrefixes');
    final teachingGrades = _strings(settings?['teachingGrades']).toSet();
    prefixes.removeWhere((grade, _) => !teachingGrades.contains(grade));
    for (final grade in prefixes.keys.toList()) {
      final value = '${prefixes[grade] ?? ''}'.trim().toUpperCase();
      if (value.isEmpty || value == prefix) {
        prefixes.remove(grade);
      } else {
        prefixes[grade] = value;
      }
    }

    setState(() => saving = true);
    try {
      final teachingGrades = _strings(settings?['teachingGrades']);
      final teachingSubjects = _strings(settings?['teachingSubjects']);
      final teachingClassTypes = _strings(settings?['teachingClassTypes']);
      final teachingResults = _strings(settings?['teachingResultCategories']);
      final profile = Map<String, dynamic>.from(widget.session.profile ?? {});
      profile['grades'] = teachingGrades;
      profile['subjects'] = teachingSubjects;
      profile['classTypes'] = teachingClassTypes;
      profile['resultCategories'] = teachingResults;
      profile['subjectGrades'] = _map(settings?['subjectGrades']);
      profile['subjectClassTypes'] = _map(settings?['subjectClassTypes']);
      profile['subjectResultCategories'] =
          _map(settings?['subjectResultCategories']);
      profile['subjectGradeIdPrefixes'] =
          _map(settings?['subjectGradeIdPrefixes']);
      await widget.session.repository.saveProfile(profile);
      await widget.session.refreshProfile(forceNetwork: true);
      final portalPayload = _map(jsonDecode(jsonEncode(settings)));
      portalPayload.remove('teachingGrades');
      portalPayload.remove('teachingSubjects');
      portalPayload.remove('teachingClassTypes');
      portalPayload.remove('teachingResultCategories');
      portalPayload.remove('subjectGrades');
      portalPayload.remove('subjectClassTypes');
      portalPayload.remove('subjectResultCategories');
      portalPayload.remove('subjectGradeIdPrefixes');
      final response = await widget.session.repository
          .saveTeacherPortalSettings(portalPayload);
      final saved = _map(_map(response)['settings']);
      final copy = _map(jsonDecode(jsonEncode(saved)));
      copy['teachingGrades'] = _strings(widget.session.profile?['grades']);
      copy['teachingSubjects'] = _strings(widget.session.profile?['subjects']);
      copy['teachingClassTypes'] =
          _strings(widget.session.profile?['classTypes']);
      copy['teachingResultCategories'] =
          _strings(widget.session.profile?['resultCategories']);
      copy['subjectGrades'] = _map(widget.session.profile?['subjectGrades']);
      copy['subjectClassTypes'] =
          _map(widget.session.profile?['subjectClassTypes']);
      copy['subjectResultCategories'] =
          _map(widget.session.profile?['subjectResultCategories']);
      copy['subjectGradeIdPrefixes'] =
          _map(widget.session.profile?['subjectGradeIdPrefixes']);
      _normalizeNavigation(copy);
      if (!mounted) return false;
      setState(() => settings = copy);
      widget.session.markContentChanged();
      _snack(context, '${_tabLabel(tab)} saved');
      if (tab == _StudentSettingsTab.ids) {
        widget.onNavigate(TeacherPage.classes);
        _snack(
            context, 'ST Manage complete. Create your first class and batch.');
      }
      return true;
    } catch (caught) {
      if (mounted) _snack(context, '$caught', error: true);
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _PageFrame(
        title: 'ST Manage',
        subtitle:
            'Configure the student app with the same controls as the web portal.',
        loading: loading,
        error: error,
        onRefresh: () => _load(refresh: true),
        children: [
          if (settings != null) ...[
            _tabBar(),
            const SizedBox(height: 14),
            switch (activeTab) {
              _StudentSettingsTab.dashboard => _dashboardSection(),
              _StudentSettingsTab.ids => _idsSection(),
              _StudentSettingsTab.setup => _setupSection(),
              _StudentSettingsTab.visual => _visualSection(),
              _StudentSettingsTab.sidebar => _sidebarSection(),
            },
          ],
        ],
      );

  Widget _tabBar() {
    const tabs = [
      (_StudentSettingsTab.dashboard, 'Dashboard', Icons.dashboard_outlined),
      (_StudentSettingsTab.ids, 'Student IDs', Icons.sell_outlined),
      (_StudentSettingsTab.setup, 'Student setup', Icons.manage_accounts),
      (_StudentSettingsTab.visual, 'Visual design', Icons.palette_outlined),
      (_StudentSettingsTab.sidebar, 'Sidebar & pages', Icons.tune_outlined),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final selected = activeTab == tab.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: selected
                ? FilledButton.icon(
                    onPressed: () => setState(() => activeTab = tab.$1),
                    icon: Icon(tab.$3, size: 18),
                    label: Text(tab.$2),
                  )
                : OutlinedButton.icon(
                    onPressed: () => setState(() => activeTab = tab.$1),
                    icon: Icon(tab.$3, size: 18),
                    label: Text(tab.$2),
                  ),
          );
        }).toList(),
      ),
    );
  }

  Widget _dashboardSection() => _settingsCard(
        title: 'Student dashboard welcome',
        subtitle:
            'Shown under the dashboard title. Use it for guidance or a current-term message.',
        children: [
          TextFormField(
            key: ValueKey('welcome-${settings.hashCode}'),
            initialValue: _text('studentWelcomeMessage'),
            minLines: 4,
            maxLines: 7,
            decoration: _input('Welcome message'),
            onChanged: (value) => setState(
              () => settings!['studentWelcomeMessage'] = value,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: .45),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIVE PREVIEW',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text('Student Dashboard',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  _text('studentWelcomeMessage').isEmpty
                      ? 'Your welcome message will appear here.'
                      : _text('studentWelcomeMessage'),
                ),
              ],
            ),
          ),
          _saveButton(_StudentSettingsTab.dashboard),
        ],
      );

  Widget _idsSection() {
    final gradePrefixes = _section('gradeIdPrefixes');
    final shownGrades = _strings(settings?['teachingGrades']);
    final allGradesUseDefault = gradePrefixes.isEmpty;
    return Column(
      children: [
        _settingsCard(
          title: 'Branding and student IDs',
          subtitle: 'Control the default ID prefix and learning-space title.',
          children: [
            TextFormField(
              initialValue: _text('idPrefix'),
              textCapitalization: TextCapitalization.characters,
              maxLength: 10,
              decoration: _input('Default student ID prefix').copyWith(
                hintText: 'Example: MICT or G6ICT',
                helperText:
                    '${prefixStatus['default']?['reason'] ?? 'Availability checks automatically while typing'}',
                helperStyle: TextStyle(
                    color: prefixStatus['default']?['available'] == true
                        ? Colors.green
                        : prefixStatus.containsKey('default')
                            ? Colors.red
                            : null),
                suffixIcon: prefixStatus['default']?['available'] == true
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : prefixStatus.containsKey('default')
                        ? const Icon(Icons.error, color: Colors.red)
                        : null,
              ),
              onChanged: (value) {
                settings!['idPrefix'] =
                    value.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
                prefixStatus.remove('default');
                _schedulePrefixCheck('default', '${settings!['idPrefix']}');
              },
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('All grades use the default ID'),
              subtitle: const Text(
                  'When enabled, every student under this teacher uses the default prefix.'),
              value: allGradesUseDefault,
              onChanged: (enabled) => setState(() {
                if (enabled) {
                  gradePrefixes.clear();
                  for (final grade in shownGrades) {
                    prefixStatus.remove(grade);
                  }
                } else if (shownGrades.isNotEmpty) {
                  gradePrefixes[shownGrades.first] = '';
                }
              }),
            ),
            _textField(
              'Learning-space title',
              _text('spaceName'),
              (value) => settings!['spaceName'] = value,
            ),
            const _Message(
              'Grade prefixes create clear student IDs. Example: G6ICT becomes G6ICT000001.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _settingsCard(
          title: 'Grade-wise ID starting letters',
          subtitle:
              'Set a prefix for each grade. Empty fields use the default prefix.',
          children: [
            if (shownGrades.isEmpty)
              const _Message(
                  'Select a subject and configure its grades in Student setup first.'),
            ...shownGrades.map(
              (grade) {
                final usesDefault = !gradePrefixes.containsKey(grade);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text('$grade uses default ID'),
                          subtitle: Text(
                              'Preview: ${usesDefault ? _text('idPrefix') : gradePrefixes[grade]}000001'),
                          value: usesDefault,
                          onChanged: allGradesUseDefault
                              ? null
                              : (enabled) => setState(() {
                                    if (enabled) {
                                      gradePrefixes.remove(grade);
                                      prefixStatus.remove(grade);
                                    } else {
                                      gradePrefixes[grade] = '';
                                    }
                                  }),
                        ),
                        if (!usesDefault)
                          TextFormField(
                            key: ValueKey('grade-$grade-${settings.hashCode}'),
                            initialValue: '${gradePrefixes[grade] ?? ''}',
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 10,
                            decoration: _input(
                                    '$grade - preview: ${gradePrefixes[grade] ?? _text("idPrefix")}000001')
                                .copyWith(
                              helperText:
                                  '${prefixStatus[grade]?['reason'] ?? 'Availability checks automatically while typing'}',
                              helperStyle: TextStyle(
                                  color:
                                      prefixStatus[grade]?['available'] == true
                                          ? Colors.green
                                          : prefixStatus.containsKey(grade)
                                              ? Colors.red
                                              : null),
                              suffixIcon:
                                  prefixStatus[grade]?['available'] == true
                                      ? const Icon(Icons.check_circle,
                                          color: Colors.green)
                                      : prefixStatus.containsKey(grade)
                                          ? const Icon(Icons.error,
                                              color: Colors.red)
                                          : null,
                            ),
                            onChanged: (value) {
                              gradePrefixes[grade] = value
                                  .toUpperCase()
                                  .replaceAll(RegExp('[^A-Z0-9]'), '');
                              prefixStatus.remove(grade);
                              _schedulePrefixCheck(
                                  grade, '${gradePrefixes[grade]}');
                            },
                          ),
                      ]),
                    ),
                  ),
                );
              },
            ),
            _saveButton(_StudentSettingsTab.ids),
          ],
        ),
      ],
    );
  }

  Future<void> _configureSubject(
    String subject,
    List<String> grades,
    List<String> classTypes,
    List<String> resultCategories,
  ) async {
    final gradeMap = _section('subjectGrades');
    final classMap = _section('subjectClassTypes');
    final resultMap = _section('subjectResultCategories');
    final selectedGrades = _strings(gradeMap[subject]).toSet();
    final selectedClasses = _strings(classMap[subject]).toSet();
    final selectedResults = _strings(resultMap[subject]).toSet();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          scrollable: true,
          title: Text('$subject setup'),
          content: SizedBox(
            width: 480,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _dialogChoices(
                  'Grades taught for $subject', grades, selectedGrades, update),
              const SizedBox(height: 16),
              _dialogChoices('Class types for $subject', classTypes,
                  selectedClasses, update),
              const SizedBox(height: 16),
              _dialogChoices('Result categories for $subject', resultCategories,
                  selectedResults, update),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: selectedGrades.isEmpty ||
                        selectedClasses.isEmpty ||
                        selectedResults.isEmpty
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: const Text('Save subject')),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        gradeMap[subject] = selectedGrades.toList();
        classMap[subject] = selectedClasses.toList();
        resultMap[subject] = selectedResults.toList();
      });
    }
  }

  Widget _dialogChoices(String title, List<String> options,
      Set<String> selected, StateSetter update) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 7),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: options
            .map((option) => FilterChip(
                  label: Text(option),
                  selected: selected.contains(option),
                  onSelected: (enabled) => update(() =>
                      enabled ? selected.add(option) : selected.remove(option)),
                ))
            .toList(),
      ),
    ]);
  }

  Widget _subjectEditor(List<String> subjects, List<String> grades,
      List<String> classTypes, List<String> results) {
    final selected = _strings(settings?['teachingSubjects']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Subjects you teach',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      if (subjects.isEmpty)
        const _Message('The administrator has not added subjects yet.'),
      Wrap(
        spacing: 7,
        runSpacing: 7,
        children: subjects.map((subject) {
          final enabled = selected.contains(subject);
          return InputChip(
            label: Text(subject),
            avatar: Icon(enabled ? Icons.edit_rounded : Icons.add_rounded,
                size: 17),
            selected: enabled,
            onPressed: () async {
              if (!enabled) {
                setState(() {
                  selected.add(subject);
                  settings!['teachingSubjects'] = selected;
                });
              }
              await _configureSubject(subject, grades, classTypes, results);
            },
            onDeleted: enabled
                ? () => setState(() {
                      selected.remove(subject);
                      settings!['teachingSubjects'] = selected;
                      _section('subjectGrades').remove(subject);
                      _section('subjectClassTypes').remove(subject);
                      _section('subjectResultCategories').remove(subject);
                    })
                : null,
          );
        }).toList(),
      ),
    ]);
  }

  Widget _instituteEditor(
    int index,
    Map<String, dynamic> institute,
    List<Map<String, dynamic>> institutions,
    List<String> availableGrades,
    List<String> availableSubjects,
  ) {
    final grades = _strings(institute['grades']);
    final subjects = _strings(institute['subjects']);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('Institute ${index + 1}',
                    style: Theme.of(context).textTheme.titleMedium)),
            IconButton(
              tooltip: 'Remove institute',
              onPressed: institutions.length == 1
                  ? null
                  : () => setState(() => institutions.removeAt(index)),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ]),
          _textField('Institute name', '${institute['name'] ?? ''}',
              (value) => institute['name'] = value),
          _textField('Google Maps link', '${institute['mapUrl'] ?? ''}',
              (value) => institute['mapUrl'] = value,
              keyboardType: TextInputType.url),
          _textField('Address and landmark', '${institute['address'] ?? ''}',
              (value) => institute['address'] = value,
              lines: 3),
          _textField('Institute phone number', '${institute['phone'] ?? ''}',
              (value) => institute['phone'] = value,
              keyboardType: TextInputType.phone),
          Text('Grades taught here',
              style: Theme.of(context).textTheme.titleSmall),
          Wrap(
              spacing: 6,
              runSpacing: 6,
              children: availableGrades.map((grade) {
                return FilterChip(
                  label: Text(grade),
                  selected: grades.contains(grade),
                  onSelected: (enabled) => setState(() {
                    enabled ? grades.add(grade) : grades.remove(grade);
                    institute['grades'] = grades;
                  }),
                );
              }).toList()),
          const SizedBox(height: 12),
          Text('Subjects taught here',
              style: Theme.of(context).textTheme.titleSmall),
          Wrap(
              spacing: 6,
              runSpacing: 6,
              children: availableSubjects.map((subject) {
                return FilterChip(
                  label: Text(subject),
                  selected: subjects.contains(subject),
                  onSelected: (enabled) => setState(() {
                    enabled ? subjects.add(subject) : subjects.remove(subject);
                    institute['subjects'] = subjects;
                  }),
                );
              }).toList()),
        ]),
      ),
    );
  }

  Widget _setupSection() {
    final reception = _section('reception');
    final profile = widget.session.profile ?? <String, dynamic>{};
    final profilePhone = '${profile['phone'] ?? ''}'.trim();
    final profileWhatsapp = '${profile['whatsappNumber'] ?? ''}'.trim();
    final profileEmail = '${profile['email'] ?? ''}'.trim();
    final profilePhones = _strings(profile['phones'])
        .where((value) => value != profilePhone)
        .toList();
    final profileEmails = _strings(profile['emails'])
        .where((value) => value.toLowerCase() != profileEmail.toLowerCase())
        .toList();
    if ('${reception['teacherPhone'] ?? ''}'.trim().isEmpty) {
      reception['teacherPhone'] = profilePhone;
    }
    if ('${reception['teacherWhatsapp'] ?? ''}'.trim().isEmpty) {
      reception['teacherWhatsapp'] = profileWhatsapp;
    }
    if ('${reception['teacherEmail'] ?? ''}'.trim().isEmpty) {
      reception['teacherEmail'] = profileEmail;
    }
    if (_strings(reception['teacherOtherPhones']).isEmpty) {
      reception['teacherOtherPhones'] = profilePhones;
    }
    if (_strings(reception['teacherOtherEmails']).isEmpty) {
      reception['teacherOtherEmails'] = profileEmails;
    }
    final availableGrades = _strings(settings?['teacherGrades']);
    final availableSubjects = _strings(settings?['teacherSubjects']);
    final availableClassTypes = _strings(settings?['classTypes']);
    final availableResults = _strings(settings?['resultCategories']);
    final institutions = (reception['institutions'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    reception['institutions'] = institutions;
    return Column(
      children: [
        _settingsCard(
          title: 'Subject setup',
          subtitle:
              'Select a subject, then configure its grades, class types, result categories and student ID prefixes.',
          children: [
            _subjectEditor(availableSubjects, availableGrades,
                availableClassTypes, availableResults),
          ],
        ),
        const SizedBox(height: 12),
        _settingsCard(
          title: 'Student reception details',
          subtitle:
              'Shown before students join a batch or when they need teacher contact details.',
          children: [
            _textField('Reception title', '${reception['title'] ?? ''}',
                (value) => reception['title'] = value),
            _textField(
                'Teacher name', '${reception['teacherName'] ?? ''}', (_) {},
                readOnly: true),
            _contactVisibility(
                'Primary phone',
                '${reception['teacherPhone'] ?? ''}',
                reception['showPhoneToStudents'] == true,
                (value) => reception['showPhoneToStudents'] = value),
            _contactVisibility(
                'Primary WhatsApp number',
                '${reception['teacherWhatsapp'] ?? ''}',
                reception['showWhatsappToStudents'] == true,
                (value) => reception['showWhatsappToStudents'] = value),
            _contactVisibility(
                'Other phone numbers',
                _strings(reception['teacherOtherPhones']).join(', '),
                reception['showOtherPhonesToStudents'] == true,
                (value) => reception['showOtherPhonesToStudents'] = value),
            _contactVisibility(
                'Primary Gmail',
                '${reception['teacherEmail'] ?? ''}',
                reception['showEmailToStudents'] == true,
                (value) => reception['showEmailToStudents'] = value),
            _contactVisibility(
                'Other email addresses',
                _strings(reception['teacherOtherEmails']).join(', '),
                reception['showOtherEmailsToStudents'] == true,
                (value) => reception['showOtherEmailsToStudents'] = value),
            _textField(
                'Student dashboard welcome message',
                _text('studentWelcomeMessage'),
                (value) => settings!['studentWelcomeMessage'] = value,
                lines: 4),
            ...institutions.asMap().entries.map((entry) => _instituteEditor(
                entry.key,
                entry.value,
                institutions,
                availableGrades,
                availableSubjects)),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  institutions.add({
                    'name': '',
                    'mapUrl': '',
                    'address': '',
                    'phone': '',
                    'grades': <String>[],
                    'subjects': <String>[],
                  });
                  reception['institutions'] = institutions;
                }),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add another institute'),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: saving ? null : _continueSetup,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Next: Student IDs'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _visualSection() {
    final studentEffects = _nested('effects', 'student');
    final visual = _section('visualEffects');
    final background = _safeChoice(
      '${studentEffects['backgroundEffect'] ?? ''}',
      _backgroundEffects,
    );
    final pointer = _safeChoice(
      '${studentEffects['pointerEffect'] ?? ''}',
      _pointerEffects,
    );
    final blur = (visual['cardBlur'] as num?)?.toDouble() ?? 8;
    final opacity = (visual['cardOpacity'] as num?)?.toDouble() ?? 88;
    return _settingsCard(
      title: 'Student Visual Design Studio',
      subtitle:
          'Set the default appearance. Students can switch effects on or off in their settings.',
      children: [
        DropdownButtonFormField<String>(
          initialValue: background,
          decoration: _input('Background effect'),
          items: _backgroundEffects
              .map((value) => DropdownMenuItem(
                    value: value,
                    child: Text(value.replaceAll('-', ' ')),
                  ))
              .toList(),
          onChanged: (value) =>
              setState(() => studentEffects['backgroundEffect'] = value),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: pointer,
          decoration: _input('Pointer effect'),
          items: _pointerEffects
              .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)))
              .toList(),
          onChanged: (value) =>
              setState(() => studentEffects['pointerEffect'] = value),
        ),
        const SizedBox(height: 18),
        Text('Card blur: ${blur.round()} px'),
        Slider(
          value: blur.clamp(0, 40),
          min: 0,
          max: 40,
          divisions: 40,
          onChanged: (value) =>
              setState(() => visual['cardBlur'] = value.round()),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Transparent cards'),
          value: visual['cardTransparent'] != false,
          onChanged: (value) =>
              setState(() => visual['cardTransparent'] = value),
        ),
        Text('Card opacity: ${opacity.round()}%'),
        Slider(
          value: opacity.clamp(10, 100),
          min: 10,
          max: 100,
          divisions: 90,
          onChanged: (value) =>
              setState(() => visual['cardOpacity'] = value.round()),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: opacity / 100),
                Theme.of(context)
                    .colorScheme
                    .tertiaryContainer
                    .withValues(alpha: opacity / 100),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Student dashboard card',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Visual changes preview here.'),
            ],
          ),
        ),
        _saveButton(_StudentSettingsTab.visual),
      ],
    );
  }

  Widget _sidebarSection() {
    final navigation = _section('navigationOrder');
    final order = _strings(navigation['student']);
    final visibility = _section('sidebarVisibility');
    final labels = _section('labels');
    return Column(
      children: [
        _settingsCard(
          title: 'Student sidebar order',
          subtitle:
              'Use the arrows to arrange student pages. Dashboard and Settings remain available.',
          children: [
            ...order.asMap().entries.map((entry) {
              final index = entry.key;
              final key = entry.value;
              final studentLabels = _map(labels['student']);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.drag_indicator),
                  title: Text(
                    '${studentLabels[key] ?? _portalNames[key] ?? key}',
                  ),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        onPressed: index == 0
                            ? null
                            : () => setState(() {
                                  final item = order.removeAt(index);
                                  order.insert(index - 1, item);
                                  navigation['student'] = order;
                                }),
                        icon: const Icon(Icons.arrow_upward),
                      ),
                      IconButton(
                        onPressed: index == order.length - 1
                            ? null
                            : () => setState(() {
                                  final item = order.removeAt(index);
                                  order.insert(index + 1, item);
                                  navigation['student'] = order;
                                }),
                        icon: const Icon(Icons.arrow_downward),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 12),
        _portalPageEditor(
          role: 'student',
          title: 'Student portal pages',
          keys: _studentPortalKeys,
          labels: labels,
          visibility: visibility,
        ),
        const SizedBox(height: 12),
        _portalPageEditor(
          role: 'teacher',
          title: 'Teacher portal pages',
          keys: _teacherPortalKeys,
          labels: labels,
          visibility: visibility,
        ),
        _saveButton(_StudentSettingsTab.sidebar),
      ],
    );
  }

  Widget _portalPageEditor({
    required String role,
    required String title,
    required List<String> keys,
    required Map<String, dynamic> labels,
    required Map<String, dynamic> visibility,
  }) {
    final roleLabels = _map(labels[role]);
    final roleVisibility = _map(visibility[role]);
    labels[role] = roleLabels;
    visibility[role] = roleVisibility;
    return _settingsCard(
      title: title,
      subtitle: 'Rename pages and choose which items are visible.',
      children: keys.map((key) {
        final protected = key == 'dashboard' || key == 'settings';
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
            child: Column(
              children: [
                TextFormField(
                  key: ValueKey('$role-$key-${settings.hashCode}'),
                  initialValue:
                      '${roleLabels[key] ?? _portalNames[key] ?? key}',
                  decoration: _input(_portalNames[key] ?? key),
                  onChanged: (value) => roleLabels[key] = value,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visible'),
                  subtitle: protected
                      ? const Text('This essential page always stays visible.')
                      : null,
                  value: protected || roleVisibility[key] != false,
                  onChanged: protected
                      ? null
                      : (value) => setState(() => roleVisibility[key] = value),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _listEditor(
    String title,
    List<String> values,
    ValueChanged<List<String>> onChanged,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...values.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey(
                              '$title-${entry.key}-${settings.hashCode}'),
                          initialValue: entry.value,
                          decoration: _input('Item ${entry.key + 1}'),
                          onChanged: (value) {
                            values[entry.key] = value;
                            onChanged(values);
                          },
                        ),
                      ),
                      IconButton(
                        onPressed: values.length == 1
                            ? null
                            : () => setState(() {
                                  values.removeAt(entry.key);
                                  onChanged(values);
                                }),
                        icon: const Icon(Icons.remove_circle_outline),
                        tooltip: 'Remove',
                      ),
                    ],
                  ),
                ),
              ),
          OutlinedButton.icon(
            onPressed: () => setState(() {
              values.add('');
              onChanged(values);
            }),
            icon: const Icon(Icons.add),
            label: const Text('Add item'),
          ),
        ],
      );

  Widget _textField(
    String label,
    String value,
    ValueChanged<String> onChanged, {
    int lines = 1,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.sentences,
    bool readOnly = false,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          key: ValueKey('$label-${settings.hashCode}'),
          initialValue: value,
          minLines: lines,
          maxLines: lines > 1 ? lines : 1,
          keyboardType: keyboardType,
          textCapitalization: capitalization,
          readOnly: readOnly,
          decoration: _input(label).copyWith(
            helperText: readOnly ? 'Managed from My Profile' : null,
            suffixIcon:
                readOnly ? const Icon(Icons.lock_outline_rounded) : null,
          ),
          onChanged: onChanged,
        ),
      );

  Widget _settingsCard({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) =>
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              ...children,
            ],
          ),
        ),
      );

  Widget _saveButton(_StudentSettingsTab tab) => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: saving ? null : () => _save(tab),
            icon: saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(saving ? 'Saving...' : 'Save this section'),
          ),
        ),
      );

  Widget _contactVisibility(
      String label, String value, bool enabled, ValueChanged<bool> onChanged) {
    final available = value.trim().isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: SwitchListTile.adaptive(
        title: Text(label),
        subtitle: SelectableText(
            available ? value : 'No contact has been saved in My Profile'),
        value: enabled,
        onChanged: (next) => setState(() => onChanged(next)),
      ),
    );
  }

  String _safeChoice(String value, List<String> options) =>
      options.contains(value) ? value : options.first;

  String _tabLabel(_StudentSettingsTab tab) => switch (tab) {
        _StudentSettingsTab.dashboard => 'Dashboard',
        _StudentSettingsTab.ids => 'Student IDs',
        _StudentSettingsTab.setup => 'Student setup',
        _StudentSettingsTab.visual => 'Visual design',
        _StudentSettingsTab.sidebar => 'Sidebar and pages',
      };
}
