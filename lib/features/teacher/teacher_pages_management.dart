part of 'teacher_pages.dart';

class _DashboardPage extends StatefulWidget {
  const _DashboardPage(
      {required this.session,
      required this.onNavigate,
      this.guideKeys = const [],
      this.onGuideReady});
  final SessionController session;
  final ValueChanged<TeacherPage> onNavigate;
  final List<GlobalKey> guideKeys;
  final VoidCallback? onGuideReady;
  @override
  State<_DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<_DashboardPage> {
  late Future<dynamic> request;
  late int _contentRevision;
  final Set<String> _endedSessions = <String>{};
  bool _guideReadySent = false;

  String _sessionKey(Map<String, dynamic> item) =>
      '${item['batchId']}__${item['classDate']}';

  @override
  void initState() {
    super.initState();
    _contentRevision = widget.session.contentRevision;
    widget.session.addListener(_sessionChanged);
    request = load();
  }

  @override
  void dispose() {
    widget.session.removeListener(_sessionChanged);
    super.dispose();
  }

  void _sessionChanged() {
    if (_contentRevision == widget.session.contentRevision) return;
    _contentRevision = widget.session.contentRevision;
    if (mounted) setState(() => request = load());
  }

  Future<dynamic> load() => Future.wait([
        widget.session.repository.dashboard(),
        widget.session.repository.dashboardContent()
      ]);
  Future<void> refresh() async {
    setState(() => request = load());
    await request;
  }

  Future<void> changeClass(Map<String, dynamic> item) async {
    final live = item['status'] == 'live';
    if (!live &&
        !await _confirm(
            context, 'Do you want to start ${item['batchName']} now?')) {
      return;
    }
    if (!mounted) return;
    final actionTime = DateFormat.jm().format(DateTime.now());
    final changed = await _act(
      context,
      () => live
          ? widget.session.repository.endClassSession('${item['batchId']}',
              classDate: '${item['classDate']}')
          : widget.session.repository.startClassSession('${item['batchId']}',
              classDate: '${item['classDate']}'),
      live
          ? '${item['batchName']} ended at $actionTime. Students were notified.'
          : '${item['batchName']} started at $actionTime. Students were notified.',
    );
    if (changed) {
      if (live && mounted) {
        setState(() => _endedSessions.add(_sessionKey(item)));
      }
      await widget.session.repository.clearCache();
      if (mounted) {
        setState(() => request = load());
        await request;
      }
    }
  }

  Future<void> addResults(List<Map<String, dynamic>> students,
      List<Map<String, dynamic>> batches) async {
    final batchId = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
            title: const Text('Select result batch'),
            children: batches
                .map((batch) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, '${batch['id']}'),
                    child: Text(_title(batch))))
                .toList()));
    if (batchId == null || !mounted) return;
    final batchStudents = students
        .where((student) => _strings(student['batchIds']).contains(batchId))
        .toList();
    final fields = <_Field>[
      const _Field('title', 'Result title'),
      const _Field('category', 'Category'),
      const _Field('total', 'Maximum marks', kind: _FieldKind.number),
      const _Field('resultDate', 'Date (YYYY-MM-DD)'),
      ...batchStudents.map((student) => _Field(
          'score_${student['uid'] ?? student['id']}',
          '${_title(student)} score',
          kind: _FieldKind.number)),
    ];
    final data = await _showForm(context,
        title: 'Enter student results',
        initial: {
          'resultDate': DateFormat('yyyy-MM-dd').format(DateTime.now())
        },
        fields: fields);
    if (data == null || !mounted) return;
    final date = DateTime.tryParse('${data['resultDate']}') ?? DateTime.now();
    final marks = batchStudents.map((student) {
      final uid = '${student['uid'] ?? student['id']}';
      return {'studentUid': uid, 'score': data['score_$uid'] ?? 0};
    }).toList();
    await _act(
        context,
        () => widget.session.repository.createResultSheet(batchId, {
              'title': data['title'],
              'category': data['category'],
              'total': data['total'],
              'resultDate': date.toUtc().toIso8601String(),
              'marks': marks
            }),
        'Student results saved');
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
      future: request,
      builder: (context, snapshot) {
        final responses =
            snapshot.data is List ? snapshot.data as List : const [];
        final summary = responses.isNotEmpty
            ? _map(_map(responses[0])['summary'])
            : <String, dynamic>{};
        final notices = responses.length > 1
            ? _list(_map(responses[1])['items'])
            : <Map<String, dynamic>>[];
        final liveClasses = _list(summary['liveClasses'])
            .where((item) => !_endedSessions.contains(_sessionKey(item)))
            .toList();
        final scheduledClasses = _list(summary['scheduledClasses'])
            .where((item) => !_endedSessions.contains(_sessionKey(item)))
            .toList();
        final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final tomorrowKey = DateFormat('yyyy-MM-dd')
            .format(DateTime.now().add(const Duration(days: 1)));
        final todayClasses = scheduledClasses
            .where((item) => '${item['classDate']}' == todayKey)
            .toList();
        final tomorrowClasses = scheduledClasses
            .where((item) => '${item['classDate']}' == tomorrowKey)
            .toList();
        final currentClass = liveClasses.firstOrNull ??
            scheduledClasses
                .where((item) =>
                    item['status'] != 'ended' &&
                    item['status'] != 'cancelled' &&
                    '${item['classDate'] ?? ''}'.compareTo(
                            DateFormat('yyyy-MM-dd').format(DateTime.now())) >=
                        0)
                .firstOrNull;
        if (snapshot.hasData && !_guideReadySent) {
          _guideReadySent = true;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => widget.onGuideReady?.call());
        }
        return _PageFrame(
          title: 'Teacher dashboard',
          subtitle: 'Classes, notices, and learning activity.',
          compactHeader: notices.isNotEmpty,
          loading: snapshot.connectionState == ConnectionState.waiting,
          error: snapshot.error,
          onRefresh: refresh,
          cacheExtent: widget.guideKeys.isEmpty ? null : 1800,
          children: [
            if (todayClasses.isNotEmpty || tomorrowClasses.isNotEmpty) ...[
              Text('Class calendar',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ...todayClasses.map((item) => _TeacherClassNotice(
                    item: item,
                    label: 'TODAY',
                    highlighted: true,
                    onTap: () => changeClass(item),
                  )),
              ...tomorrowClasses.map((item) => _TeacherClassNotice(
                    item: item,
                    label: 'TOMORROW',
                    onTap: () => widget.onNavigate(TeacherPage.calendar),
                  )),
              const SizedBox(height: 8),
            ],
            if (currentClass != null) ...[
              Container(
                key: widget.guideKeys.isNotEmpty ? widget.guideKeys[0] : null,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: .24),
                    Theme.of(context)
                        .colorScheme
                        .tertiary
                        .withValues(alpha: .16),
                  ]),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: .28)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          currentClass['status'] == 'live'
                              ? 'CLASS IS LIVE NOW'
                              : 'NEXT SCHEDULED CLASS',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1)),
                      const SizedBox(height: 8),
                      Text('${currentClass['batchName']}',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Text(
                          '${currentClass['classDate']} • ${currentClass['classStartTime']}–${currentClass['classEndTime']}'),
                      if (currentClass['status'] == 'live' &&
                          currentClass['actualStartedAt'] != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          'Started at ${DateFormat.jm().format(DateTime.parse('${currentClass['actualStartedAt']}').toLocal())}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                      const SizedBox(height: 14),
                      FilledButton.icon(
                          onPressed: () => changeClass(currentClass),
                          icon: Icon(currentClass['status'] == 'live'
                              ? Icons.stop_circle_outlined
                              : Icons.play_circle_fill_rounded),
                          label: Text(currentClass['status'] == 'live'
                              ? 'End class'
                              : 'Start class')),
                    ]),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              key: currentClass == null && widget.guideKeys.isNotEmpty
                  ? widget.guideKeys[0]
                  : null,
              child: ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Teacher ID'),
                subtitle: Text(
                    '${widget.session.profile?['teacherPublicId'] ?? widget.session.profile?['teacherCode'] ?? 'Not assigned'}'),
              ),
            ),
            KeyedSubtree(
              key: widget.guideKeys.length > 1 ? widget.guideKeys[1] : null,
              child: _Section(
                  'Upcoming',
                  _list(summary['upcomingItems'])
                      .map((item) => _dataTile(
                          item, () => widget.onNavigate(TeacherPage.classes)))
                      .toList()),
            ),
            _Section(
                'Quotes & notices',
                notices
                    .map((item) => _dataTile(
                        item, () => widget.onNavigate(TeacherPage.quotes)))
                    .toList()),
            GridView.count(
                key: widget.guideKeys.length > 2 ? widget.guideKeys[2] : null,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                padding: const EdgeInsets.only(top: 8),
                childAspectRatio: 1.5,
                children: [
                  _Metric(
                      'Students',
                      summary['totalStudents'] ?? 0,
                      Icons.groups_outlined,
                      () => widget.onNavigate(TeacherPage.students)),
                  _Metric(
                      'Batches',
                      summary['activeBatches'] ?? 0,
                      Icons.class_outlined,
                      () => widget.onNavigate(TeacherPage.classes)),
                  _Metric(
                      'Attendance',
                      summary['attendanceSessionsToday'] ?? 0,
                      Icons.how_to_reg_outlined,
                      () => widget.onNavigate(TeacherPage.attendance)),
                  _Metric(
                      'Unread',
                      summary['unreadMessages'] ?? 0,
                      Icons.chat_outlined,
                      () => widget.onNavigate(TeacherPage.messages)),
                ]),
          ],
        );
      });
}

