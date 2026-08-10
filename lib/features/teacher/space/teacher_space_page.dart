part of '../teacher_pages.dart';

class _BatchContentPage extends StatefulWidget {
  const _BatchContentPage({required this.session, this.initialBatchId});
  final SessionController session;
  final String? initialBatchId;

  @override
  State<_BatchContentPage> createState() => _BatchContentPageState();
}

class _BatchContentPageState extends State<_BatchContentPage> {
  List<Map<String, dynamic>> batches = [];
  List<Map<String, dynamic>> content = [];
  List<Map<String, dynamic>> localDrafts = [];
  String? batchId;
  bool loading = true;
  String? error;

  Map<String, dynamic>? get selectedBatch =>
      batches.where((item) => '${item['id']}' == batchId).firstOrNull;

  @override
  void initState() {
    super.initState();
    batchId = widget.initialBatchId;
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      if (refresh) await widget.session.repository.clearCache();
      final batchResponse = await widget.session.repository.batches();
      batches = _list(_map(batchResponse)['batches']);
      if (batchId == null ||
          !batches.any((item) => '${item['id']}' == batchId)) {
        batchId = batches.firstOrNull?['id']?.toString();
      }
      content = batchId == null
          ? []
          : _list(_map(await widget.session.repository.batchContent(batchId!))[
              'content']);
      await _loadLocalDrafts();
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String get _draftKey =>
      'teacher-space-drafts:${widget.session.user?.uid ?? 'teacher'}:${batchId ?? 'none'}';

  Future<void> _loadLocalDrafts() async {
    if (batchId == null) {
      localDrafts = [];
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_draftKey);
    try {
      localDrafts = raw == null
          ? []
          : (jsonDecode(raw) as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
    } catch (_) {
      localDrafts = [];
    }
  }

  Future<void> _saveLocalDrafts() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_draftKey, jsonEncode(localDrafts));
  }

  Future<void> _selectBatch(String? value) async {
    if (value == null) return;
    setState(() {
      batchId = value;
      content = [];
      loading = true;
    });
    await _load();
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    if (batchId == null) {
      _snack(context, 'Create or select a batch first', error: true);
      return;
    }
    final saved = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SpaceEditorDialog(
        session: widget.session,
        batchId: batchId!,
        batchName: _title(selectedBatch ?? {}),
        item: item,
      ),
    );
    if (saved is Map && saved['draft'] is Map) {
      localDrafts.add(Map<String, dynamic>.from(saved['draft'] as Map));
      await _saveLocalDrafts();
      if (mounted) setState(() {});
      return;
    }
    if (saved == true) {
      await _load(refresh: true);
      widget.session.markContentChanged();
    }
  }

  Future<Map<String, dynamic>> _resolveDraft(
      Map<String, dynamic> source) async {
    final payload = _map(jsonDecode(jsonEncode(source)));
    final rawUrl = '${payload['url'] ?? ''}';
    if (rawUrl.startsWith('__LOCAL__:')) {
      final path = rawUrl.substring('__LOCAL__:'.length);
      final upload = await widget.session.repository.uploadFile(File(path));
      payload['url'] = _absoluteUrl('${upload['url'] ?? ''}');
    }
    if ('${payload['type']}' == 'quiz') {
      final quiz = _map(jsonDecode('${payload['content'] ?? '{}'}'));
      final questions = _list(quiz['questions']);
      for (final question in questions) {
        final imageUrl = '${question['imageUrl'] ?? ''}';
        if (imageUrl.startsWith('__LOCAL__:')) {
          final upload = await widget.session.repository
              .uploadFile(File(imageUrl.substring('__LOCAL__:'.length)));
          question['imageUrl'] = _absoluteUrl('${upload['url'] ?? ''}');
        }
      }
      quiz['questions'] = questions;
      payload['content'] = jsonEncode(quiz);
    }
    return payload;
  }

  Future<void> _publishLocalDrafts() async {
    if (batchId == null || localDrafts.isEmpty) return;
    setState(() => loading = true);
    try {
      for (final draft in localDrafts) {
        await widget.session.repository
            .createBatchContent(batchId!, await _resolveDraft(draft));
      }
      localDrafts.clear();
      await _saveLocalDrafts();
      await _load(refresh: true);
      widget.session.markContentChanged();
      if (mounted) _snack(context, 'All Learning Space drafts published.');
    } catch (exception) {
      if (mounted) _snack(context, '$exception', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> item) async {
    if (!await _confirm(context, 'Delete this ICT Space item?')) return;
    try {
      await widget.session.repository
          .deleteBatchContent(batchId!, '${item['id']}');
      await _load(refresh: true);
      widget.session.markContentChanged();
      if (mounted) _snack(context, 'Content deleted');
    } catch (e) {
      if (mounted) _snack(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => _PageFrame(
        title: 'Manage Learning Space',
        subtitle:
            'Select a batch, preview its student view, and publish learning content.',
        loading: loading,
        error: error,
        onRefresh: () => _load(refresh: true),
        actions: [
          IconButton(
            onPressed: batchId == null
                ? null
                : () async {
                    if (await _showAddStudentsToBatch(
                      context,
                      widget.session,
                      initialBatchId: batchId,
                    )) {
                      await _load(refresh: true);
                    }
                  },
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'Add students to this batch',
          ),
          IconButton(
              onPressed: batchId == null ? null : () => _edit(),
              icon: const Icon(Icons.add),
              tooltip: 'Add content')
        ],
        children: [
          DropdownButtonFormField<String>(
            initialValue: batchId,
            decoration: _input('Batch'),
            items: batches
                .map((batch) => DropdownMenuItem(
                    value: '${batch['id']}', child: Text(_title(batch))))
                .toList(),
            onChanged: _selectBatch,
          ),
          if (selectedBatch != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  if (await _changeBatchThisWeek(
                      context, widget.session, selectedBatch!)) {
                    await _load(refresh: true);
                  }
                },
                icon: const Icon(Icons.edit_calendar_outlined),
                label: const Text('Change this week'),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: Text('Student preview',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold))),
            FilledButton.icon(
                onPressed: batchId == null ? null : () => _edit(),
                icon: const Icon(Icons.add),
                label: const Text('Add')),
          ]),
          const SizedBox(height: 8),
          _SpacePreview(
              batchName: _title(selectedBatch ?? {}),
              items: [...content, ...localDrafts]),
          if (localDrafts.isNotEmpty) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
                onPressed: _publishLocalDrafts,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text('Publish all ${localDrafts.length} drafts')),
          ],
          const SizedBox(height: 18),
          Text('Manage content',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (batchId != null && content.isEmpty && !loading)
            const _Message(
                'No content has been added yet. The preview above is ready for your first item.'),
          ...content.map((item) => Card(
                child: ListTile(
                  leading:
                      CircleAvatar(child: Icon(_spaceIcon('${item['type']}'))),
                  title: Text(_spaceLabel(item)),
                  subtitle: Text('${item['content'] ?? item['url'] ?? ''}',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => _edit(item),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) =>
                        value == 'edit' ? _edit(item) : _remove(item),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              )),
          if (localDrafts.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Saved on this device',
                style: Theme.of(context).textTheme.titleMedium),
            ...localDrafts.asMap().entries.map((entry) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.drafts_outlined),
                    title: Text(_spaceLabel(entry.value)),
                    subtitle: const Text('Not published yet'),
                    trailing: IconButton(
                      onPressed: () async {
                        setState(() => localDrafts.removeAt(entry.key));
                        await _saveLocalDrafts();
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                )),
          ],
        ],
      );
}

