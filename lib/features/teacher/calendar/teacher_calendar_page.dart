part of '../teacher_pages.dart';

enum _CalendarEventKind {
  quiz,
  assignmentOpen,
  assignmentDeadline,
  notice,
  classSession,
  classCancelled,
  reminder,
}

Color _teacherCalendarColour(_CalendarEventKind kind) => switch (kind) {
      _CalendarEventKind.quiz => Colors.purple,
      _CalendarEventKind.assignmentOpen => Colors.blue,
      _CalendarEventKind.assignmentDeadline => Colors.red,
      _CalendarEventKind.notice => Colors.orange,
      _CalendarEventKind.classSession => Colors.green,
      _CalendarEventKind.classCancelled => Colors.grey,
      _CalendarEventKind.reminder => Colors.teal,
    };

String _teacherCalendarLabel(_CalendarEventKind kind) => switch (kind) {
      _CalendarEventKind.quiz => 'Quiz',
      _CalendarEventKind.assignmentOpen => 'Assignment opens',
      _CalendarEventKind.assignmentDeadline => 'Assignment due',
      _CalendarEventKind.notice => 'Notice',
      _CalendarEventKind.classSession => 'Class',
      _CalendarEventKind.classCancelled => 'No class',
      _CalendarEventKind.reminder => 'Reminder',
    };

class _CalendarEvent {
  const _CalendarEvent({
    required this.id,
    required this.title,
    required this.batchName,
    required this.kind,
    required this.date,
    this.batchId = '',
    this.originalDate = '',
    this.startTime = '',
    this.endTime = '',
    this.message = '',
    this.reminder,
  });

  final String id;
  final String title;
  final String batchName;
  final _CalendarEventKind kind;
  final DateTime date;
  final String batchId;
  final String originalDate;
  final String startTime;
  final String endTime;
  final String message;
  final Map<String, dynamic>? reminder;
}

class _TeacherCalendarPage extends StatefulWidget {
  const _TeacherCalendarPage({required this.session});

  final SessionController session;

  @override
  State<_TeacherCalendarPage> createState() => _TeacherCalendarPageState();
}

