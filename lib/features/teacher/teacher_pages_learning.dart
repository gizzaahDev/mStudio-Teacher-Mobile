part of 'teacher_pages.dart';

class _AttendancePage extends StatefulWidget {
  const _AttendancePage({required this.session});
  final SessionController session;
  @override
  State<_AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<_AttendancePage> {
  List<Map<String, dynamic>> batches = [], students = [];
  String? batchId;
  String classType = 'Theory';
  String date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  Map<String, int> values = {};
  bool loading = true;
  @override
  void initState() {
    super.initState();
    start();
  }

  List<Map<String, dynamic>> get selectedStudents => students
      .where((student) => _strings(student['batchIds']).contains(batchId))
      .toList();
  Future<void> start() async {
    try {
      final result = await Future.wait([
        widget.session.repository.batches(),
        widget.session.repository.students()
      ]);
      batches = _list(_map(result[0])['batches']);
      students = _list(_map(result[1])['students']);
      if (batches.isNotEmpty) {
        batchId = '${batches.first['id']}';
        classType =
            _strings(batches.first['classTypes']).firstOrNull ?? 'Theory';
      }
      await loadRegister();
    } catch (error) {
      if (mounted) _snack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadRegister() async {
    if (batchId == null) return;
    final response = await widget.session.repository
        .getAttendance(batchId!, classType, date);
    final records = _list(_map(_map(response)['session'])['records']);
    values = {
      for (final student in selectedStudents)
        '${student['uid'] ?? student['id']}': 0,
      for (final record in records)
        '${record['studentUid']}': record['attendance'] == 1 ? 1 : 0
    };
    if (mounted) setState(() {});
  }

  Future<void> pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(date) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null) return;
    setState(() => date = DateFormat('yyyy-MM-dd').format(selected));
  }

  Widget attendanceMetric(String label, int value, IconData icon) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Icon(icon),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('$value',
                      style: Theme.of(context).textTheme.titleLarge),
                  Text(label),
                ])),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final batch =
        batches.where((item) => '${item['id']}' == batchId).firstOrNull;
    final types = _strings(batch?['classTypes']);
    return _PageFrame(
        title: 'Attendance',
        subtitle:
            'Open a date-wise register and review present and absent students.',
        loading: loading,
        onRefresh: start,
        children: [
          DropdownButtonFormField<String>(
              initialValue: batchId,
              decoration: _input('Batch'),
              items: batches
                  .map((item) => DropdownMenuItem(
                      value: '${item['id']}', child: Text(_title(item))))
                  .toList(),
              onChanged: (value) {
                setState(() => batchId = value);
                loadRegister();
              }),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
              initialValue: types.contains(classType) ? classType : null,
              decoration: _input('Class type'),
              items: types
                  .map((item) =>
                      DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  classType = value;
                  loadRegister();
                }
              }),
          const SizedBox(height: 10),
          InkWell(
            onTap: pickDate,
            child: InputDecorator(
              decoration: _input('Attendance date').copyWith(
                  suffixIcon: const Icon(Icons.calendar_month_outlined)),
              child: Text(DateFormat('d MMMM yyyy')
                  .format(DateTime.tryParse(date) ?? DateTime.now())),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
              onPressed: batchId == null ? null : loadRegister,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Open attendance register')),
          const SizedBox(height: 12),
          if (values.isNotEmpty)
            Row(children: [
              Expanded(
                  child: attendanceMetric(
                      'Present',
                      values.values.where((value) => value == 1).length,
                      Icons.check_circle_outline)),
              const SizedBox(width: 8),
              Expanded(
                  child: attendanceMetric(
                      'Absent',
                      values.values.where((value) => value != 1).length,
                      Icons.cancel_outlined)),
            ]),
          const SizedBox(height: 8),
          ...selectedStudents.map((student) {
            final uid = '${student['uid'] ?? student['id']}';
            return Card(
                child: ListTile(
                    leading: Icon(
                        values[uid] == 1
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: values[uid] == 1 ? Colors.green : Colors.red),
                    title: Text(_title(student)),
                    subtitle: Text('${student['studentId'] ?? ''}'),
                    trailing: Text(values[uid] == 1 ? 'Present' : 'Absent')));
          }),
        ]);
  }
}