class _QuizQuestionDraft {
  _QuizQuestionDraft({
    String question = '',
    this.kind = 'single',
    List<String> options = const ['', ''],
    String answer = '',
    List<String> answers = const [],
    int seconds = 0,
    String imageUrl = '',
  })  : question = TextEditingController(text: question),
        options =
            options.map((value) => TextEditingController(text: value)).toList(),
        answer = TextEditingController(text: answer),
        writtenAnswer = TextEditingController(text: answer),
        seconds = TextEditingController(text: '$seconds'),
        imageUrl = TextEditingController(text: imageUrl),
        selectedAnswers = answers.toSet();

  final TextEditingController question;
  String kind;
  final List<TextEditingController> options;
  final TextEditingController answer;
  final TextEditingController writtenAnswer;
  final TextEditingController seconds;
  final TextEditingController imageUrl;
  final Set<String> selectedAnswers;
  File? imageFile;

  void dispose() {
    question.dispose();
    for (final option in options) {
      option.dispose();
    }
    answer.dispose();
    writtenAnswer.dispose();
    seconds.dispose();
    imageUrl.dispose();
  }
}

class _SpaceEditorDialog extends StatefulWidget {
  const _SpaceEditorDialog(
      {required this.session,
      required this.batchId,
      required this.batchName,
      this.item});
  final SessionController session;
  final String batchId;
  final String batchName;
  final Map<String, dynamic>? item;

  @override
  State<_SpaceEditorDialog> createState() => _SpaceEditorDialogState();
}