class _TeacherCalendarPageState extends State<_TeacherCalendarPage> {
  final List<_CalendarEvent> _events = [];
  final List<Map<String, dynamic>> _batches = [];
  final List<Map<String, dynamic>> _reminders = [];
  late DateTime _month;
  late DateTime _selectedDate;
  late int _contentRevision;
  bool _loading = true;
  bool _refreshing = false;
  bool _reloadPending = false;
  final Set<String> _shownDueReminderIds = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _month = DateTime(today.year, today.month);
    _selectedDate = DateTime(today.year, today.month, today.day);
    _contentRevision = widget.session.contentRevision;
    widget.session.addListener(_sessionChanged);
    _load();
  }

  @override
  void dispose() {
    widget.session.removeListener(_sessionChanged);
    super.dispose();
  }

  void _sessionChanged() {
    if (_contentRevision == widget.session.contentRevision) return;
    _contentRevision = widget.session.contentRevision;
    _load(silent: true);
  }

  Future<void> _load({bool refresh = false, bool silent = false}) async {
    if (_refreshing) {
      _reloadPending = true;
      return;
    }
    if (mounted) {
      setState(() {
        _refreshing = true;
        if (!silent && _events.isEmpty) _loading = true;
        _error = null;
      });
    }
    try {
      if (refresh) await widget.session.repository.clearCache();
      final responses = await Future.wait([
        widget.session.repository.batches(),
        widget.session.repository
            .classSchedule('${_month.year}-01-01', '${_month.year + 1}-12-31'),
        widget.session.repository.reminders(refresh: refresh),
      ]);
      final batches = _list(_map(responses[0])['batches']);
      final groups = await Future.wait(batches.map((batch) async {
        final id = '${batch['id'] ?? ''}';
        if (id.isEmpty) {
          return (batch: batch, content: <Map<String, dynamic>>[]);
        }
        final result = await widget.session.repository.batchContent(id);
        return (
          batch: batch,
          content: _list(_map(result)['content']),
        );
      }));
      final events = <_CalendarEvent>[];
      for (final group in groups) {
        final batchName = _title(group.batch);
        for (final item in group.content) {
          events.addAll(_eventsFor(item, batchName: batchName));
        }
      }
      for (final item in _list(_map(responses[1])['occurrences'])) {
        final date = DateTime.tryParse(
            '${item['classDate']}T${item['classStartTime']}:00');
        if (date == null) continue;
        final cancelled = item['scheduleStatus'] == 'cancelled';
        events.add(_CalendarEvent(
          id: 'class-${item['id']}',
          title:
              cancelled ? 'No class this week' : '${item['batchName']} class',
          batchName: '${item['batchName']}',
          kind: cancelled
              ? _CalendarEventKind.classCancelled
              : _CalendarEventKind.classSession,
          date: date,
          batchId: '${item['batchId']}',
          originalDate: '${item['originalDate']}',
          startTime: '${item['classStartTime']}',
          endTime: '${item['classEndTime']}',
          message: '${item['message'] ?? ''}',
        ));
      }
      final reminderItems = _list(_map(responses[2])['reminders']);
      for (final item in reminderItems) {
        final date =
            DateTime.tryParse('${item['reminderAt'] ?? ''}')?.toLocal();
        if (date == null) continue;
        final batch = batches.cast<Map<String, dynamic>?>().firstWhere(
              (value) => '${value?['id'] ?? ''}' == '${item['batchId'] ?? ''}',
              orElse: () => null,
            );
        events.add(_CalendarEvent(
          id: 'reminder-${item['id']}',
          title: '${item['label'] ?? 'Reminder'}',
          batchName: batch == null ? '' : _title(batch),
          kind: _CalendarEventKind.reminder,
          date: date,
          batchId: '${item['batchId'] ?? ''}',
          message: '${item['reason'] ?? ''}',
          reminder: item,
        ));
      }
      events.sort((a, b) => a.date.compareTo(b.date));
      if (!mounted) return;
      setState(() {
        _events
          ..clear()
          ..addAll(events);
        _batches
          ..clear()
          ..addAll(batches);
        _reminders
          ..clear()
          ..addAll(reminderItems);
      });
      final now = DateTime.now();
      final due = reminderItems.where((item) {
        final id = '${item['id'] ?? ''}';
        final at = DateTime.tryParse('${item['reminderAt'] ?? ''}')?.toLocal();
        return id.isNotEmpty &&
            !_shownDueReminderIds.contains(id) &&
            at != null &&
            !at.isAfter(now) &&
            now.difference(at).inHours <= 24;
      }).firstOrNull;
      if (due != null) {
        _shownDueReminderIds.add('${due['id']}');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showDueReminder(due);
        });
      }
    } catch (exception) {
      if (mounted) setState(() => _error = '$exception');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
        if (_reloadPending) {
          _reloadPending = false;
          _load(silent: true);
        }
      }
    }
  }

  Future<void> _showDueReminder(Map<String, dynamic> reminder) async {
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog.fullscreen(
        child: PopScope(
          canPop: false,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.alarm_on_rounded,
                      size: 92, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 20),
                  const Text('Reminder',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('${reminder['label'] ?? 'Calendar reminder'}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 30, fontWeight: FontWeight.w900)),
                  if ('${reminder['reason'] ?? ''}'.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('${reminder['reason']}', textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 30),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(dialogContext, 'stop'),
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('Stop'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(dialogContext, 'snooze'),
                        icon: const Icon(Icons.snooze_rounded),
                        label: const Text('Snooze 1 hour'),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    final id = '${reminder['id'] ?? ''}';
    if (action == 'snooze') {
      await widget.session.repository.snoozeReminder(id);
    } else if (action == 'stop') {
      await widget.session.repository.dismissReminder(id);
    }
    await _load(refresh: true, silent: true);
  }

  List<_CalendarEvent> _eventsFor(
    Map<String, dynamic> item, {
    required String batchName,
  }) {
    final type = '${item['type'] ?? ''}';
    if (!const ['quiz', 'assignment', 'notice'].contains(type)) return const [];
    final contentId = '${item['id'] ?? ''}';
    final raw = '${item['content'] ?? ''}';
    Map<String, dynamic> details = {};
    try {
      details = _map(jsonDecode(raw));
    } catch (_) {
      // Notices and legacy space items are usually stored as plain text.
    }
    final title = _calendarTitle(type, raw, details);
    final events = <_CalendarEvent>[];
    void add(String suffix, _CalendarEventKind kind, dynamic value) {
      final date = _calendarDate(value);
      if (date == null) return;
      events.add(_CalendarEvent(
        id: '$contentId-$suffix',
        title: title,
        batchName: batchName,
        kind: kind,
        date: date,
      ));
    }

    if (type == 'notice') {
      add(
        'notice',
        _CalendarEventKind.notice,
        details['availableAt'] ??
            details['scheduledAt'] ??
            item['createdAt'] ??
            item['updatedAt'],
      );
    } else {
      add(
        'open',
        type == 'quiz'
            ? _CalendarEventKind.quiz
            : _CalendarEventKind.assignmentOpen,
        details['availableAt'] ?? details['upcomingAt'],
      );
      if (type == 'assignment') {
        add(
          'deadline',
          _CalendarEventKind.assignmentDeadline,
          details['deadline'],
        );
      }
    }
    return events;
  }

  String _calendarTitle(String type, String raw, Map<String, dynamic> details) {
    final title = '${details['title'] ?? ''}'.trim();
    if (title.isNotEmpty) return title;
    final questions = _list(details['questions']);
    if (questions.isNotEmpty) {
      final question = '${questions.first['question'] ?? ''}'.trim();
      if (question.isNotEmpty) return question;
    }
    final question = '${details['question'] ?? ''}'.trim();
    if (question.isNotEmpty) return question;
    if (type == 'notice') {
      final plain =
          raw.replaceAll(RegExp(r'\n\n__FILE__:.*$', dotAll: true), '');
      if (plain.trim().isNotEmpty) return plain.trim().split('\n').first;
      return 'Special notice';
    }
    return type == 'quiz' ? 'ICT Quiz' : 'ICT Assignment';
  }

  DateTime? _calendarDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse('$value')?.toLocal();
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  List<_CalendarEvent> get _selectedEvents => _events
      .where((event) => _dateKey(event.date) == _dateKey(_selectedDate))
      .toList();

  void _moveMonth(int amount) {
    setState(() {
      _month = DateTime(_month.year, _month.month + amount);
      _selectedDate = _month;
    });
  }

  void _today() {
    final now = DateTime.now();
    setState(() {
      _month = DateTime(now.year, now.month);
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  Future<void> _changeClass(_CalendarEvent event) async {
    final mode = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.event_busy_outlined),
                  title: const Text('There will be no classes this week'),
                  onTap: () => Navigator.pop(context, 'cancelled')),
              ListTile(
                  leading: const Icon(Icons.edit_calendar_outlined),
                  title: const Text('Reschedule this week only'),
                  onTap: () => Navigator.pop(context, 'rescheduled'))
            ])));
    if (mode == null || !mounted) return;
    var notification = mode == 'cancelled'
        ? 'There will be no classes this week.'
        : 'This week’s class has been rescheduled.';
    String rescheduledDate = '', start = event.startTime, end = event.endTime;
    if (mode == 'rescheduled') {
      final chosenDate = await showDatePicker(
          context: context,
          initialDate: event.date,
          firstDate: DateTime.now().subtract(const Duration(days: 1)),
          lastDate: DateTime.now().add(const Duration(days: 730)));
      if (chosenDate == null || !mounted) return;
      final chosenStart = await showTimePicker(
          context: context, initialTime: TimeOfDay.fromDateTime(event.date));
      if (chosenStart == null || !mounted) return;
      final chosenEnd = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(
              hour: int.tryParse(event.endTime.split(':').first) ??
                  ((chosenStart.hour + 1) % 24),
              minute: int.tryParse(event.endTime.split(':').last) ??
                  chosenStart.minute));
      if (chosenEnd == null || !mounted) return;
      rescheduledDate = DateFormat('yyyy-MM-dd').format(chosenDate);
      start =
          '${chosenStart.hour.toString().padLeft(2, '0')}:${chosenStart.minute.toString().padLeft(2, '0')}';
      end =
          '${chosenEnd.hour.toString().padLeft(2, '0')}:${chosenEnd.minute.toString().padLeft(2, '0')}';
    }
    final messageData = await _showForm(context,
        title: 'Student notification',
        initial: {'message': notification},
        fields: const [_Field('message', 'Custom message', lines: 3)]);
    if (messageData == null || !mounted) return;
    notification = '${messageData['message'] ?? notification}'.trim();
    await _act(
        context,
        () =>
            widget.session.repository.saveClassScheduleOverride(event.batchId, {
              'occurrenceDate': event.originalDate,
              'status': mode,
              'rescheduledDate': rescheduledDate,
              'startTime': mode == 'rescheduled' ? start : '',
              'endTime': mode == 'rescheduled' ? end : '',
              'message': notification
            }),
        'Schedule saved and students notified');
    await _load(refresh: true);
  }

  Future<void> _addReminder([Map<String, dynamic>? existing]) async {
    final existingDate =
        DateTime.tryParse('${existing?['reminderAt'] ?? ''}')?.toLocal();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: existingDate ??
          (_selectedDate.isBefore(DateTime.now())
              ? DateTime.now()
              : _selectedDate),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: existingDate == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay.fromDateTime(existingDate),
    );
    if (pickedTime == null || !mounted) return;
    final batchNames = <String>[
      'Do not target a batch',
      ..._batches.map(_title)
    ];
    final grades = _batches
        .map((batch) => '${batch['grade'] ?? ''}'.trim())
        .where((grade) => grade.isNotEmpty)
        .toSet()
        .toList();
    final existingBatch = _batches.cast<Map<String, dynamic>?>().firstWhere(
          (batch) =>
              batch != null &&
              '${batch['id']}' == '${existing?['batchId'] ?? ''}',
          orElse: () => null,
        );
    final data = await _showForm(
      context,
      title: existing == null ? 'Add calendar reminder' : 'Edit reminder',
      initial: {
        'label': existing?['label'] ?? '',
        'batch':
            existingBatch == null ? batchNames.first : _title(existingBatch),
        'grade': '${existing?['grade'] ?? ''}'.isEmpty
            ? 'Do not target a grade'
            : existing?['grade'],
        'reason': existing?['reason'] ?? '',
        'leadTime': switch ('${existing?['leadTime'] ?? ''}') {
          '3_days' => '3 days before',
          '10_days' => '10 days before',
          _ => 'At the selected date and time',
        },
        'sound': switch ('${existing?['sound'] ?? ''}') {
          'alarm' => 'System alarm',
          'notification' => 'Notification sound',
          'silent' => 'Silent',
          _ => 'System default',
        },
        'shareWithStudents': existing?['shareWithStudents'] == true,
      },
      fields: [
        const _Field('label', 'Reminder label'),
        _Field('batch', 'Class batch',
            kind: _FieldKind.select, options: batchNames),
        _Field('grade', 'Grade',
            kind: _FieldKind.select,
            options: ['Do not target a grade', ...grades]),
        const _Field('reason', 'Reason (optional)', lines: 3),
        const _Field('leadTime', 'Notify me',
            kind: _FieldKind.select,
            options: [
              'At the selected date and time',
              '3 days before',
              '10 days before'
            ]),
        const _Field('sound', 'Reminder sound',
            kind: _FieldKind.select,
            options: [
              'System default',
              'System alarm',
              'Notification sound',
              'Silent'
            ]),
        const _Field('shareWithStudents', 'Share with matching students',
            kind: _FieldKind.boolean),
      ],
    );
    if (data == null || !mounted) return;
    final label = '${data['label'] ?? ''}'.trim();
    if (label.isEmpty) {
      _snack(context, 'Add a reminder label.', error: true);
      return;
    }
    final selectedBatchName = '${data['batch'] ?? ''}';
    final selectedBatch = _batches.cast<Map<String, dynamic>?>().firstWhere(
          (batch) => batch != null && _title(batch) == selectedBatchName,
          orElse: () => null,
        );
    final selectedGrade = data['grade'] == 'Do not target a grade'
        ? ''
        : '${data['grade'] ?? ''}';
    if (data['shareWithStudents'] == true &&
        selectedBatch == null &&
        selectedGrade.isEmpty) {
      _snack(context,
          'Select a class batch or grade before sharing with students.',
          error: true);
      return;
    }
    final reminderAt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    ).toUtc().toIso8601String();
    final lead = switch ('${data['leadTime']}') {
      '3 days before' => '3_days',
      '10 days before' => '10_days',
      _ => 'same_day',
    };
    final reminderSound = switch ('${data['sound']}') {
      'System alarm' => 'alarm',
      'Notification sound' => 'notification',
      'Silent' => 'silent',
      _ => 'system_default',
    };
    final payload = {
      'label': label,
      'batchId': '${selectedBatch?['id'] ?? ''}',
      'grade': selectedGrade,
      'reason': '${data['reason'] ?? ''}',
      'reminderAt': reminderAt,
      'leadTime': lead,
      'shareWithStudents': data['shareWithStudents'] == true,
      'sound': reminderSound,
    };
    await _act(
      context,
      () => existing == null
          ? widget.session.repository.createReminder(payload)
          : widget.session.repository
              .updateReminder('${existing['id']}', payload),
      existing != null
          ? 'Reminder updated.'
          : data['shareWithStudents'] == true
              ? 'Reminder saved for you and matching students.'
              : 'Private teacher reminder saved.',
    );
    await _load(refresh: true, silent: true);
  }

  Future<void> _showReminderHistory() async {
    try {
      final response = await widget.session.repository
          .reminders(history: true, refresh: true);
      final history = _list(_map(response)['reminders']);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: FractionallySizedBox(
            heightFactor: .72,
            child: Column(children: [
              const ListTile(
                  leading: Icon(Icons.history),
                  title: Text('Reminder history'),
                  subtitle: Text('Past and completed reminders')),
              const Divider(height: 1),
              Expanded(
                  child: history.isEmpty
                      ? const Center(child: Text('No reminder history yet.'))
                      : ListView.builder(
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final item = history[index];
                            final date =
                                DateTime.tryParse('${item['reminderAt'] ?? ''}')
                                    ?.toLocal();
                            return ListTile(
                                leading: const Icon(Icons.alarm_on_outlined),
                                title: Text('${item['label'] ?? 'Reminder'}'),
                                subtitle: Text(
                                    '${date == null ? '' : DateFormat('d MMM yyyy, h:mm a').format(date)}${('${item['reason'] ?? ''}').isNotEmpty ? '\n${item['reason']}' : ''}'));
                          })),
            ]),
          ),
        ),
      );
    } catch (error) {
      if (mounted) _snack(context, '$error', error: true);
    }
  }

  Future<void> _showReminderSettings() async {
    try {
      final response =
          await widget.session.repository.notificationPreferences();
      final preferences = _map(_map(response)['preferences']);
      if (!mounted) return;
      final data = await _showForm(context,
          title: 'Reminder settings',
          initial: preferences,
          fields: const [
            _Field('reminders', 'Calendar reminders',
                kind: _FieldKind.boolean, defaultBoolean: true),
            _Field('soundEnabled', 'Reminder sounds',
                kind: _FieldKind.boolean, defaultBoolean: true),
          ]);
      if (data == null || !mounted) return;
      await _act(
          context,
          () => widget.session.repository.saveNotificationPreferences(data),
          'Reminder settings saved.');
    } catch (error) {
      if (mounted) _snack(context, '$error', error: true);
    }
  }

  Future<void> _reminderAction(_CalendarEvent event, String action) async {
    final id = '${event.reminder?['id'] ?? ''}';
    if (id.isEmpty) return;
    if (action == 'edit') {
      await _addReminder(event.reminder);
      return;
    }
    await _act(
      context,
      () => action == 'snooze'
          ? widget.session.repository.snoozeReminder(id)
          : action == 'done'
              ? widget.session.repository.dismissReminder(id)
              : widget.session.repository.deleteReminder(id),
      action == 'snooze'
          ? 'Reminder snoozed for one hour.'
          : action == 'done'
              ? 'Reminder moved to history.'
              : 'Reminder deleted.',
    );
    await _load(refresh: true, silent: true);
  }

  @override
  Widget build(BuildContext context) => _PageFrame(
        title: 'Teaching Calendar',
        subtitle:
            'Quiz openings, assignment dates, deadlines, and special notices from every managed ICT Space.',
        loading: _loading,
        error: _error,
        onRefresh: () => _load(refresh: true),
        actions: [
          IconButton(
            onPressed: _addReminder,
            icon: const Icon(Icons.add_alarm_outlined),
            tooltip: 'Add reminder',
          ),
          IconButton(
            onPressed: _showReminderHistory,
            icon: const Icon(Icons.history),
            tooltip: 'Reminder history',
          ),
          IconButton(
            onPressed: _showReminderSettings,
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Reminder settings',
          ),
          IconButton(
            onPressed: _refreshing ? null : () => _load(refresh: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh calendar',
          ),
        ],
        children: [
          _CalendarMonthHeader(
            month: _month,
            eventCount: _events.length,
            onPrevious: () => _moveMonth(-1),
            onToday: _today,
            onNext: () => _moveMonth(1),
          ),
          const SizedBox(height: 8),
          const _TeacherCalendarLegend(),
          const SizedBox(height: 12),
          _CalendarMonthGrid(
            month: _month,
            selectedDate: _selectedDate,
            events: _events,
            onSelected: (date) => setState(() => _selectedDate = date),
          ),
          const SizedBox(height: 14),
          _CalendarDayEvents(
              date: _selectedDate,
              events: _selectedEvents,
              onChangeClass: _changeClass,
              onReminderAction: _reminderAction),
        ],
      );
}