class _CurriculumPage extends StatefulWidget {
  const _CurriculumPage({required this.session});
  final SessionController session;

  @override
  State<_CurriculumPage> createState() => _CurriculumPageState();
}

class _CurriculumPageState extends State<_CurriculumPage> {
  late Future<List<Map<String, dynamic>>> request = _load();

  Future<List<Map<String, dynamic>>> _load() async =>
      _list(_map(await widget.session.repository.curriculum())['resources']);

  Future<void> _refresh() async {
    setState(() => request = _load());
    await request;
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _CurriculumEditor(session: widget.session, item: item),
    );
    if (changed == true) await _refresh();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    if (!await _confirm(context, 'Delete this curriculum resource?') ||
        !mounted) {
      return;
    }
    final deleted = await _act(
      context,
      () => widget.session.repository.deleteCurriculum('${item['id']}'),
      'Curriculum resource deleted',
    );
    if (deleted) await _refresh();
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: request,
        builder: (context, snapshot) => _PageFrame(
          title: 'Curriculum',
          subtitle:
              'Add written lessons, links, or upload files to secure storage.',
          loading: snapshot.connectionState == ConnectionState.waiting,
          error: snapshot.error,
          onRefresh: _refresh,
          actions: [
            IconButton(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              tooltip: 'Add curriculum resource',
            ),
          ],
          children: [
            if (snapshot.hasData && snapshot.data!.isEmpty)
              const _Message('No resources yet. Tap + to add one.'),
            ...(snapshot.data ?? []).map(
              (item) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(_curriculumIcon('${item['type']}')),
                  ),
                  title: Text(_title(item)),
                  subtitle: Text(
                    [
                      _curriculumTypeLabel('${item['type']}'),
                      if ('${item['fileName'] ?? ''}'.isNotEmpty)
                        '${item['fileName']}',
                      if ('${item['description'] ?? ''}'.isNotEmpty)
                        '${item['description']}',
                    ].join(' · '),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _edit(item),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) =>
                        value == 'edit' ? _edit(item) : _delete(item),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _CurriculumEditor extends StatefulWidget {
  const _CurriculumEditor({required this.session, this.item});

  final SessionController session;
  final Map<String, dynamic>? item;

  @override
  State<_CurriculumEditor> createState() => _CurriculumEditorState();
}

class _CurriculumEditorState extends State<_CurriculumEditor> {
  late final TextEditingController title;
  late final TextEditingController description;
  late final TextEditingController url;
  late String type;
  late bool allowDownload;
  File? file;
  String selectedFileName = '';
  String selectedMimeType = '';
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item ?? const <String, dynamic>{};
    title = TextEditingController(text: '${item['title'] ?? ''}');
    description = TextEditingController(text: '${item['description'] ?? ''}');
    url = TextEditingController(text: '${item['url'] ?? ''}');
    type = _curriculumTypes.contains('${item['type']}')
        ? '${item['type']}'
        : 'paragraph';
    allowDownload = item['allowDownload'] != false;
    selectedFileName = '${item['fileName'] ?? ''}';
    selectedMimeType = '${item['mimeType'] ?? ''}';
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    url.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    final platformFile = result?.files.single;
    if (platformFile?.path == null) return;
    final name = platformFile!.name;
    setState(() {
      file = File(platformFile.path!);
      selectedFileName = name;
      selectedMimeType = _curriculumMimeType(name);
      type = _curriculumTypeForFile(name);
    });
  }

  Future<void> _save() async {
    if (title.text.trim().isEmpty) {
      _snack(context, 'Enter a resource title', error: true);
      return;
    }
    if (type != 'paragraph' && file == null && url.text.trim().isEmpty) {
      _snack(context, 'Choose a file or enter an external link', error: true);
      return;
    }

    setState(() => saving = true);
    try {
      var savedUrl = type == 'paragraph' ? '' : url.text.trim();
      if (file != null) {
        final uploaded = await widget.session.repository.uploadFile(file!);
        savedUrl = _absoluteApiUrl('${uploaded['url'] ?? ''}');
        if (savedUrl.isEmpty) {
          throw StateError('The uploaded file did not return a storage URL');
        }
      }
      final payload = <String, dynamic>{
        'title': title.text.trim(),
        'description': description.text.trim(),
        'type': type,
        'url': savedUrl,
        'fileName': type == 'paragraph' ? '' : selectedFileName,
        'mimeType': type == 'paragraph' ? '' : selectedMimeType,
        'allowDownload': type == 'paragraph' ? false : allowDownload,
      };
      if (widget.item == null) {
        await widget.session.repository.createCurriculum(payload);
      } else {
        await widget.session.repository
            .updateCurriculum('${widget.item!['id']}', payload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _snack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.item == null
            ? 'Add curriculum resource'
            : 'Edit curriculum resource'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: _input('Title')),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  minLines: 4,
                  maxLines: 7,
                  decoration: _input(
                    type == 'paragraph'
                        ? 'Lesson text'
                        : 'Description (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(type),
                  initialValue: type,
                  decoration: _input('Resource type'),
                  items: _curriculumTypes
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_curriculumTypeLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => type = value ?? 'paragraph'),
                ),
                if (type != 'paragraph') ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: saving ? null : _pickFile,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text(
                      selectedFileName.isEmpty
                          ? 'Choose file from device'
                          : selectedFileName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (selectedFileName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        file == null
                            ? 'Current stored file · $selectedMimeType'
                            : 'Ready to upload · $selectedMimeType',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: url,
                    keyboardType: TextInputType.url,
                    decoration: _input('External link (optional)'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Allow students to download'),
                    value: allowDownload,
                    onChanged: (value) => setState(() => allowDownload = value),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(saving ? 'Saving…' : 'Save'),
          ),
        ],
      );
}

const _curriculumTypes = [
  'paragraph',
  'pdf',
  'recording',
  'video',
  'audio',
  'image',
  'file',
];

String _curriculumTypeLabel(String value) => switch (value) {
      'paragraph' => 'Written lesson',
      'pdf' => 'PDF document',
      'recording' => 'Class recording',
      'video' => 'Video',
      'audio' => 'Audio',
      'image' => 'Image',
      _ => 'File',
    };

IconData _curriculumIcon(String value) => switch (value) {
      'paragraph' => Icons.article_outlined,
      'pdf' => Icons.picture_as_pdf_outlined,
      'recording' => Icons.podcasts_outlined,
      'video' => Icons.video_library_outlined,
      'audio' => Icons.audio_file_outlined,
      'image' => Icons.image_outlined,
      _ => Icons.insert_drive_file_outlined,
    };

String _curriculumTypeForFile(String fileName) {
  final extension = fileName.split('.').last.toLowerCase();
  if (extension == 'pdf') return 'pdf';
  if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
    return 'image';
  }
  if (['mp3', 'wav', 'm4a', 'aac', 'ogg'].contains(extension)) {
    return 'audio';
  }
  if (['mp4', 'mov', 'mkv', 'webm'].contains(extension)) return 'video';
  return 'file';
}

String _curriculumMimeType(String fileName) {
  final extension = fileName.split('.').last.toLowerCase();
  return switch (extension) {
    'pdf' => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'mp3' => 'audio/mpeg',
    'wav' => 'audio/wav',
    'm4a' => 'audio/mp4',
    'aac' => 'audio/aac',
    'ogg' => 'audio/ogg',
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    'mkv' => 'video/x-matroska',
    'webm' => 'video/webm',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt' => 'application/vnd.ms-powerpoint',
    'pptx' =>
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'txt' => 'text/plain',
    _ => 'application/octet-stream',
  };
}

String _absoluteApiUrl(String value) {
  if (value.isEmpty ||
      value.startsWith('http://') ||
      value.startsWith('https://')) {
    return value;
  }
  return '${AppConfig.apiBaseUrl}${value.startsWith('/') ? value : '/$value'}';
}

class _DashboardContentPage extends StatefulWidget {
  const _DashboardContentPage({required this.session});
  final SessionController session;

  @override
  State<_DashboardContentPage> createState() => _DashboardContentPageState();
}

class _DashboardContentPageState extends State<_DashboardContentPage> {
  late Future<List<dynamic>> request = _load();

  Future<List<dynamic>> _load() => Future.wait([
        widget.session.repository.dashboardContent(),
        widget.session.repository.batches(),
        widget.session.repository.students(),
      ]);

  Future<void> _refresh() async {
    setState(() => request = _load());
    await request;
  }

  Future<void> _edit({Map<String, dynamic>? item}) async {
    late List<dynamic> values;
    try {
      values = await request;
    } catch (error) {
      if (mounted)
        _snack(context, 'Could not load recipients: $error', error: true);
      return;
    }
    if (!mounted) return;
    final batches = _list(_map(values[1])['batches']);
    final students = _list(_map(values[2])['students']);
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DashboardContentEditor(
        session: widget.session,
        initial: item ?? const {},
        batches: batches,
        students: students,
      ),
    );
    if (data == null || !mounted) return;
    final saved = await _act(
      context,
      () => item == null
          ? widget.session.repository.createDashboardContent(data)
          : widget.session.repository
              .updateDashboardContent('${item['id']}', data),
      item == null
          ? 'Dashboard content published'
          : 'Dashboard content updated',
    );
    if (saved) {
      widget.session.markContentChanged();
      await _refresh();
    }
  }

  Future<void> _remove(Map<String, dynamic> item) async {
    if (!await _confirm(context, 'Delete this quote or notice?')) return;
    if (!mounted) return;
    final removed = await _act(
      context,
      () => widget.session.repository.deleteDashboardContent('${item['id']}'),
      'Dashboard content deleted',
    );
    if (removed) await _refresh();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
        future: request,
        builder: (context, snapshot) {
          final values = snapshot.data ?? const [];
          final items = values.isEmpty
              ? <Map<String, dynamic>>[]
              : _list(_map(values[0])['items']);
          return _PageFrame(
            title: 'Quotes & notices',
            subtitle:
                'Quotes go to all students. Schedule notices for everyone, batches, or selected students.',
            loading: snapshot.connectionState == ConnectionState.waiting,
            error: snapshot.error,
            onRefresh: _refresh,
            actions: [
              IconButton(
                tooltip: 'Create quote or notice',
                onPressed: snapshot.hasData ? () => _edit() : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
            children: [
              if (snapshot.hasData)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _edit,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create quote or notice'),
                  ),
                ),
              ...items.map((item) => Card(
                    child: ListTile(
                      onTap: () => _edit(item: item),
                      leading: Icon(item['type'] == 'quote'
                          ? Icons.format_quote_rounded
                          : Icons.campaign_rounded),
                      title: Text('${item['title'] ?? 'Dashboard content'}'),
                      subtitle: Text(
                          [
                            item['type'] == 'quote'
                                ? 'Quote · All students'
                                : 'Notice · ${item['audience'] ?? 'all'}',
                            '${item['content'] ?? ''}',
                            if ('${item['startsAt'] ?? ''}'.isNotEmpty)
                              'Starts ${_dashboardTime(item['startsAt'])}',
                            if ('${item['endsAt'] ?? ''}'.isNotEmpty)
                              'Ends ${_dashboardTime(item['endsAt'])}',
                          ].join('\n'),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: 'Delete',
                        onPressed: () => _remove(item),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ),
                  )),
            ],
          );
        },
      );
}

String _dashboardTime(Object? value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  return date == null
      ? '$value'
      : DateFormat('d MMM yyyy, h:mm a').format(date);
}

class _DashboardContentEditor extends StatefulWidget {
  const _DashboardContentEditor({
    required this.session,
    required this.initial,
    required this.batches,
    required this.students,
  });
  final SessionController session;
  final Map<String, dynamic> initial;
  final List<Map<String, dynamic>> batches;
  final List<Map<String, dynamic>> students;

  @override
  State<_DashboardContentEditor> createState() =>
      _DashboardContentEditorState();
}

class _DashboardContentEditorState extends State<_DashboardContentEditor> {
  late final title =
      TextEditingController(text: '${widget.initial['title'] ?? ''}');
  late final content =
      TextEditingController(text: '${widget.initial['content'] ?? ''}');
  late final url =
      TextEditingController(text: '${widget.initial['url'] ?? ''}');
  late String type = '${widget.initial['type'] ?? 'notice'}';
  late String audience =
      type == 'quote' ? 'all' : '${widget.initial['audience'] ?? 'all'}';
  late String priority = '${widget.initial['priority'] ?? 'medium'}';
  late bool active = widget.initial['active'] != false;
  late Set<String> batchIds = type == 'quote'
      ? <String>{}
      : _strings(widget.initial['targetBatchIds']).toSet();
  late Set<String> studentIds = type == 'quote'
      ? <String>{}
      : _strings(widget.initial['targetStudentIds']).toSet();
  late DateTime? startsAt =
      DateTime.tryParse('${widget.initial['startsAt'] ?? ''}')?.toLocal();
  late DateTime? endsAt =
      DateTime.tryParse('${widget.initial['endsAt'] ?? ''}')?.toLocal();
  String imageUrl = '';
  File? imageFile;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    imageUrl = '${widget.initial['imageUrl'] ?? ''}';
  }

  @override
  void dispose() {
    title.dispose();
    content.dispose();
    url.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime? current) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current ?? now),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _chooseImage() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final path = picked?.files.single.path;
    if (path != null && mounted) setState(() => imageFile = File(path));
  }