class _SpaceEditorDialogState extends State<_SpaceEditorDialog> {
  late final TextEditingController content;
  late final TextEditingController url;
  late final TextEditingController color;
  late final TextEditingController background;
  late final TextEditingController borderColor;
  late final TextEditingController borderTopColor;
  late final TextEditingController borderRightColor;
  late final TextEditingController borderBottomColor;
  late final TextEditingController borderLeftColor;
  late final TextEditingController underlineColor;
  late final TextEditingController quizTitle;
  late final TextEditingController quizSeconds;
  late final TextEditingController quizAttempts;
  final List<_QuizQuestionDraft> quizQuestions = [];
  late String type;
  late String fontSize;
  late String fontWeight;
  late String align;
  late String fontStyle;
  late String textDecoration;
  late bool borderTop;
  late bool borderRight;
  late bool borderBottom;
  late bool borderLeft;
  File? file;
  DateTime? availableAt;
  DateTime? deadline;
  bool saving = false;
  bool removeExistingFile = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item ?? {};
    final style = _map(item['style']);
    type = '${item['type'] ?? 'text'}';
    _readSchedule(item);
    fontSize = '${style['fontSize'] ?? 'base'}';
    fontWeight = '${style['fontWeight'] ?? 'normal'}';
    align = '${style['align'] ?? 'left'}';
    fontStyle = '${style['fontStyle'] ?? 'normal'}';
    textDecoration = '${style['textDecoration'] ?? 'none'}';
    borderTop = style['borderTop'] == true || widget.item == null;
    borderRight = style['borderRight'] == true || widget.item == null;
    borderBottom = style['borderBottom'] == true || widget.item == null;
    borderLeft = style['borderLeft'] != false;
    content = TextEditingController(text: '${item['content'] ?? ''}');
    Map<String, dynamic> quiz = {};
    if (type == 'quiz') {
      try {
        quiz = _map(jsonDecode(content.text));
      } catch (_) {}
    }
    final savedQuestions = _list(quiz['questions']);
    quizTitle = TextEditingController(
        text:
            '${quiz['title'] ?? savedQuestions.firstOrNull?['question'] ?? 'ICT Quiz'}');
    quizSeconds = TextEditingController(text: '${quiz['seconds'] ?? 0}');
    quizAttempts = TextEditingController(text: '${quiz['maxAttempts'] ?? 1}');
    for (final raw in savedQuestions) {
      final options = _strings(raw['options']);
      final kind = '${raw['kind'] ?? 'choice'}';
      quizQuestions.add(_QuizQuestionDraft(
        question: '${raw['question'] ?? ''}',
        kind: kind == 'written'
            ? 'written'
            : kind == 'multiple'
                ? 'multiple'
                : 'single',
        options: options.isEmpty ? const ['', ''] : options,
        answer: '${raw['answer'] ?? ''}',
        answers: _strings(raw['answers']),
        seconds: (raw['seconds'] as num?)?.toInt() ?? 0,
        imageUrl: '${raw['imageUrl'] ?? ''}',
      ));
    }
    if (quizQuestions.isEmpty) quizQuestions.add(_QuizQuestionDraft());
    url = TextEditingController(text: '${item['url'] ?? ''}');
    color = TextEditingController(text: '${style['color'] ?? '#1e293b'}');
    background =
        TextEditingController(text: '${style['background'] ?? 'transparent'}');
    borderColor =
        TextEditingController(text: '${style['borderColor'] ?? '#2563eb'}');
    borderTopColor = TextEditingController(
        text: '${style['borderTopColor'] ?? style['borderColor'] ?? '#2563eb'}');
    borderRightColor = TextEditingController(
        text: '${style['borderRightColor'] ?? style['borderColor'] ?? '#2563eb'}');
    borderBottomColor = TextEditingController(
        text: '${style['borderBottomColor'] ?? style['borderColor'] ?? '#2563eb'}');
    borderLeftColor = TextEditingController(
        text: '${style['borderLeftColor'] ?? style['borderColor'] ?? '#2563eb'}');
    underlineColor = TextEditingController(
        text: '${style['underlineColor'] ?? style['color'] ?? '#2563eb'}');
    for (final controller in [
      content,
      url,
      color,
      background,
      borderColor,
      borderTopColor,
      borderRightColor,
      borderBottomColor,
      borderLeftColor,
      underlineColor,
      quizTitle,
      quizSeconds,
      quizAttempts,
    ]) {
      controller.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    content.dispose();
    url.dispose();
    color.dispose();
    background.dispose();
    borderColor.dispose();
    borderTopColor.dispose();
    borderRightColor.dispose();
    borderBottomColor.dispose();
    borderLeftColor.dispose();
    underlineColor.dispose();
    quizTitle.dispose();
    quizSeconds.dispose();
    quizAttempts.dispose();
    for (final question in quizQuestions) {
      question.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get draft => {
        'type': type,
        'content': _scheduledContent(),
        'url': removeExistingFile ? '' : url.text,
        'style': {
          'color': color.text,
          'background': background.text,
          'borderColor': borderColor.text,
          'borderTop': borderTop,
          'borderRight': borderRight,
          'borderBottom': borderBottom,
          'borderLeft': borderLeft,
          'borderTopColor': borderTopColor.text,
          'borderRightColor': borderRightColor.text,
          'borderBottomColor': borderBottomColor.text,
          'borderLeftColor': borderLeftColor.text,
          'underlineColor': underlineColor.text,
          'fontSize': fontSize,
          'fontWeight': fontWeight,
          'fontStyle': fontStyle,
          'textDecoration': textDecoration,
          'align': align,
        }
      };

  void _readSchedule(Map<String, dynamic> item) {
    final raw = '${item['content'] ?? ''}';
    try {
      final details = _map(jsonDecode(raw));
      availableAt = DateTime.tryParse(
              '${details['availableAt'] ?? details['upcomingAt'] ?? ''}')
          ?.toLocal();
      deadline = DateTime.tryParse('${details['deadline'] ?? ''}')?.toLocal();
    } catch (_) {
      availableAt = null;
      deadline = null;
    }
  }

  String _scheduledContent() {
    if (type != 'quiz' && type != 'assignment') return content.text;
    final raw = content.text.trim();
    Map<String, dynamic> details = {};
    try {
      details = _map(jsonDecode(raw));
    } catch (_) {
      if (raw.isNotEmpty) {
        details['title'] = raw;
        if (type == 'quiz') details['question'] = raw;
      }
    }
    if (availableAt != null) {
      details['availableAt'] = availableAt!.toUtc().toIso8601String();
    }
    if (type == 'assignment' && deadline != null) {
      details['deadline'] = deadline!.toUtc().toIso8601String();
    }
    return jsonEncode(details);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() {
      file = File(path);
      type = 'resource';
    });
  }

  String _absoluteUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return '${AppConfig.apiBaseUrl}${value.startsWith('/') ? value : '/$value'}';
  }

  Future<void> _pickDateTime({required bool isDeadline}) async {
    final initial = (isDeadline ? deadline : availableAt) ??
        DateTime.now().add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      final value =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (isDeadline) {
        deadline = value;
      } else {
        availableAt = value;
      }
    });
  }

  Widget _dateTimeField({
    required String label,
    required DateTime? value,
    required bool isDeadline,
  }) =>
      Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading:
              Icon(isDeadline ? Icons.timer_outlined : Icons.event_outlined),
          title: Text(label),
          subtitle: Text(value == null
              ? 'Tap to choose the date and time'
              : DateFormat('EEEE, d MMM yyyy · h:mm a').format(value)),
          onTap: () => _pickDateTime(isDeadline: isDeadline),
          trailing: value == null
              ? const Icon(Icons.chevron_right)
              : IconButton(
                  onPressed: () => setState(() {
                    if (isDeadline) {
                      deadline = null;
                    } else {
                      availableAt = null;
                    }
                  }),
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear date',
                ),
        ),
      );

  Future<File> _persistDraftFile(File source) async {
    final directory = Directory(
        '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}space_drafts${Platform.pathSeparator}${widget.batchId}');
    await directory.create(recursive: true);
    final name = source.path.split(Platform.pathSeparator).last;
    return source.copy(
        '${directory.path}${Platform.pathSeparator}${DateTime.now().microsecondsSinceEpoch}-$name');
  }

  Future<void> _save({bool draftOnly = false}) async {
    if ((type == 'quiz' || type == 'assignment') && availableAt == null) {
      _snack(context, 'Choose the upcoming date and time', error: true);
      return;
    }
    if (type == 'assignment' && deadline == null) {
      _snack(context, 'Choose the assignment deadline', error: true);
      return;
    }
    if (type == 'assignment' && !deadline!.isAfter(availableAt!)) {
      _snack(context, 'Deadline must be after the upcoming date', error: true);
      return;
    }
    if (type == 'quiz') {
      if (quizTitle.text.trim().isEmpty ||
          quizQuestions.every((item) => item.question.text.trim().isEmpty)) {
        _snack(context, 'Add a quiz title and at least one question',
            error: true);
        return;
      }
      for (final question in quizQuestions) {
        if (question.question.text.trim().isEmpty) continue;
        final options = question.options
            .map((item) => item.text.trim())
            .where((item) => item.isNotEmpty)
            .toList();
        if (question.kind != 'written' && options.length < 2) {
          _snack(context, 'Add at least two answers for every choice question',
              error: true);
          return;
        }
        if ((question.kind == 'single' && question.answer.text.isEmpty) ||
            (question.kind == 'multiple' && question.selectedAnswers.isEmpty) ||
            (question.kind == 'written' &&
                question.writtenAnswer.text.trim().isEmpty)) {
          _snack(context, 'Select or enter every correct answer', error: true);
          return;
        }
      }
    }
    if (type != 'divider' &&
        type != 'quiz' &&
        content.text.trim().isEmpty &&
        url.text.trim().isEmpty &&
        file == null) {
      _snack(context, 'Add text, a URL, or a file', error: true);
      return;
    }
    setState(() => saving = true);
    try {
      final payload = draft;
      if (type == 'quiz') {
        final questions = <Map<String, dynamic>>[];
        for (final item in quizQuestions) {
          if (item.question.text.trim().isEmpty) continue;
          if (item.imageFile != null && !draftOnly) {
            final uploaded =
                await widget.session.repository.uploadFile(item.imageFile!);
            item.imageUrl.text = _absoluteUrl('${uploaded['url'] ?? ''}');
          } else if (item.imageFile != null) {
            item.imageUrl.text =
                '__LOCAL__:${(await _persistDraftFile(item.imageFile!)).path}';
          }
          final options = item.options
              .map((option) => option.text.trim())
              .where((option) => option.isNotEmpty)
              .toList();
          questions.add({
            'question': item.question.text.trim(),
            'kind': item.kind == 'single' ? 'choice' : item.kind,
            'options': item.kind == 'written' ? <String>[] : options,
            'answer': item.kind == 'written'
                ? item.writtenAnswer.text.trim()
                : item.kind == 'single'
                    ? item.answer.text
                    : '',
            'answers': item.kind == 'multiple'
                ? item.selectedAnswers
                    .where((answer) => options.contains(answer))
                    .toList()
                : <String>[],
            'seconds': int.tryParse(item.seconds.text) ?? 0,
            'imageUrl': item.imageUrl.text.trim(),
          });
        }
        payload['content'] = jsonEncode({
          'title': quizTitle.text.trim(),
          'seconds': int.tryParse(quizSeconds.text) ?? 0,
          'maxAttempts': int.tryParse(quizAttempts.text) ?? 1,
          'availableAt': availableAt!.toUtc().toIso8601String(),
          'questions': questions,
        });
      }
      if (file != null) {
        payload['type'] = 'resource';
        if (draftOnly) {
          payload['url'] =
              '__LOCAL__:${(await _persistDraftFile(file!)).path}';
        } else {
          final upload = await widget.session.repository.uploadFile(file!);
          payload['url'] = _absoluteUrl('${upload['url'] ?? ''}');
        }
        payload['content'] =
            '${content.text.trim()}${content.text.trim().isEmpty ? '' : '\n\n'}__FILE__:${file!.path.split(Platform.pathSeparator).last}';
      }
      payload['batchName'] = widget.batchName;
      if (draftOnly) {
        if (mounted) Navigator.pop(context, {'draft': payload});
        return;
      }
      if (widget.item == null) {
        await widget.session.repository
            .createBatchContent(widget.batchId, payload);
      } else {
        await widget.session.repository.updateBatchContent(
            widget.batchId, '${widget.item!['id']}', payload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _snack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _pickQuizImage(_QuizQuestionDraft question) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path != null && mounted) {
      setState(() => question.imageFile = File(path));
    }
  }

  Widget _quizEditor() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(controller: quizTitle, decoration: _input('Quiz title')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: quizSeconds,
                keyboardType: TextInputType.number,
                decoration: _input('Overall time (seconds)')
                    .copyWith(helperText: '0 means no overall timer'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: quizAttempts,
                keyboardType: TextInputType.number,
                decoration: _input('Allowed attempts')
                    .copyWith(helperText: '0 means unlimited'),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          ...quizQuestions.asMap().entries.map((entry) {
            final index = entry.key;
            final question = entry.value;
            final optionValues = question.options
                .map((item) => item.text.trim())
                .where((item) => item.isNotEmpty)
                .toList();
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      CircleAvatar(radius: 15, child: Text('${index + 1}')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text('Question ${index + 1}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                      if (quizQuestions.length > 1)
                        IconButton(
                          onPressed: () => setState(() {
                            quizQuestions.removeAt(index).dispose();
                          }),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Remove question',
                        ),
                    ]),
                    TextField(
                      controller: question.question,
                      minLines: 2,
                      maxLines: 4,
                      decoration: _input('Question text'),
                    ),
                    const SizedBox(height: 9),
                    DropdownButtonFormField<String>(
                      initialValue: question.kind,
                      decoration: _input('Answer type'),
                      items: const [
                        DropdownMenuItem(
                            value: 'single', child: Text('One answer')),
                        DropdownMenuItem(
                            value: 'multiple', child: Text('Multiple answers')),
                        DropdownMenuItem(
                            value: 'written', child: Text('Type answer')),
                      ],
                      onChanged: (value) =>
                          setState(() => question.kind = value ?? 'single'),
                    ),
                    const SizedBox(height: 9),
                    TextField(
                      controller: question.seconds,
                      keyboardType: TextInputType.number,
                      decoration: _input('Question time (seconds)')
                          .copyWith(helperText: '0 means no separate time'),
                    ),
                    if (question.kind != 'written') ...[
                      const SizedBox(height: 8),
                      ...question.options.asMap().entries.map((optionEntry) {
                        final optionIndex = optionEntry.key;
                        final controller = optionEntry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Row(children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                decoration: _input('Answer ${optionIndex + 1}'),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            if (question.options.length > 2)
                              IconButton(
                                onPressed: () => setState(() {
                                  final removed =
                                      question.options.removeAt(optionIndex);
                                  question.selectedAnswers
                                      .remove(removed.text.trim());
                                  removed.dispose();
                                }),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                          ]),
                        );
                      }),
                      OutlinedButton.icon(
                        onPressed: () => setState(() =>
                            question.options.add(TextEditingController())),
                        icon: const Icon(Icons.add),
                        label: const Text('Add another answer'),
                      ),
                      const SizedBox(height: 8),
                      if (question.kind == 'single')
                        DropdownButtonFormField<String>(
                          key:
                              ValueKey('correct-$index-${optionValues.join()}'),
                          initialValue:
                              optionValues.contains(question.answer.text)
                                  ? question.answer.text
                                  : null,
                          decoration: _input('Correct answer'),
                          items: optionValues
                              .map((option) => DropdownMenuItem(
                                  value: option, child: Text(option)))
                              .toList(),
                          onChanged: (value) =>
                              question.answer.text = value ?? '',
                        )
                      else
                        Column(
                          children: optionValues
                              .map((option) => CheckboxListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    value: question.selectedAnswers
                                        .contains(option),
                                    title: Text(option),
                                    onChanged: (selected) => setState(() {
                                      selected == true
                                          ? question.selectedAnswers.add(option)
                                          : question.selectedAnswers
                                              .remove(option);
                                    }),
                                  ))
                              .toList(),
                        ),
                    ] else ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: question.writtenAnswer,
                        decoration: _input('Accepted written answer'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _pickQuizImage(question),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(question.imageFile == null
                          ? question.imageUrl.text.isEmpty
                              ? 'Add question image'
                              : 'Replace question image'
                          : question.imageFile!.path
                              .split(Platform.pathSeparator)
                              .last),
                    ),
                    if (question.imageFile != null ||
                        question.imageUrl.text.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => setState(() {
                          question.imageFile = null;
                          question.imageUrl.clear();
                        }),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove question image'),
                      ),
                  ],
                ),
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: () =>
                setState(() => quizQuestions.add(_QuizQuestionDraft())),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Add another question'),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close)),
            title: Text(widget.item == null
                ? 'Add ICT Space item'
                : 'Edit ICT Space item'),
            actions: [
              TextButton(
                  onPressed: saving ? null : _save,
                  child: Text(saving ? 'Saving…' : 'Save'))
            ],
          ),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Text(widget.batchName,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: _input('Content type'),
              items: const [
                'heading',
                'text',
                'notice',
                'link',
                'divider',
                'resource',
                'quiz',
                'assignment'
              ]
                  .map((value) => DropdownMenuItem(
                      value: value,
                      child: Text(value[0].toUpperCase() + value.substring(1))))
                  .toList(),
              onChanged: (value) => setState(() => type = value ?? type),
            ),
            const SizedBox(height: 10),
            if (type == 'quiz')
              _quizEditor()
            else
              TextField(
                  controller: content,
                  maxLines: 6,
                  decoration: _input(type == 'assignment'
                      ? 'Assignment title or assignment details JSON'
                      : 'Text or description')),
            if (type == 'quiz' || type == 'assignment') ...[
              const SizedBox(height: 10),
              _dateTimeField(
                label: type == 'quiz'
                    ? 'Quiz upcoming date and time'
                    : 'Assignment upcoming date and time',
                value: availableAt,
                isDeadline: false,
              ),
              if (type == 'assignment')
                _dateTimeField(
                  label: 'Assignment submission deadline',
                  value: deadline,
                  isDeadline: true,
                ),
            ],
            if (type == 'link') ...[
              const SizedBox(height: 10),
              TextField(controller: url, decoration: _input('Link URL')),
            ],
            if (type != 'quiz') ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(file == null
                      ? 'Choose image, PDF, audio, video, or file'
                      : file!.path.split(Platform.pathSeparator).last)),
            ],
            if (type != 'quiz' && file != null)
              TextButton.icon(
                onPressed: () => setState(() => file = null),
                icon: const Icon(Icons.close),
                label: const Text('Remove selected file'),
              ),
            if (file == null && url.text.trim().isNotEmpty && type != 'link')
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.image_outlined),
                title: const Text('Current uploaded image or file'),
                subtitle: Text(removeExistingFile
                    ? 'This file will be removed when saved.'
                    : 'Stored safely in the Learning Space.'),
                trailing: TextButton(
                  onPressed: () =>
                      setState(() => removeExistingFile = !removeExistingFile),
                  child: Text(removeExistingFile ? 'Keep' : 'Remove'),
                ),
              ),
            const SizedBox(height: 16),
            Text('Colours',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _ColourField(label: 'Text colour', controller: color),
            _ColourField(
                label: 'Background colour',
                controller: background,
                allowTransparent: true),
            _ColourField(
                label: 'Notice border colour', controller: borderColor),
            const SizedBox(height: 10),
            Text('Text size: $fontSize'),
            Slider(
              value: const ['sm', 'base', 'lg', 'xl', '2xl']
                  .indexOf(fontSize)
                  .clamp(0, 4)
                  .toDouble(),
              min: 0,
              max: 4,
              divisions: 4,
              label: fontSize,
              onChanged: (value) => setState(() => fontSize =
                  const ['sm', 'base', 'lg', 'xl', '2xl'][value.round()]),
            ),
            Text('Text weight: $fontWeight'),
            Slider(
              value: const ['normal', 'medium', 'bold']
                  .indexOf(fontWeight)
                  .clamp(0, 2)
                  .toDouble(),
              min: 0,
              max: 2,
              divisions: 2,
              label: fontWeight,
              onChanged: (value) => setState(() => fontWeight =
                  const ['normal', 'medium', 'bold'][value.round()]),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Complete border'),
              subtitle: const Text('Apply all four notice border sides'),
              value: borderTop && borderRight && borderBottom && borderLeft,
              onChanged: (value) => setState(() {
                borderTop = value;
                borderRight = value;
                borderBottom = value;
                borderLeft = value;
              }),
            ),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilterChip(label: const Text('Top'), selected: borderTop, onSelected: (value) => setState(() => borderTop = value)),
              FilterChip(label: const Text('Right'), selected: borderRight, onSelected: (value) => setState(() => borderRight = value)),
              FilterChip(label: const Text('Bottom'), selected: borderBottom, onSelected: (value) => setState(() => borderBottom = value)),
              FilterChip(label: const Text('Left'), selected: borderLeft, onSelected: (value) => setState(() => borderLeft = value)),
            ]),
            if (borderTop) _ColourField(label: 'Top border colour', controller: borderTopColor),
            if (borderRight) _ColourField(label: 'Right border colour', controller: borderRightColor),
            if (borderBottom) _ColourField(label: 'Bottom border colour', controller: borderBottomColor),
            if (borderLeft) _ColourField(label: 'Left border colour', controller: borderLeftColor),
            const SizedBox(height: 10),
            SegmentedButton<String>(segments: const [
              ButtonSegment(value: 'left', icon: Icon(Icons.format_align_left)),
              ButtonSegment(
                  value: 'center', icon: Icon(Icons.format_align_center)),
              ButtonSegment(
                  value: 'right', icon: Icon(Icons.format_align_right))
            ], selected: {
              align
            }, onSelectionChanged: (v) => setState(() => align = v.first)),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Italic'),
                value: fontStyle == 'italic',
                onChanged: (v) =>
                    setState(() => fontStyle = v ? 'italic' : 'normal')),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Underline'),
                value: textDecoration == 'underline',
                onChanged: (v) =>
                    setState(() => textDecoration = v ? 'underline' : 'none')),
            if (textDecoration == 'underline')
              _ColourField(
                  label: 'Underline colour', controller: underlineColor),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Student preview'),
                    content: SizedBox(
                      width: 520,
                      child: SingleChildScrollView(
                        child: _SpacePreview(
                            batchName: widget.batchName, items: [draft]),
                      ),
                    ),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                  ),
                ),
                icon: const Icon(Icons.preview_outlined),
                label: const Text('Open full preview'),
              ),
            ),
            const SizedBox(height: 12),
            Text('Live preview',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _SpacePreview(batchName: widget.batchName, items: [draft]),
            const SizedBox(height: 90),
          ]),
          floatingActionButton: Wrap(spacing: 10, children: [
            if (widget.item == null)
              FloatingActionButton.extended(
                  heroTag: 'space-draft',
                  onPressed: saving ? null : () => _save(draftOnly: true),
                  icon: const Icon(Icons.add_to_photos_outlined),
                  label: const Text('Add to drafts')),
            FloatingActionButton.extended(
                heroTag: 'space-publish',
                onPressed: saving ? null : _save,
                icon: const Icon(Icons.publish),
                label: const Text('Publish')),
          ]),
        ),
      );
}