class _CalendarMonthHeader extends StatelessWidget {
  const _CalendarMonthHeader({
    required this.month,
    required this.eventCount,
    required this.onPrevious,
    required this.onToday,
    required this.onNext,
  });

  final DateTime month;
  final int eventCount;
  final VoidCallback onPrevious;
  final VoidCallback onToday;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(children: [
              Icon(Icons.calendar_month,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('MMMM yyyy').format(month),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$eventCount scheduled ${eventCount == 1 ? 'event' : 'events'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ]),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              IconButton.filledTonal(
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous month',
              ),
              const Spacer(),
              OutlinedButton(onPressed: onToday, child: const Text('Today')),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next month',
              ),
            ]),
          ]),
        ),
      );
}

class _CalendarMonthGrid extends StatelessWidget {
  const _CalendarMonthGrid({
    required this.month,
    required this.selectedDate,
    required this.events,
    required this.onSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final List<_CalendarEvent> events;
  final ValueChanged<DateTime> onSelected;

  String _key(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month);
    final dayCount = DateTime(month.year, month.month + 1, 0).day;
    final leading = firstDay.weekday - 1;
    final cells = leading + dayCount;
    final rows = (cells / 7).ceil();
    final dayEvents = <String, List<_CalendarEvent>>{};
    for (final event in events) {
      (dayEvents[_key(event.date)] ??= <_CalendarEvent>[]).add(event);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          Row(
            children: [
              for (final label in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Text(label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows * 7,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
              childAspectRatio: .77,
            ),
            itemBuilder: (context, index) {
              final day = index - leading + 1;
              if (day < 1 || day > dayCount) return const SizedBox.shrink();
              final date = DateTime(month.year, month.month, day);
              final datedEvents =
                  dayEvents[_key(date)] ?? const <_CalendarEvent>[];
              final count = datedEvents.length;
              final selected = _key(date) == _key(selectedDate);
              final scheme = Theme.of(context).colorScheme;
              return InkWell(
                onTap: () => onSelected(date),
                borderRadius: BorderRadius.circular(11),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primaryContainer
                        : count > 0
                            ? scheme.primary.withValues(alpha: .055)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: selected ? scheme.primary : scheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$day',
                          style: TextStyle(
                              fontWeight: selected
                                  ? FontWeight.w900
                                  : FontWeight.w800)),
                      if (count > 0) ...[
                        const SizedBox(height: 3),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 2,
                          runSpacing: 2,
                          children: datedEvents
                              .take(8)
                              .map((event) => Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _teacherCalendarColour(event.kind),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ]),
      ),
    );
  }
}

class _TeacherCalendarLegend extends StatelessWidget {
  const _TeacherCalendarLegend();

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 10,
        runSpacing: 7,
        children: _CalendarEventKind.values
            .map((kind) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _teacherCalendarColour(kind),
                        )),
                    const SizedBox(width: 4),
                    Text(_teacherCalendarLabel(kind),
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                ))
            .toList(),
      );
}

class _CalendarDayEvents extends StatelessWidget {
  const _CalendarDayEvents(
      {required this.date,
      required this.events,
      required this.onChangeClass,
      required this.onReminderAction});