class _TeacherClassNotice extends StatelessWidget {
  const _TeacherClassNotice({
    required this.item,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });
  final Map<String, dynamic> item;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: highlighted ? scheme.primaryContainer : null,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: highlighted ? scheme.primary : scheme.secondary,
          foregroundColor: highlighted ? scheme.onPrimary : scheme.onSecondary,
          child: const Icon(Icons.schedule_rounded),
        ),
        title: Text('$label · ${item['batchName'] ?? 'Class'}',
            style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(
            '${item['classStartTime'] ?? ''}–${item['classEndTime'] ?? ''}${item['message'] == null || '${item['message']}'.isEmpty ? '' : '\n${item['message']}'}'),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon, this.onTap);
  final String label;
  final dynamic value;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
      child: InkWell(
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon),
                    Text('$value',
                        style: Theme.of(context).textTheme.headlineSmall),
                    Text(label)
                  ]))));
}

class _BatchesPage extends StatefulWidget {
  const _BatchesPage({required this.session, required this.onNavigate});
  final SessionController session;
  final ValueChanged<TeacherPage> onNavigate;
  @override
  State<_BatchesPage> createState() => _BatchesPageState();
}

class _BatchesPageState extends State<_BatchesPage> {
  List<String> batchTypes = [];
  List<String> grades = [];
  List<Map<String, dynamic>> currentBatches = [];
  String defaultInstitute = 'Teacher workspace';
  late Future<List<Map<String, dynamic>>> request = load();