class _ColourField extends StatelessWidget {
  const _ColourField(
      {required this.label,
      required this.controller,
      this.allowTransparent = false});
  final String label;
  final TextEditingController controller;
  final bool allowTransparent;
  static const swatches = [
    '#ffffff',
    '#000000',
    '#1e293b',
    '#2563eb',
    '#7c3aed',
    '#dc2626',
    '#ea580c',
    '#16a34a',
    '#facc15',
    '#f1f5f9'
  ];

  Future<void> _pickAnyColour(BuildContext context) async {
    var hsv = HSVColor.fromColor(_spaceColor(
        controller.text == 'transparent' ? '#ffffff' : controller.text));
    final selected = await showDialog<Color>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('Choose $label'),
          content: SizedBox(
            width: 360,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                height: 74,
                decoration: BoxDecoration(
                  color: hsv.toColor(),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
              ),
              Slider(
                  min: 0,
                  max: 360,
                  value: hsv.hue,
                  onChanged: (value) => update(() => hsv = hsv.withHue(value))),
              Slider(
                  min: 0,
                  max: 1,
                  value: hsv.saturation,
                  onChanged: (value) =>
                      update(() => hsv = hsv.withSaturation(value))),
              Slider(
                  min: 0,
                  max: 1,
                  value: hsv.value,
                  onChanged: (value) =>
                      update(() => hsv = hsv.withValue(value))),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, hsv.toColor()),
                child: const Text('Use colour')),
          ],
        ),
      ),
    );
    if (selected != null) {
      controller.text =
          '#${selected.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 7),
          Wrap(spacing: 7, runSpacing: 7, children: [
            if (allowTransparent)
              ChoiceChip(
                  label: const Text('None'),
                  selected: controller.text == 'transparent',
                  onSelected: (_) => controller.text = 'transparent'),
            ...swatches.map((hex) => InkWell(
                  onTap: () => controller.text = hex,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                          color: _spaceColor(hex),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: controller.text.toLowerCase() == hex
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                              width: controller.text.toLowerCase() == hex
                                  ? 3
                                  : 1))),
                )),
          ]),
          const SizedBox(height: 7),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _pickAnyColour(context),
              icon: const Icon(Icons.colorize_rounded),
              label: const Text('Choose any colour'),
            ),
          ),
        ]),
      );
}