  Future<void> _chooseBatches() async {
    final selected = {...batchIds};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Choose batches'),
          content: SizedBox(
            width: 520,
            child: ListView(
              shrinkWrap: true,
              children: widget.batches.map((batch) {
                final id = '${batch['id']}';
                return CheckboxListTile(
                  value: selected.contains(id),
                  title: Text(_title(batch)),
                  subtitle: Text([
                    '${batch['grade'] ?? ''}',
                    ..._strings(batch['classTypes']),
                  ].where((value) => value.isNotEmpty).join(' · ')),
                  onChanged: (checked) => update(() =>
                      checked == true ? selected.add(id) : selected.remove(id)),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, selected),
                child: const Text('Done')),
          ],
        ),
      ),
    );
    if (result != null) setState(() => batchIds = result);
  }

  Future<void> _chooseStudents() async {
    final selected = {...studentIds};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Choose students'),
          content: SizedBox(
            width: 520,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                TextButton(
                    onPressed: () => update(() {
                          selected
                            ..clear()
                            ..addAll(widget.students.map((student) =>
                                '${student['uid'] ?? student['id']}'));
                        }),
                    child: const Text('Select all')),
                TextButton(
                    onPressed: () => update(selected.clear),
                    child: const Text('Clear all')),
              ]),
              Flexible(
                  child: ListView(
                shrinkWrap: true,
                children: widget.students.map((student) {
                  final id = '${student['uid'] ?? student['id']}';
                  return CheckboxListTile(
                    value: selected.contains(id),
                    title: Text(_title(student)),
                    subtitle: Text('${student['studentId'] ?? id}'),
                    onChanged: (checked) => update(() => checked == true
                        ? selected.add(id)
                        : selected.remove(id)),
                  );
                }).toList(),
              )),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, selected),
                child: const Text('Done')),
          ],
        ),
      ),
    );
    if (result != null) setState(() => studentIds = result);
  }

  Future<void> _save() async {
    if (title.text.trim().isEmpty || content.text.trim().isEmpty) {
      return _snack(context, 'Enter a title and content.', error: true);
    }
    if (startsAt == null || endsAt == null) {
      return _snack(context, 'Choose the start and end showing date and time.',
          error: true);
    }
    if (!endsAt!.isAfter(startsAt!)) {
      return _snack(context, 'End time must be after start time.', error: true);
    }
    if (type == 'notice' && audience == 'batches' && batchIds.isEmpty) {
      return _snack(context, 'Select at least one batch.', error: true);
    }
    if (type == 'notice' && audience == 'students' && studentIds.isEmpty) {
      return _snack(context, 'Select at least one student.', error: true);
    }
    setState(() => saving = true);
    try {
      if (imageFile != null) {
        final uploaded = await widget.session.repository.uploadFile(imageFile!);
        imageUrl = _absoluteApiUrl('${uploaded['url'] ?? ''}');
      }
      if (!mounted) return;
      Navigator.pop(context, <String, dynamic>{
        'type': type,
        'title': title.text.trim(),
        'content': content.text.trim(),
        'url': url.text.trim(),
        'imageUrl': imageUrl,
        'active': active,
        'priority': priority,
        'startsAt': startsAt!.toUtc().toIso8601String(),
        'endsAt': endsAt!.toUtc().toIso8601String(),
        'audience': type == 'quote' ? 'all' : audience,
        'targetBatchIds': type == 'notice' && audience == 'batches'
            ? batchIds.toList()
            : <String>[],
        'targetStudentIds': type == 'notice' && audience == 'students'
            ? studentIds.toList()
            : <String>[],
        'targetTeacherIds': <String>[],
      });
    } catch (error) {
      if (mounted) _snack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.initial.isEmpty
            ? 'Create quote or notice'
            : 'Edit quote or notice'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: _input('Content type'),
                items: const [
                  DropdownMenuItem(
                      value: 'quote', child: Text('Quote · All students')),
                  DropdownMenuItem(
                      value: 'notice', child: Text('Special notice')),
                ],
                onChanged: (value) => setState(() {
                  type = value ?? 'notice';
                  audience = type == 'quote' ? 'all' : audience;
                  batchIds.clear();
                  studentIds.clear();
                }),
              ),
              const SizedBox(height: 12),
              if (type == 'notice') ...[
                DropdownButtonFormField<String>(
                  initialValue: audience,
                  decoration: _input('Send to'),
                  items: const [
                    DropdownMenuItem(
                        value: 'all', child: Text('All my students')),
                    DropdownMenuItem(
                        value: 'batches', child: Text('Selected batches')),
                    DropdownMenuItem(
                        value: 'students', child: Text('Selected students')),
                  ],
                  onChanged: (value) => setState(() {
                    audience = value ?? 'all';
                    batchIds.clear();
                    studentIds.clear();
                  }),
                ),
                if (audience == 'batches')
                  ListTile(
                    title: const Text('Selected batches'),
                    subtitle: Text('${batchIds.length} selected'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _chooseBatches,
                  ),
                if (audience == 'students')
                  ListTile(
                    title: const Text('Selected students'),
                    subtitle: Text('${studentIds.length} selected'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _chooseStudents,
                  ),
                const SizedBox(height: 8),
              ],
              TextField(controller: title, decoration: _input('Title')),
              const SizedBox(height: 12),
              TextField(
                  controller: content,
                  minLines: 4,
                  maxLines: 8,
                  decoration: _input('Content')),
              const SizedBox(height: 12),
              TextField(
                  controller: url,
                  keyboardType: TextInputType.url,
                  decoration: _input('Optional reading link')),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                  onPressed: _chooseImage,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(imageFile == null
                      ? (imageUrl.isEmpty ? 'Choose image' : 'Change image')
                      : imageFile!.uri.pathSegments.last)),
              if (imageFile != null || imageUrl.isNotEmpty)
                TextButton.icon(
                    onPressed: () => setState(() {
                          imageFile = null;
                          imageUrl = '';
                        }),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove image')),
              const SizedBox(height: 8),
              ListTile(
                  title: const Text('Start showing'),
                  subtitle: Text(startsAt == null
                      ? 'Choose date and time'
                      : _dashboardTime(startsAt!.toIso8601String())),
                  trailing: const Icon(Icons.calendar_month_rounded),
                  onTap: () async {
                    final value = await _pickDateTime(startsAt);
                    if (value != null) setState(() => startsAt = value);
                  }),
              ListTile(
                  title: const Text('Stop showing'),
                  subtitle: Text(endsAt == null
                      ? 'Choose date and time'
                      : _dashboardTime(endsAt!.toIso8601String())),
                  trailing: const Icon(Icons.event_busy_rounded),
                  onTap: () async {
                    final value = await _pickDateTime(endsAt);
                    if (value != null) setState(() => endsAt = value);
                  }),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show this item to students'),
                  value: active,
                  onChanged: (value) => setState(() => active = value)),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton.icon(
              onPressed: saving ? null : _save,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.publish_rounded),
              label: Text(saving ? 'Saving...' : 'Save')),
        ],
      );
}