  Future<List<Map<String, dynamic>>> load() async {
    final responses = await Future.wait([
      widget.session.repository.batches(),
      widget.session.repository.appSettings(),
    ]);
    final profile = widget.session.profile ?? <String, dynamic>{};
    final settings = _map(_map(responses[1])['settings']);
    batchTypes = _strings(profile['classTypes']);
    if (batchTypes.isEmpty) batchTypes = _strings(settings['classTypes']);
    grades = _strings(settings['teachingGrades']);
    if (grades.isEmpty) grades = _strings(profile['grades']);
    if (grades.isEmpty) grades = _strings(settings['teacherGrades']);
    final institutes = _list(profile['institutes']);
    final activeInstitute =
        institutes.where((item) => item['active'] == true).firstOrNull ??
            institutes.firstOrNull;
    defaultInstitute =
        '${activeInstitute?['name'] ?? profile['displayName'] ?? 'Teacher workspace'}';
    currentBatches = _list(_map(responses[0])['batches']);
    return currentBatches;
  }

  Future<void> refresh() async {
    setState(() => request = load());
    await request;
  }

  String weeklyText(Map<String, dynamic> item) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final schedule = _list(item['weeklySchedule']);
    if (schedule.isEmpty) return 'No weekly class days';
    return schedule.map((entry) {
      final weekday = (entry['weekday'] as num?)?.toInt() ?? 1;
      return '${days[weekday - 1]} ${entry['startTime']}–${entry['endTime']}';
    }).join(' · ');
  }

  Future<void> edit([Map<String, dynamic>? item]) async {
    if (batchTypes.isEmpty || grades.isEmpty) {
      _snack(
          context,
          batchTypes.isEmpty
              ? 'Add batch types to your teacher profile or ST Manage first.'
              : 'Add grades to your teacher profile first.',
          error: true);
      return;
    }
    final initial = <String, dynamic>{
      ...?item,
      'batchType':
          _strings(item?['classTypes']).firstOrNull ?? batchTypes.first,
      'feeType': item?['feeType'] == 'daily'
          ? 'Day fee'
          : item?['feeType'] == 'monthly' || item?['tuitionFeeEnabled'] == true
              ? 'Monthly fee'
              : 'Free',
    };
    final data = await _showForm(context,
        title: item == null ? 'Create batch' : 'Edit batch',
        initial: initial,
        confirmLabel: 'Next',
        fields: [
          const _Field('name', 'Batch name'),
          _Field('batchType', 'Batch type',
              kind: _FieldKind.select, options: batchTypes),
          _Field('grade', 'Batch grade',
              kind: _FieldKind.select, options: grades),
          const _Field('enrollmentKey', 'Enrollment key'),
          const _Field('feeType', 'Class fee method',
              kind: _FieldKind.select,
              options: ['Free', 'Day fee', 'Monthly fee']),
          const _Field('dailyFee', 'Day fee (LKR)', kind: _FieldKind.number),
          const _Field('monthlyFee', 'Monthly fee (LKR)',
              kind: _FieldKind.number),
        ]);
    if (data == null || !mounted) return;
    final existingWeekly = _list(item?['weeklySchedule']);
    final weeklySchedule = await _showWeeklyScheduleForm(
      context,
      initial: existingWeekly,
    );
    if (weeklySchedule == null || !mounted) return;
    final name = '${data['name']}'.trim();
    final enrollmentKey = '${data['enrollmentKey']}'.trim();
    final feeType = data['feeType'] == 'Day fee'
        ? 'daily'
        : data['feeType'] == 'Monthly fee'
            ? 'monthly'
            : 'free';
    final tuitionFeeEnabled = feeType != 'free';
    final dailyFee = (data['dailyFee'] as num?)?.toDouble() ?? 0;
    final monthlyFee = (data['monthlyFee'] as num?)?.toDouble() ?? 0;
    if (name.isEmpty || enrollmentKey.length < 4) {
      _snack(context,
          'Enter a batch name and an enrollment key of at least 4 characters.',
          error: true);
      return;
    }
    if (feeType == 'daily' && dailyFee <= 0) {
      _snack(context, 'Enter the day fee for this batch.', error: true);
      return;
    }
    if (feeType == 'monthly' && monthlyFee <= 0) {
      _snack(context, 'Enter the monthly fee for this batch.', error: true);
      return;
    }
    final yearMatch = RegExp(r'\b(20\d{2})\b').firstMatch(name);
    final payload = <String, dynamic>{
      'name': name,
      'institute': item?['institute'] ?? defaultInstitute,
      'year': item?['year'] ?? yearMatch?.group(1) ?? '${DateTime.now().year}',
      'grade': data['grade'],
      'enrollmentKey': enrollmentKey,
      'classTypes': [data['batchType']],
      'feeType': feeType,
      'tuitionFeeEnabled': tuitionFeeEnabled,
      'dailyFee': feeType == 'daily' ? dailyFee : 0,
      'monthlyFee': feeType == 'monthly' ? monthlyFee : 0,
      'classDate': '',
      'classStartTime': '',
      'classEndTime': '',
      'weeklySchedule': weeklySchedule,
    };
    final creatingFirstBatch = item == null && currentBatches.isEmpty;
    final saved = await _act(
      context,
      () => item == null
          ? widget.session.repository.createBatch(payload)
          : widget.session.repository.updateBatch('${item['id']}', payload),
      item == null
          ? 'Batch created. Teacher setup is complete.'
          : 'Batch updated',
    );
    if (!saved || !mounted) return;
    await refresh();
    if (creatingFirstBatch && mounted) {
      await _showSetupCompleteDialog();
    }
  }

  Future<void> _showSetupCompleteDialog() async {
    final scheme = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: CircleAvatar(
          radius: 34,
          backgroundColor: scheme.primaryContainer,
          child: Icon(Icons.check_rounded, size: 42, color: scheme.primary),
        ),
        title: const Text('Setup completed successfully',
            textAlign: TextAlign.center),
        content: const SizedBox(
          width: 430,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'Your teacher workspace is ready. You can now approve student requests, send messages, manage attendance, and add learning content.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            _CompletedSetupStep(
                number: '1', title: 'Teacher profile completed'),
            _CompletedSetupStep(
                number: '2', title: 'Student setup and IDs completed'),
            _CompletedSetupStep(
                number: '3', title: 'First class and batch created'),
          ]),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.onNavigate(TeacherPage.messages);
            },
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('Messages'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.onNavigate(TeacherPage.students);
            },
            icon: const Icon(Icons.how_to_reg_rounded),
            label: const Text('Approve students'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: request,
        builder: (context, snapshot) => _PageFrame(
          title: 'Classes & batches',
          subtitle:
              'Choose a batch type, fee method, and the first date and default time for its repeating weekly class.',
          loading: snapshot.connectionState == ConnectionState.waiting,
          error: snapshot.error,
          onRefresh: refresh,
          actions: [
            IconButton(
              onPressed: () async {
                if (await _showAddStudentsToBatch(context, widget.session)) {
                  await refresh();
                }
              },
              icon: const Icon(Icons.group_add_outlined),
              tooltip: 'Add students to batch',
            ),
            IconButton(onPressed: () => edit(), icon: const Icon(Icons.add))
          ],
          children: [
            if (snapshot.hasData && snapshot.data!.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.class_outlined,
                          size: 44,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 10),
                      Text('No batches yet',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      const Text(
                        'Create your first batch to start adding students and learning content.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => edit(),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Tap to create'),
                      ),
                    ],
                  ),
                ),
              ),
            ...(snapshot.data ?? []).map((item) => Card(
                    child: ListTile(
                  title: Text(_title(item)),
                  subtitle: Text(
                      '${_strings(item['classTypes']).join(', ')} • ${item['grade'] ?? ''}\n${weeklyText(item)}\nEnrollment key: ${item['enrollmentKey'] ?? ''}${item['feeType'] == 'daily' ? '\nDay fee: LKR ${item['dailyFee'] ?? 0}' : item['feeType'] == 'monthly' ? '\nMonthly fee: LKR ${item['monthlyFee'] ?? 0}' : '\nFree class'}'),
                  isThreeLine: true,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => _BatchContentPage(
                      session: widget.session,
                      initialBatchId: '${item['id']}',
                    ),
                  )),
                  leading: const Icon(Icons.space_dashboard_rounded),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'students') {
                        if (await _showAddStudentsToBatch(
                          context,
                          widget.session,
                          initialBatchId: '${item['id']}',
                        )) {
                          await refresh();
                        }
                      } else if (value == 'edit') {
                        await edit(item);
                      } else if (value == 'week') {
                        if (await _changeBatchThisWeek(
                            context, widget.session, item)) {
                          await refresh();
                        }
                      } else if (await _confirm(
                          context, 'Delete this batch?')) {
                        await widget.session.repository
                            .deleteBatch('${item['id']}');
                        await refresh();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'students', child: Text('Add students')),
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                          value: 'week', child: Text('Change this week')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ))),
          ],
        ),
      );
}