class _SpacePreview extends StatelessWidget {
  const _SpacePreview({required this.batchName, required this.items});
  final String batchName;
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(18)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.school_outlined),
            const SizedBox(width: 8),
            Expanded(
                child: Text(batchName.isEmpty ? 'Selected batch' : batchName,
                    style: const TextStyle(fontWeight: FontWeight.bold)))
          ]),
          const Divider(height: 22),
          if (items.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Column(children: [
                  Icon(Icons.preview_outlined, size: 42),
                  SizedBox(height: 8),
                  Text('Preview ready'),
                  Text(
                      'New content will appear here before and after publishing.',
                      textAlign: TextAlign.center)
                ])),
          ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _SpaceBlockPreview(item: item))),
        ]),
      );
}

class _SpaceBlockPreview extends StatelessWidget {
  const _SpaceBlockPreview({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final style = _map(item['style']);
    final type = '${item['type'] ?? 'text'}';
    final raw = '${item['content'] ?? ''}';
    String shown = raw.replaceAll(RegExp(r'\n\n__FILE__:.*$'), '');
    if (type == 'quiz' || type == 'assignment') {
      try {
        final data = _map(jsonDecode(raw));
        shown = type == 'assignment'
            ? '${data['title'] ?? 'Assignment'}\n${data['instructions'] ?? ''}'
            : 'Quiz · ${_list(data['questions']).length} question(s)';
      } catch (_) {}
    }
    if (type == 'divider') {
      return Divider(
          color: _spaceColor('${style['color'] ?? '#64748b'}'), thickness: 2);
    }
    final size = switch ('${style['fontSize']}') {
      'sm' => 13.0,
      'lg' => 18.0,
      'xl' => 22.0,
      '2xl' => 27.0,
      _ => 15.0
    };
    final alignment = switch ('${style['align']}') {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      _ => TextAlign.left
    };
    BorderSide side(String enabledKey, String colourKey) {
      final enabled = style.containsKey(enabledKey)
          ? style[enabledKey] == true
          : type == 'notice';
      return enabled
          ? BorderSide(
              color: _spaceColor(
                  '${style[colourKey] ?? style['borderColor'] ?? '#2563eb'}'),
              width: 2)
          : BorderSide.none;
    }
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _spaceColor('${style['background'] ?? 'transparent'}'),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          top: side('borderTop', 'borderTopColor'),
          right: side('borderRight', 'borderRightColor'),
          bottom: side('borderBottom', 'borderBottomColor'),
          left: side('borderLeft', 'borderLeftColor'),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (type == 'resource') const Icon(Icons.attach_file),
        Text(
            shown.isEmpty
                ? (type == 'resource'
                    ? 'Attached resource'
                    : 'Your content preview')
                : shown,
            textAlign: alignment,
            style: TextStyle(
                color: _spaceColor('${style['color'] ?? '#1e293b'}'),
                fontSize: size,
                fontWeight: '${style['fontWeight']}' == 'bold'
                    ? FontWeight.bold
                    : '${style['fontWeight']}' == 'medium'
                        ? FontWeight.w500
                        : FontWeight.normal,
                fontStyle: '${style['fontStyle']}' == 'italic'
                    ? FontStyle.italic
                    : FontStyle.normal,
                decoration: '${style['textDecoration']}' == 'underline'
                    ? TextDecoration.underline
                    : TextDecoration.none,
                decorationColor: _spaceColor(
                    '${style['underlineColor'] ?? style['color'] ?? '#2563eb'}'))),
        if ('${item['url'] ?? ''}'.isNotEmpty)
          TextButton.icon(
              onPressed: () => launchUrl(Uri.parse('${item['url']}'),
                  mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open resource')),
      ]),
    );
  }
}

Color _spaceColor(String value) {
  if (value == 'transparent' || value.isEmpty) return Colors.transparent;
  final hex = value.replaceFirst('#', '');
  final normalized = hex.length == 6 ? 'ff$hex' : hex;
  return Color(int.tryParse(normalized, radix: 16) ?? 0xff1e293b);
}

IconData _spaceIcon(String type) => switch (type) {
      'heading' => Icons.title,
      'notice' => Icons.campaign_outlined,
      'link' => Icons.link,
      'divider' => Icons.horizontal_rule,
      'resource' => Icons.attach_file,
      'quiz' => Icons.quiz_outlined,
      'assignment' => Icons.assignment_outlined,
      _ => Icons.notes,
    };

String _spaceLabel(Map<String, dynamic> item) {
  final type = '${item['type'] ?? 'content'}';
  if (type == 'assignment') {
    try {
      return '${_map(jsonDecode('${item['content']}'))['title'] ?? 'Assignment'}';
    } catch (_) {}
  }
  return type[0].toUpperCase() + type.substring(1);
}