  final DateTime date;
  final List<_CalendarEvent> events;
  final ValueChanged<_CalendarEvent> onChangeClass;
  final void Function(_CalendarEvent, String) onReminderAction;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(
              DateFormat('EEEE, d MMMM yyyy').format(date),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (events.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Text('Nothing scheduled for this date.',
                    textAlign: TextAlign.center),
              ),
            ...events.map((event) => _CalendarEventTile(
                event: event,
                onChangeClass: onChangeClass,
                onReminderAction: onReminderAction)),
          ]),
        ),
      );
}

class _CalendarEventTile extends StatelessWidget {
  const _CalendarEventTile(
      {required this.event,
      required this.onChangeClass,
      required this.onReminderAction});

  final _CalendarEvent event;
  final ValueChanged<_CalendarEvent> onChangeClass;
  final void Function(_CalendarEvent, String) onReminderAction;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (event.kind) {
      _CalendarEventKind.quiz => (
          Icons.quiz_outlined,
          'Quiz opens',
          Theme.of(context).colorScheme.primary
        ),
      _CalendarEventKind.assignmentOpen => (
          Icons.assignment_outlined,
          'Assignment opens',
          Theme.of(context).colorScheme.tertiary
        ),
      _CalendarEventKind.assignmentDeadline => (
          Icons.timer_outlined,
          'Assignment deadline',
          Theme.of(context).colorScheme.error
        ),
      _CalendarEventKind.notice => (
          Icons.campaign_outlined,
          'Special notice published',
          Colors.orange
        ),
      _CalendarEventKind.classSession => (
          Icons.schedule_outlined,
          'Weekly class',
          Theme.of(context).colorScheme.primary
        ),
      _CalendarEventKind.classCancelled => (
          Icons.event_busy_outlined,
          'No class this week',
          Theme.of(context).colorScheme.error
        ),
      _CalendarEventKind.reminder => (
          Icons.alarm_on_outlined,
          event.reminder?['shareWithStudents'] == true
              ? 'Shared reminder'
              : 'Private teacher reminder',
          Theme.of(context).colorScheme.secondary
        ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .35)),
          color: color.withValues(alpha: .08),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: .14),
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(width: 11),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text('${event.batchName} · $label'),
              Text(
                event.kind == _CalendarEventKind.classSession ||
                        event.kind == _CalendarEventKind.classCancelled
                    ? '${event.startTime}–${event.endTime}${event.message.isNotEmpty ? '\n${event.message}' : ''}'
                    : DateFormat('h:mm a').format(event.date),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (event.kind == _CalendarEventKind.classSession ||
                  event.kind == _CalendarEventKind.classCancelled)
                Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                        onPressed: () => onChangeClass(event),
                        icon:
                            const Icon(Icons.edit_calendar_outlined, size: 18),
                        label: const Text('Change this week'))),
              if (event.kind == _CalendarEventKind.reminder)
                Wrap(alignment: WrapAlignment.end, spacing: 4, children: [
                  IconButton(
                      onPressed: () => onReminderAction(event, 'edit'),
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit reminder'),
                  TextButton(
                      onPressed: () => onReminderAction(event, 'snooze'),
                      child: const Text('Snooze 1 hour')),
                  TextButton(
                      onPressed: () => onReminderAction(event, 'done'),
                      child: const Text('Done')),
                  IconButton(
                      onPressed: () => onReminderAction(event, 'delete'),
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete reminder'),
                ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
