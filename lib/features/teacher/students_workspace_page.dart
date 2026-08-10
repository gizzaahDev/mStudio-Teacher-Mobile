part of 'teacher_pages.dart';

enum _StudentWorkspaceTab { details, attendance, marks }

class _StudentsPage extends StatefulWidget {
  const _StudentsPage({required this.session});
  final SessionController session;
  @override
  State<_StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<_StudentsPage> {
  late Future<dynamic> request = _load();
  _StudentWorkspaceTab activeTab = _StudentWorkspaceTab.details;
  String studentQuery = '';
  bool showPending = false;
  String? quickBatchId;

  int paymentYear = DateTime.now().year;
  int paymentMonth = DateTime.now().month;
  String? paymentInstituteId;
  String paymentQuery = '';
  List<Map<String, dynamic>> paymentRows = [];
  bool paymentLoading = false, paymentLoaded = false;
  String savingPaymentUid = '';

  String? attendanceBatchId;
  String attendanceClassType = '';
  DateTime attendanceDate = DateTime.now();
  Map<String, int> attendanceValues = {};
  Map<String, String> attendanceMarkedTimes = {};
  bool attendanceReady = false;
  bool attendanceLoading = false, attendanceSaving = false;

  String? marksBatchId;
  String marksTitle = '', marksCategory = '', marksTotal = '100';
  String marksDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final Map<String, String> marks = {};
  bool marksSaving = false;

  Future<dynamic> _load() => Future.wait([
        widget.session.repository.students(),
        widget.session.repository.pendingStudents(),
        widget.session.repository.batches(),
        widget.session.repository.appSettings(),
      ]);

  Future<void> _refresh() async {
    setState(() => request = _load());
    await request;
  }

  Future<void> _selectTab(_StudentWorkspaceTab tab) async {
    setState(() {
      activeTab = tab;
      if (tab == _StudentWorkspaceTab.marks) marksBatchId = null;
    });
  }

  Future<void> _approve(Map<String, dynamic> student) async {
    final saved = await _act(
      context,
      () => widget.session.repository
          .approveStudent('${student['uid'] ?? student['id']}'),
      'Student access approved',
    );
    if (saved) await _refresh();
  }

  Future<void> _showStudentDetails(
    Map<String, dynamic> student, {
    bool pending = false,
  }) async {
    if (!mounted) return;
    final free = student['freeCard'] == true || student['isFreeCard'] == true;
    final details = <(String, String)>[
      ('Student ID', '${student['studentId'] ?? 'Pending'}'),
      ('Name', _title(student)),
      ('First name', '${student['firstName'] ?? ''}'),
      ('Last name', '${student['lastName'] ?? ''}'),
      ('Grade', '${student['grade'] ?? 'Not set'}'),
      ('Email', '${student['email'] ?? ''}'),
      ('Parent email', '${student['parentEmail'] ?? ''}'),
      ('Phone', '${student['phone'] ?? ''}'),
      ('Birthday', '${student['birthday'] ?? ''}'),
      ('Institute', '${student['instituteName'] ?? ''}'),
      (
        'Status',
        pending ? 'Pending approval' : '${student['status'] ?? 'Approved'}'
      ),
      ('Fee access', free ? 'Free card student' : 'Normal fee student'),
      ('Batches', _strings(student['batchIds']).join(', ')),
    ];
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(children: [
          const CircleAvatar(child: Icon(Icons.person_outline)),
          const SizedBox(width: 10),
          Expanded(child: Text(_title(student))),
        ]),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              children: details
                  .where((item) => item.$2.trim().isNotEmpty)
                  .map((item) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.$1),
                        subtitle: Text(item.$2),
                      ))
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close')),
          if (!pending)
            OutlinedButton(
                onPressed: () => Navigator.pop(dialogContext, 'manage'),
                child: const Text('Manage')),
          if (pending)
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, 'approve'),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Approve student'),
            ),
        ],
      ),
    );
    if (action == 'approve') await _approve(student);
    if (action == 'manage') await _editStudent(student);
  }

  Future<void> _showPendingRequests(List<Map<String, dynamic>> pending) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Pending student requests (${pending.length})'),
        content: SizedBox(
          width: 460,
          child: pending.isEmpty
              ? const _Message('No pending student requests.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: pending.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final student = pending[index];
                    return ListTile(
                      leading: const CircleAvatar(
                          child: Icon(Icons.person_add_alt_1_outlined)),
                      title: Text(_title(student)),
                      subtitle: Text(
                          '${student['grade'] ?? 'Grade not set'} · ${student['email'] ?? ''}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(dialogContext);
                        _showStudentDetails(student, pending: true);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _editStudent(Map<String, dynamic> student) async {
    final data = await _showForm(
      context,
      title: 'Manage student',
      initial: {
        ...student,
        'freeCard':
            student['freeCard'] == true || student['isFreeCard'] == true,
      },
      fields: const [
        _Field('displayName', 'Display name'),
        _Field('grade', 'Grade'),
        _Field('firstName', 'First name'),
        _Field('lastName', 'Last name'),
        _Field('parentEmail', 'Parent email'),
        _Field('freeCard', 'Free card student', kind: _FieldKind.boolean),
      ],
    );
    if (data == null || !mounted) return;
    final saved = await _act(
      context,
      () => widget.session.repository
          .updateStudent('${student['uid'] ?? student['id']}', data),
      'Student details saved',
    );
    if (saved) {
      paymentLoaded = false;
      await _refresh();
    }
  }

  Future<void> _assignStudent(
    Map<String, dynamic> student,
    List<Map<String, dynamic>> batches, [
    String? preferredBatchId,
  ]) async {
    final joined = _strings(student['batchIds']);
    final available =
        batches.where((batch) => !joined.contains('${batch['id']}')).toList();
    if (available.isEmpty) {
      _snack(context, 'This student is already in every available batch');
      return;
    }
    var batchId = preferredBatchId;
    if (batchId == null ||
        !available.any((batch) => '${batch['id']}' == batchId)) {
      batchId = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Add student to batch'),
          children: available
              .map((batch) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, '${batch['id']}'),
                    child: Text(_title(batch)),
                  ))
              .toList(),
        ),
      );
    }
    if (batchId == null || !mounted) return;
    final batch = batches.firstWhere((item) => '${item['id']}' == batchId);
    final saved = await _act(
      context,
      () => widget.session.repository.assignStudent(
        '${student['uid'] ?? student['id']}',
        batchId!,
        '${batch['name']}',
      ),
      'Student added to batch',
    );
    if (saved) await _refresh();
  }

  List<String> get _instituteIds {
    final ids = _strings(widget.session.profile?['instituteIds']);
    if (paymentInstituteId == null && ids.isNotEmpty) {
      paymentInstituteId = ids.first;
    }
    return ids;
  }

  String _instituteLabel(String id) {
    final institutes = _list(widget.session.profile?['institutes']);
    final institute =
        institutes.where((item) => '${item['id']}' == id).firstOrNull;
    return institute == null ? id : _title(institute);
  }

  Future<void> _loadPayments() async {
    final ids = _instituteIds;
    if (ids.isEmpty) {
      if (mounted) {
        setState(() {
          paymentRows = [];
          paymentLoaded = true;
          paymentLoading = false;
        });
      }
      return;
    }
    paymentInstituteId ??= ids.first;
    setState(() => paymentLoading = true);
    try {
      final response = await widget.session.repository.payments(
        paymentInstituteId!,
        paymentYear,
        paymentMonth,
      );
      if (mounted) {
        setState(() {
          paymentRows = _list(_map(response)['payments']);
          paymentLoaded = true;
        });
      }
    } catch (error) {
      if (mounted) _snack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => paymentLoading = false);
    }
  }

  Future<void> _setPaid(Map<String, dynamic> row, bool paid) async {
    final uid = '${row['studentUid']}';
    setState(() {
      savingPaymentUid = '$uid-paid';
      row['paid'] = paid;
    });
    try {
      await widget.session.repository.savePayment(uid, {
        'instituteId': paymentInstituteId,
        'year': paymentYear,
        'month': paymentMonth,
        'paid': paid,
      });
      if (mounted) _snack(context, paid ? 'Marked as paid' : 'Payment removed');
    } catch (error) {
      row['paid'] = !paid;
      if (mounted) _snack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => savingPaymentUid = '');
    }
  }

  Future<void> _setFreeCard(Map<String, dynamic> row, bool enabled) async {
    final uid = '${row['studentUid']}';
    setState(() {
      savingPaymentUid = '$uid-free';
      row['freeCard'] = enabled;
    });
    try {
      await widget.session.repository.updateStudent(uid, {'freeCard': enabled});
      if (mounted) {
        _snack(context, enabled ? 'Free card enabled' : 'Free card removed');
      }
    } catch (error) {
      row['freeCard'] = !enabled;
      if (mounted) _snack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => savingPaymentUid = '');
    }
  }

  List<Map<String, dynamic>> _batchStudents(
    List<Map<String, dynamic>> students,
    String? batchId,
  ) =>
      students
          .where((student) =>
              batchId != null &&
              _strings(student['batchIds']).contains(batchId))
          .toList()
        ..sort(
          (left, right) => '${left['studentId'] ?? ''}'
              .compareTo('${right['studentId'] ?? ''}'),
        );

  Future<void> _openAttendance(
    List<Map<String, dynamic>> students,
  ) async {
    if (attendanceBatchId == null || attendanceClassType.isEmpty) {
      _snack(context, 'Select a batch and class type first', error: true);
      return;
    }
    final selectedStudents = _batchStudents(students, attendanceBatchId);
    if (selectedStudents.isEmpty) {
      _snack(context, 'No approved students are enrolled in this batch',
          error: true);
      return;
    }
    setState(() => attendanceLoading = true);
    try {
      final date = DateFormat('yyyy-MM-dd').format(attendanceDate);
      final response = await widget.session.repository.getAttendance(
        attendanceBatchId!,
        attendanceClassType,
        date,
      );
      final records = _list(_map(_map(response)['session'])['records']);
      final loaded = <String, int>{
        for (final student in selectedStudents)
          '${student['uid'] ?? student['id']}': 0,
        for (final record in records)
          '${record['studentUid']}': record['attendance'] == 1 ? 1 : 0,
      };
      if (mounted) {
        setState(() {
          attendanceValues = loaded;
          attendanceMarkedTimes = {
            for (final record in records)
              if (record['attendanceMarkedAt'] != null)
                '${record['studentUid']}': '${record['attendanceMarkedAt']}',
          };
          attendanceReady = true;
        });
      }
    } catch (error) {
      if (mounted) _snack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => attendanceLoading = false);
    }
  }

  Future<void> _saveAttendance(
    List<Map<String, dynamic>> students,
  ) async {
    final selectedStudents = _batchStudents(students, attendanceBatchId);
    if (!attendanceReady ||
        attendanceBatchId == null ||
        selectedStudents.isEmpty) {
      _snack(context, 'Open an attendance register first', error: true);
      return;
    }
    setState(() => attendanceSaving = true);
    try {
      await widget.session.repository.saveAttendance(attendanceBatchId!, {
        'classType': attendanceClassType,
        'date': DateFormat('yyyy-MM-dd').format(attendanceDate),
        'records': selectedStudents.map((student) {
          final uid = '${student['uid'] ?? student['id']}';
          return {'studentUid': uid, 'attendance': attendanceValues[uid] ?? 0};
        }).toList(),
      });
      if (mounted) _snack(context, 'Attendance saved');
    } catch (error) {
      if (mounted) _snack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => attendanceSaving = false);
    }
  }

  Future<void> _pickAttendanceYear() async {
    final controller = TextEditingController(text: '${attendanceDate.year}');
    final year = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attendance year'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: _input('Year'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (year == null || year < 2020 || year > 2100 || !mounted) return;
    setState(() {
      final day = attendanceDate.day.clamp(
        1,
        DateUtils.getDaysInMonth(year, attendanceDate.month),
      );
      attendanceDate = DateTime(year, attendanceDate.month, day);
      attendanceReady = false;
    });
  }

  Future<void> _saveMarks(List<Map<String, dynamic>> students) async {
    final selectedStudents = _batchStudents(students, marksBatchId);
    final total = num.tryParse(marksTotal);
    if (marksBatchId == null ||
        marksTitle.trim().isEmpty ||
        total == null ||
        total <= 0 ||
        DateTime.tryParse(marksDate) == null) {
      _snack(context, 'Complete the result name, date, and total marks',
          error: true);
      return;
    }
    final entered = <Map<String, dynamic>>[];
    for (final student in selectedStudents) {
      final uid = '${student['uid'] ?? student['id']}';
      final raw = marks[uid]?.trim() ?? '';
      if (raw.isEmpty) continue;
      final score = num.tryParse(raw);
      if (score == null || score < 0 || score > total) {
        _snack(context, 'Every mark must be between 0 and $total', error: true);
        return;
      }
      entered.add({'studentUid': uid, 'score': score});
    }
    if (entered.isEmpty) {
      _snack(context, 'Enter at least one student mark', error: true);
      return;
    }
    setState(() => marksSaving = true);
    try {
      final date = DateTime.parse(marksDate).add(const Duration(hours: 12));
      await widget.session.repository.createResultSheet(marksBatchId!, {
        'title': marksTitle.trim(),
        'category': marksCategory,
        'total': total,
        'resultDate': date.toUtc().toIso8601String(),
        'marks': entered,
      });
      if (mounted) {
        setState(() {
          marks.clear();
          marksTitle = '';
        });
        _snack(context, '${entered.length} student marks saved');
      }
    } catch (error) {
      if (mounted) _snack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => marksSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
        future: request,
        builder: (context, snapshot) {
          final values =
              snapshot.data is List ? snapshot.data as List : const [];
          final approved = values.isNotEmpty
              ? _list(_map(values[0])['students'])
              : <Map<String, dynamic>>[];
          final pending = values.length > 1
              ? _list(_map(values[1])['students'])
              : <Map<String, dynamic>>[];
          final batches = values.length > 2
              ? _list(_map(values[2])['batches'])
              : <Map<String, dynamic>>[];
          final settings = values.length > 3
              ? _map(_map(values[3])['settings'])
              : <String, dynamic>{};
          final categories = _strings(settings['resultCategories']);
          if (marksCategory.isEmpty && categories.isNotEmpty) {
            marksCategory = categories.first;
          }
          return _PageFrame(
            title: 'Students',
            subtitle:
                'Update students, payments, monthly attendance, and marks in one place.',
            loading: snapshot.connectionState == ConnectionState.waiting,
            error: snapshot.error,
            onRefresh: _refresh,
            children: [
              if (snapshot.hasData) ...[
                _workspaceTabs(),
                const SizedBox(height: 16),
                switch (activeTab) {
                  _StudentWorkspaceTab.details =>
                    _studentDetails(approved, pending, batches),
                  _StudentWorkspaceTab.attendance =>
                    _attendancePanel(approved, batches),
                  _StudentWorkspaceTab.marks =>
                    _marksPanel(approved, batches, categories),
                },
              ],
            ],
          );
        },
      );

  Widget _workspaceTabs() {
    const tabs = [
      (_StudentWorkspaceTab.details, 'Student details', Icons.people_outline),
      (
        _StudentWorkspaceTab.attendance,
        'Monthly attendance',
        Icons.calendar_month_outlined
      ),
      (_StudentWorkspaceTab.marks, 'Marks', Icons.menu_book_outlined),
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
                    onPressed: () => _selectTab(tab.$1),
                    icon: Icon(tab.$3, size: 18),
                    label: Text(tab.$2),
                  )
                : OutlinedButton.icon(
                    onPressed: () => _selectTab(tab.$1),
                    icon: Icon(tab.$3, size: 18),
                    label: Text(tab.$2),
                  ),
          );
        }).toList(),
      ),
    );
  }

  Widget _studentDetails(
    List<Map<String, dynamic>> approved,
    List<Map<String, dynamic>> pending,
    List<Map<String, dynamic>> batches,
  ) {
    final term = studentQuery.trim().toLowerCase();
    final visible = approved.where((student) {
      if (term.isEmpty) return true;
      return [
        student['displayName'],
        student['firstName'],
        student['lastName'],
        student['studentId'],
        student['phone'],
        student['email'],
        student['grade'],
        student['instituteName'],
      ].join(' ').toLowerCase().contains(term);
    }).toList();

    return Column(
      children: [
        if (showPending && pending.isNotEmpty)
          _studentCard(
            title: 'Student access requests',
            subtitle: 'Approve students before adding them to teacher batches.',
            children: pending
                .map(
                  (student) => Card(
                    child: ListTile(
                      title: Text(_title(student)),
                      subtitle: Text(
                        '${student['studentId'] ?? 'ID pending'} - '
                        '${student['grade'] ?? 'Grade not set'}',
                      ),
                      trailing: FilledButton(
                        onPressed: () => _approve(student),
                        child: const Text('Approve'),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        if (showPending && pending.isNotEmpty) const SizedBox(height: 12),
        _studentCard(
          title: 'Approved student directory',
          subtitle:
              'Edit learning details, free cards, and batch assignments. Account email and phone stay read-only.',
          children: [
            OutlinedButton.icon(
              onPressed: () => _showPendingRequests(pending),
              icon: const Icon(Icons.how_to_reg_outlined),
              label: Text('Pending students (${pending.length})'),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration:
                  _input('Search name, ID, institute, grade, email, or phone'),
              onChanged: (value) => setState(() => studentQuery = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('quick-${quickBatchId ?? ''}'),
              initialValue:
                  batches.any((batch) => '${batch['id']}' == quickBatchId)
                      ? quickBatchId
                      : null,
              decoration: _input('Batch for quick add'),
              items: batches
                  .map(
                    (batch) => DropdownMenuItem(
                      value: '${batch['id']}',
                      child: Text(_title(batch)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => quickBatchId = value),
            ),
            const SizedBox(height: 14),
            if (visible.isEmpty) const _Message('No approved students found.'),
            ...visible.map((student) {
              final joined = quickBatchId != null &&
                  _strings(student['batchIds']).contains(quickBatchId);
              final free =
                  student['freeCard'] == true || student['isFreeCard'] == true;
              final name = _title(student);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                  child: Column(
                    children: [
                      ListTile(
                        onTap: () => _showStudentDetails(student),
                        leading: CircleAvatar(
                          backgroundImage: '${student['profileImageUrl'] ?? ''}'
                                  .isEmpty
                              ? null
                              : NetworkImage('${student['profileImageUrl']}'),
                          child: '${student['profileImageUrl'] ?? ''}'.isEmpty
                              ? Text(name.isEmpty ? 'S' : name[0].toUpperCase())
                              : null,
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(name)),
                            if (free)
                              const Chip(
                                label: Text('Free card'),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                        subtitle: Text(
                          '${student['studentId'] ?? 'ID pending'} - '
                          '${student['grade'] ?? 'Grade not set'}\n'
                          '${student['email'] ?? ''}',
                        ),
                        isThreeLine: true,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _editStudent(student),
                                icon: const Icon(Icons.manage_accounts),
                                label: const Text('Manage'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: quickBatchId == null || joined
                                    ? null
                                    : () => _assignStudent(
                                          student,
                                          batches,
                                          quickBatchId,
                                        ),
                                child: Text(
                                  joined ? 'Already added' : 'Add to batch',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _paymentsPanel() {
    final ids = _instituteIds;
    final visible = paymentRows.where((row) {
      final term = paymentQuery.trim().toLowerCase();
      return term.isEmpty ||
          [row['studentId'], row['studentName'], row['grade']]
              .join(' ')
              .toLowerCase()
              .contains(term);
    }).toList();
    final paid = paymentRows
        .where((row) => row['paid'] == true && row['freeCard'] != true)
        .length;
    final free = paymentRows.where((row) => row['freeCard'] == true).length;
    String paidDate(Map<String, dynamic> row) {
      final value = DateTime.tryParse('${row['paidAt'] ?? ''}');
      return value == null
          ? ''
          : DateFormat.yMMMd().add_jm().format(value.toLocal());
    }

    return _studentCard(
      title: 'Monthly payment register',
      subtitle:
          'Choose an institute and month, then update free-card and paid status.',
      children: [
        if (ids.isEmpty)
          const _Message(
              'Add an institute to your teacher profile before managing payments.'),
        if (ids.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            key: ValueKey('institute-${paymentInstituteId ?? ''}'),
            initialValue: ids.contains(paymentInstituteId)
                ? paymentInstituteId
                : ids.first,
            decoration: _input('Institute'),
            items: ids
                .map((id) => DropdownMenuItem(
                      value: id,
                      child: Text(_instituteLabel(id)),
                    ))
                .toList(),
            onChanged: (value) {
              paymentInstituteId = value;
              _loadPayments();
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('payment-year-$paymentYear'),
                  initialValue: '$paymentYear',
                  keyboardType: TextInputType.number,
                  decoration: _input('Year'),
                  onFieldSubmitted: (value) {
                    paymentYear = int.tryParse(value) ?? paymentYear;
                    _loadPayments();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _loadPayments,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh register',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(12, (index) {
              final month = index + 1;
              return ChoiceChip(
                label: Text(DateFormat('MMM').format(DateTime(2024, month))),
                selected: paymentMonth == month,
                onSelected: (_) {
                  setState(() => paymentMonth = month);
                  _loadPayments();
                },
              );
            }),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _metricCard('Students', paymentRows.length)),
              const SizedBox(width: 8),
              Expanded(child: _metricCard('Paid', paid)),
              const SizedBox(width: 8),
              Expanded(child: _metricCard('Free', free)),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            decoration: _input('Search index, name, or grade'),
            onChanged: (value) => setState(() => paymentQuery = value),
          ),
          const SizedBox(height: 12),
          _DelayedLoading(loading: paymentLoading),
          if (!paymentLoading && visible.isEmpty)
            const _Message('No students are assigned to this register.'),
          ...visible.map(
            (row) => Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                        '${row['studentName'] ?? row['studentId'] ?? 'Student'}'),
                    subtitle: Text(
                      '${row['studentId'] ?? 'ID pending'} - '
                      '${row['grade'] ?? 'Grade not set'}'
                      '${paidDate(row).isNotEmpty ? '\nPaid: ${paidDate(row)}' : ''}',
                    ),
                    isThreeLine: paidDate(row).isNotEmpty,
                    trailing: Chip(
                      label: Text(
                        row['freeCard'] == true
                            ? 'Free card'
                            : row['paid'] == true
                                ? 'Paid'
                                : 'Pending',
                      ),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Free card'),
                    value: row['freeCard'] == true,
                    onChanged: savingPaymentUid == '${row['studentUid']}-free'
                        ? null
                        : (value) => _setFreeCard(row, value),
                  ),
                  SwitchListTile(
                    title: Text(
                      '${DateFormat('MMMM').format(DateTime(paymentYear, paymentMonth))} paid',
                    ),
                    value: row['paid'] == true,
                    onChanged: row['freeCard'] == true ||
                            savingPaymentUid == '${row['studentUid']}-paid'
                        ? null
                        : (value) => _setPaid(row, value),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _attendancePanel(
    List<Map<String, dynamic>> students,
    List<Map<String, dynamic>> batches,
  ) {
    final selectedBatch = batches
        .where((batch) => '${batch['id']}' == attendanceBatchId)
        .firstOrNull;
    final classTypes = _strings(selectedBatch?['classTypes']);
    final selectedStudents = _batchStudents(students, attendanceBatchId);
    final days = DateUtils.getDaysInMonth(
      attendanceDate.year,
      attendanceDate.month,
    );
    final present = selectedStudents
        .where((student) =>
            attendanceValues['${student['uid'] ?? student['id']}'] == 1)
        .length;

    return Column(
      children: [
        _studentCard(
          title: 'Monthly attendance register',
          subtitle:
              'Open a month and date, select a batch, then mark and save attendance.',
          children: [
            OutlinedButton.icon(
              onPressed: _pickAttendanceYear,
              icon: const Icon(Icons.event),
              label: Text('Year ${attendanceDate.year}'),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(12, (index) {
                final month = index + 1;
                return ChoiceChip(
                  label: Text(DateFormat('MMM').format(DateTime(2024, month))),
                  selected: attendanceDate.month == month,
                  onSelected: (_) => setState(() {
                    final day = attendanceDate.day.clamp(
                      1,
                      DateUtils.getDaysInMonth(attendanceDate.year, month),
                    );
                    attendanceDate = DateTime(attendanceDate.year, month, day);
                    attendanceReady = false;
                  }),
                );
              }),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: List.generate(days, (index) {
                final day = index + 1;
                return ChoiceChip(
                  label: Text('$day'),
                  selected: attendanceDate.day == day,
                  onSelected: (_) => setState(() {
                    attendanceDate = DateTime(
                      attendanceDate.year,
                      attendanceDate.month,
                      day,
                    );
                    attendanceReady = false;
                  }),
                );
              }),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey('attendance-batch-${attendanceBatchId ?? ''}'),
              initialValue:
                  batches.any((batch) => '${batch['id']}' == attendanceBatchId)
                      ? attendanceBatchId
                      : null,
              decoration: _input('Batch'),
              items: batches
                  .map((batch) => DropdownMenuItem(
                        value: '${batch['id']}',
                        child: Text(_title(batch)),
                      ))
                  .toList(),
              onChanged: (value) => setState(() {
                attendanceBatchId = value;
                final batch = batches
                    .where((item) => '${item['id']}' == value)
                    .firstOrNull;
                attendanceClassType =
                    _strings(batch?['classTypes']).firstOrNull ?? '';
                attendanceReady = false;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(
                  'attendance-type-$attendanceBatchId-$attendanceClassType'),
              initialValue: classTypes.contains(attendanceClassType)
                  ? attendanceClassType
                  : null,
              decoration: _input('Class type'),
              items: classTypes
                  .map((type) =>
                      DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (value) => setState(() {
                attendanceClassType = value ?? '';
                attendanceReady = false;
              }),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed:
                  attendanceLoading ? null : () => _openAttendance(students),
              icon: attendanceLoading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.calendar_month),
              label: Text(
                attendanceLoading
                    ? 'Opening...'
                    : attendanceReady
                        ? 'Reload attendance register'
                        : 'Open attendance register',
              ),
            ),
          ],
        ),
        if (attendanceReady) ...[
          const SizedBox(height: 12),
          _studentCard(
            title: selectedBatch == null
                ? 'Student attendance'
                : _title(selectedBatch),
            subtitle: '${DateFormat('yyyy-MM-dd').format(attendanceDate)} - '
                '$attendanceClassType - $present present / '
                '${selectedStudents.length} students',
            children: [
              ...selectedStudents.map((student) {
                final uid = '${student['uid'] ?? student['id']}';
                return Card(
                  child: SwitchListTile(
                    title: Text(_title(student)),
                    subtitle: Text([
                      '${student['studentId'] ?? 'ID pending'}',
                      if (DateTime.tryParse(attendanceMarkedTimes[uid] ?? '') !=
                          null)
                        'Scanned ${DateFormat.yMMMd().add_jm().format(DateTime.parse(attendanceMarkedTimes[uid]!).toLocal())}',
                    ].join('\n')),
                    value: attendanceValues[uid] == 1,
                    onChanged: (value) => setState(
                      () => attendanceValues[uid] = value ? 1 : 0,
                    ),
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed:
                      attendanceSaving ? null : () => _saveAttendance(students),
                  icon: const Icon(Icons.save_outlined),
                  label:
                      Text(attendanceSaving ? 'Saving...' : 'Save attendance'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _marksPanel(
    List<Map<String, dynamic>> students,
    List<Map<String, dynamic>> batches,
    List<String> categories,
  ) {
    if (marksBatchId == null) {
      return _studentCard(
        title: 'Select a batch for marks',
        subtitle: 'Each batch opens its own student marks form.',
        children: [
          if (batches.isEmpty)
            const _Message('Create a batch before adding marks.'),
          ...batches.map((batch) {
            final count = _batchStudents(students, '${batch['id']}').length;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(_title(batch)),
                subtitle: Text(
                  '${batch['grade'] ?? ''} - $count students\n'
                  '${_strings(batch['classTypes']).join(', ')}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() {
                  marksBatchId = '${batch['id']}';
                  marks.clear();
                  marksTitle = '';
                }),
              ),
            );
          }),
        ],
      );
    }

    final batch =
        batches.where((item) => '${item['id']}' == marksBatchId).firstOrNull;
    final selectedStudents = _batchStudents(students, marksBatchId);
    final availableCategories =
        categories.isEmpty ? const ['Paper'] : categories;
    if (!availableCategories.contains(marksCategory)) {
      marksCategory = availableCategories.first;
    }

    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => marksBatchId = null),
            icon: const Icon(Icons.arrow_back),
            label: const Text('All batches'),
          ),
        ),
        const SizedBox(height: 12),
        _studentCard(
          title: batch == null ? 'Result sheet' : _title(batch),
          subtitle:
              'Enter result details and save all entered student marks together.',
          children: [
            TextFormField(
              key: ValueKey('marks-title-$marksBatchId-$marksTitle'),
              initialValue: marksTitle,
              decoration: _input('Paper / result name'),
              onChanged: (value) => marksTitle = value,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('marks-category-$marksCategory'),
              initialValue: marksCategory,
              decoration: _input('Result type'),
              items: availableCategories
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) => marksCategory = value ?? marksCategory,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: marksTotal,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _input('Total marks'),
              onChanged: (value) => marksTotal = value,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: marksDate,
              keyboardType: TextInputType.datetime,
              decoration: _input('Result date (YYYY-MM-DD)'),
              onChanged: (value) => marksDate = value,
            ),
            const SizedBox(height: 16),
            if (selectedStudents.isEmpty)
              const _Message('No students are assigned to this batch.'),
            ...selectedStudents.asMap().entries.map((entry) {
              final index = entry.key;
              final student = entry.value;
              final uid = '${student['uid'] ?? student['id']}';
              return Card(
                child: ListTile(
                  title: Text(_title(student)),
                  subtitle: Text('${student['studentId'] ?? 'ID pending'}'),
                  trailing: SizedBox(
                    width: 92,
                    child: TextFormField(
                      initialValue: marks[uid],
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: index == selectedStudents.length - 1
                          ? TextInputAction.done
                          : TextInputAction.next,
                      decoration: _input('Mark'),
                      onChanged: (value) => marks[uid] = value,
                      onFieldSubmitted: (_) {
                        if (index < selectedStudents.length - 1) {
                          FocusScope.of(context).nextFocus();
                        } else {
                          FocusScope.of(context).unfocus();
                        }
                      },
                    ),
                  ),
                ),
              );
            }),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: marksSaving || selectedStudents.isEmpty
                    ? null
                    : () => _saveMarks(students),
                icon: const Icon(Icons.save_outlined),
                label: Text(marksSaving ? 'Saving...' : 'Save entered marks'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _studentCard({
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
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      );

  Widget _metricCard(String label, int value) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: .42),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text('$value', style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      );
}