class _CompletedSetupStep extends StatelessWidget {
  const _CompletedSetupStep({required this.number, required this.title});
  final String number;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          child:
              Text(number, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w800))),
        const Icon(Icons.check_circle_rounded, color: Colors.green),
      ]),
    );
  }
}

class _PaymentsPage extends StatefulWidget {
  const _PaymentsPage({required this.session});
  final SessionController session;
  @override
  State<_PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<_PaymentsPage> {
  int year = DateTime.now().year, month = DateTime.now().month;
  String? instituteId;
  late Future<List<Map<String, dynamic>>> request = load();
  Future<List<Map<String, dynamic>>> load() async {
    final result = _map(
        await widget.session.repository.batchPaymentRegister(year, month));
    final batchRows = _list(result['batchPayments']);
    if (batchRows.isNotEmpty) return batchRows;
    instituteId ??=
        _strings(widget.session.profile?['instituteIds']).firstOrNull;
    if (instituteId == null) return [];
    return _list(_map(await widget.session.repository
        .payments(instituteId!, year, month))['payments']);
  }

  Future<void> refresh() async {
    setState(() => request = load());
    await request;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<
          List<Map<String, dynamic>>>(
      future: request,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        final paidRows = rows.where((item) => item['paid'] == true).toList();
        final freeRows =
            rows.where((item) => item['freeCard'] == true).toList();
        final dueRows = rows
            .where((item) => item['paid'] != true && item['freeCard'] != true)
            .toList();
        final income = paidRows.fold<double>(
            0,
            (sum, item) =>
                sum +
                ((item['amount'] ?? item['monthlyFee'] ?? item['dailyFee'] ?? 0)
                        as num)
                    .toDouble());
        return _PageFrame(
          title: 'Payments',
          subtitle: 'Batch-wise monthly payment register and income summary.',
          loading: snapshot.connectionState == ConnectionState.waiting,
          error: snapshot.error,
          onRefresh: refresh,
          children: [
            Row(children: [
              Expanded(
                  child: TextFormField(
                      initialValue: '$year',
                      decoration: _input('Year'),
                      keyboardType: TextInputType.number,
                      onChanged: (value) =>
                          year = int.tryParse(value) ?? year)),
              const SizedBox(width: 8),
              Expanded(
                  child: DropdownButtonFormField<int>(
                      initialValue: month,
                      decoration: _input('Month'),
                      items: List.generate(
                          12,
                          (index) => DropdownMenuItem(
                              value: index + 1, child: Text('${index + 1}'))),
                      onChanged: (value) {
                        month = value ?? month;
                        refresh();
                      }))
            ]),
            if (rows.isEmpty && snapshot.connectionState != ConnectionState.waiting)
              const _Message('No student payment records for this month.'),
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                Chip(
                    avatar: const Icon(Icons.payments_outlined, size: 18),
                    label: Text('Income LKR ${income.toStringAsFixed(2)}')),
                Chip(label: Text('Paid ${paidRows.length}')),
                Chip(label: Text('Due ${dueRows.length}')),
                Chip(label: Text('Free cards ${freeRows.length}')),
              ]),
              const SizedBox(height: 8),
            ],
            ...rows.map((payment) => Card(
                    child: ListTile(
                  title: Text(
                      '${payment['studentName'] ?? payment['studentId'] ?? 'Student'}'),
                  subtitle: Text([
                    '${payment['studentId'] ?? ''}',
                    '${payment['batchName'] ?? ''}',
                    '${payment['classType'] ?? payment['batchType'] ?? ''}',
                    '${payment['grade'] ?? ''}',
                    payment['freeCard'] == true
                        ? 'Free card'
                        : payment['paid'] == true
                            ? 'Paid${('${payment['paidAt'] ?? ''}').isEmpty ? '' : ' · ${payment['paidAt']}'}'
                            : 'Payment due',
                    if (payment['feeType'] != null) '${payment['feeType']} fee',
                  ].where((value) => value.isNotEmpty).join(' · ')),
                  trailing: payment['freeCard'] == true
                      ? const Chip(label: Text('Free card'))
                      : payment['paid'] == true
                          ? const Chip(
                              avatar: Icon(Icons.check_circle, size: 18),
                              label: Text('Paid'))
                          : FilledButton(
                              onPressed: '${payment['batchId'] ?? ''}'.isEmpty
                                  ? null
                                  : () async {
                                      final date = DateFormat('yyyy-MM-dd').format(
                                          DateTime(year, month,
                                              DateTime.now().day.clamp(1, 28)));
                                      await widget.session.repository
                                          .markBatchPayment(
                                              '${payment['batchId']}',
                                              '${payment['studentUid']}',
                                              date);
                                      await refresh();
                                    },
                              child: const Text('Mark paid')),
                ))),
          ],
        );
      });
}
