part of 'teacher_pages.dart';

enum _FieldKind {
  text,
  readOnly,
  csv,
  number,
  boolean,
  select,
  multiSelect,
  date,
  time
}

class _Field {
  const _Field(this.key, this.label,
      {this.kind = _FieldKind.text,
      this.options = const [],
      this.lines = 1,
      this.defaultBoolean = false});
  final String key;
  final String label;
  final _FieldKind kind;
  final List<String> options;
  final int lines;
  final bool defaultBoolean;
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.title,
    required this.subtitle,
    required this.children,
    this.loading = false,
    this.error,
    this.onRefresh,
    this.actions = const [],
    this.cacheExtent,
    this.compactHeader = false,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool loading;
  final Object? error;
  final Future<void> Function()? onRefresh;
  final List<Widget> actions;
  final double? cacheExtent;
  final bool compactHeader;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final list = ListView(
      cacheExtent: cacheExtent,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          padding: EdgeInsets.all(compactHeader ? 13 : 19),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary.withValues(alpha: .92),
                Color.lerp(scheme.primary, scheme.tertiary, .55)!
                    .withValues(alpha: .82),
                scheme.surfaceContainerHighest.withValues(alpha: .72),
              ],
              stops: const [0, .55, 1],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: scheme.onPrimary.withValues(alpha: .16),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: .22),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!compactHeader)
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 16,
                        color: scheme.onPrimary.withValues(alpha: .9)),
                    const SizedBox(width: 7),
                    Text(
                      'TEACHER STUDIO',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onPrimary.withValues(alpha: .82),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                    ),
                  ],
                ),
              SizedBox(height: compactHeader ? 0 : 11),
              Text(appLocale.tr(title),
                  style: (compactHeader
                          ? Theme.of(context).textTheme.titleLarge
                          : Theme.of(context).textTheme.headlineSmall)
                      ?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w900)),
              SizedBox(height: compactHeader ? 3 : 7),
              Text(
                appLocale.tr(subtitle),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onPrimary.withValues(alpha: .78)),
              ),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          _Message('$error', error: true),
        ],
        _DelayedLoading(loading: loading),
        const SizedBox(height: 14),
        ...children,
      ],
    );
    return Scaffold(
      appBar: actions.isEmpty ? null : AppBar(actions: actions),
      body: onRefresh == null
          ? list
          : RefreshIndicator(onRefresh: onRefresh!, child: list),
    );
  }
}

class _DelayedLoading extends StatefulWidget {
  const _DelayedLoading({required this.loading});

  final bool loading;

  @override
  State<_DelayedLoading> createState() => _DelayedLoadingState();
}

class _DelayedLoadingState extends State<_DelayedLoading> {
  var _generation = 0;
  var _visible = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _DelayedLoading oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loading != widget.loading) _sync();
  }

  void _sync() {
    final generation = ++_generation;
    if (!widget.loading) {
      _visible = false;
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (!mounted || generation != _generation || !widget.loading) return;
      setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.loading || !_visible) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.error = false});
  final String text;
  final bool error;
  @override
  Widget build(BuildContext context) => Card(
        color: error ? Theme.of(context).colorScheme.errorContainer : null,
        child: Padding(padding: const EdgeInsets.all(16), child: Text(text)),
      );
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);
  final String label;
  final dynamic value;
  @override
  Widget build(BuildContext context) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text('${value ?? 'Not set'}'));
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      ...children,
    ]);
  }
}

class _CrudPage extends StatefulWidget {
  const _CrudPage(
      {required this.title,
      required this.subtitle,
      required this.loader,
      required this.fields,
      required this.create,
      required this.update,
      required this.remove,
      this.onChanged});
  final String title;
  final String subtitle;
  final Future<List<Map<String, dynamic>>> Function() loader;
  final List<_Field> fields;
  final Future<dynamic> Function(Map<String, dynamic>) create;
  final Future<dynamic> Function(Map<String, dynamic>, Map<String, dynamic>)
      update;
  final Future<dynamic> Function(Map<String, dynamic>) remove;
  final VoidCallback? onChanged;
  @override
  State<_CrudPage> createState() => _CrudPageState();
}

class _CrudPageState extends State<_CrudPage> {
  late Future<List<Map<String, dynamic>>> request = widget.loader();
  Future<void> refresh() async {
    setState(() => request = widget.loader());
    await request;
  }

  Future<void> edit([Map<String, dynamic>? item]) async {
    var data = await _showForm(context,
        title: item == null ? 'Create' : 'Edit',
        initial: item ?? {},
        fields: widget.fields);
    if (data == null || !mounted) return;
    final saved = await _act(
        context,
        () => item == null ? widget.create(data) : widget.update(item, data),
        'Saved');
    if (!saved) return;
    widget.onChanged?.call();
    await refresh();
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: request,
        builder: (context, snapshot) => _PageFrame(
          title: widget.title,
          subtitle: widget.subtitle,
          loading: snapshot.connectionState == ConnectionState.waiting,
          error: snapshot.error,
          onRefresh: refresh,
          actions: [
            IconButton(onPressed: () => edit(), icon: const Icon(Icons.add))
          ],
          children: [
            if (snapshot.hasData && snapshot.data!.isEmpty)
              const _Message('No items yet. Tap + to create one.'),
            ...(snapshot.data ?? []).map((item) => Card(
                    child: ListTile(
                  title: Text(_title(item)),
                  subtitle: Text(_summary(item),
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                  onTap: () => edit(item),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') return edit(item);
                      final confirmed =
                          await _confirm(context, 'Delete this item?');
                      if (!context.mounted || !confirmed) return;
                      final removed = await _act(
                          context, () => widget.remove(item), 'Deleted');
                      if (!removed) return;
                      widget.onChanged?.call();
                      await refresh();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete'))
                    ],
                  ),
                ))),
          ],
        ),
      );
}

class _SimpleDataPage extends StatefulWidget {
  const _SimpleDataPage(
      {required this.title,
      required this.subtitle,
      required this.loader,
      required this.listKey,
      this.secondaryKeys = const []});
  final String title;
  final String subtitle;
  final Future<dynamic> Function() loader;
  final String listKey;
  final List<String> secondaryKeys;
  @override
  State<_SimpleDataPage> createState() => _SimpleDataPageState();
}

class _SimpleDataPageState extends State<_SimpleDataPage> {
  late Future<dynamic> request = widget.loader();
  Future<void> refresh() async {
    setState(() => request = widget.loader());
    await request;
  }

  List<Map<String, dynamic>> extract(dynamic raw, String key) {
    dynamic value = raw;
    for (final part in key.split('.')) {
      value = value is Map ? value[part] : null;
    }
    return _list(value);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
      future: request,
      builder: (context, snapshot) {
        final items = extract(snapshot.data, widget.listKey);
        return _PageFrame(
          title: widget.title,
          subtitle: widget.subtitle,
          loading: snapshot.connectionState == ConnectionState.waiting,
          error: snapshot.error,
          onRefresh: refresh,
          children: [
            if (items.isEmpty && snapshot.hasData)
              const _Message('No items are available yet.'),
            ...items.map(_dataTile),
            ...widget.secondaryKeys.map((key) => _Section(_label(key),
                extract(snapshot.data, key).map(_dataTile).toList())),
          ],
        );
      });
}

Future<Map<String, dynamic>?> _showForm(
  BuildContext context, {
  required String title,
  required Map<String, dynamic> initial,
  required List<_Field> fields,
  String confirmLabel = 'Save',
}) =>
    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DynamicFormDialog(
          title: title,
          initial: initial,
          fields: fields,
          confirmLabel: confirmLabel),
    );

Future<List<Map<String, dynamic>>?> _showWeeklyScheduleForm(
  BuildContext context, {
  required List<Map<String, dynamic>> initial,
}) =>
    showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (_) => _WeeklyScheduleDialog(initial: initial),
    );

class _WeeklyScheduleDialog extends StatefulWidget {
  const _WeeklyScheduleDialog({required this.initial});
  final List<Map<String, dynamic>> initial;
  @override
  State<_WeeklyScheduleDialog> createState() => _WeeklyScheduleDialogState();
}

class _WeeklyScheduleDialogState extends State<_WeeklyScheduleDialog> {
  late final Map<int, Map<String, String>> schedule = {
    for (final item in widget.initial)
      if ((item['weekday'] as num?)?.toInt() case final int weekday)
        weekday: {
          'startTime': '${item['startTime'] ?? '08:00'}',
          'endTime': '${item['endTime'] ?? '10:00'}',
        }
  };
  static const names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  Future<void> pick(int weekday, String key) async {
    final current = schedule[weekday]![key]!.split(':');
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(current.first) ?? 8,
        minute: int.tryParse(current.last) ?? 0,
      ),
    );
    if (value != null) {
      setState(() => schedule[weekday]![key] =
          '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Weekly class days'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(7, (index) {
                final weekday = index + 1;
                final value = schedule[weekday];
                return Column(children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(names[index]),
                    value: value != null,
                    onChanged: (enabled) => setState(() => enabled == true
                        ? schedule[weekday] = {
                            'startTime': '08:00',
                            'endTime': '10:00'
                          }
                        : schedule.remove(weekday)),
                  ),
                  if (value != null)
                    Row(children: [
                      Expanded(
                          child: OutlinedButton(
                        onPressed: () => pick(weekday, 'startTime'),
                        child: Text('Start ${value['startTime']}'),
                      )),
                      const SizedBox(width: 8),
                      Expanded(
                          child: OutlinedButton(
                        onPressed: () => pick(weekday, 'endTime'),
                        child: Text('End ${value['endTime']}'),
                      )),
                    ]),
                ]);
              }),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (schedule.isEmpty ||
                  schedule.values.any((item) =>
                      item['endTime']!.compareTo(item['startTime']!) <= 0)) {
                _snack(context,
                    'Select at least one day and keep every end time after its start time.',
                    error: true);
                return;
              }
              Navigator.pop(
                  context,
                  schedule.entries
                      .map((entry) => {
                            'weekday': entry.key,
                            'startTime': entry.value['startTime'],
                            'endTime': entry.value['endTime'],
                          })
                      .toList());
            },
            child: const Text('Save'),
          ),
        ],
      );
}

class _DynamicFormDialog extends StatefulWidget {
  const _DynamicFormDialog(
      {required this.title,
      required this.initial,
      required this.fields,
      required this.confirmLabel});
  final String title;
  final Map<String, dynamic> initial;
  final List<_Field> fields;
  final String confirmLabel;

  @override
  State<_DynamicFormDialog> createState() => _DynamicFormDialogState();
}

class _DynamicFormDialogState extends State<_DynamicFormDialog> {
  final controllers = <String, TextEditingController>{};
  final booleans = <String, bool>{};
  final selections = <String, String?>{};
  final multiSelections = <String, Set<String>>{};

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      if (field.kind == _FieldKind.boolean) {
        booleans[field.key] = widget.initial.containsKey(field.key)
            ? widget.initial[field.key] == true
            : field.defaultBoolean;
      } else if (field.kind == _FieldKind.select) {
        selections[field.key] =
            widget.initial[field.key]?.toString() ?? field.options.firstOrNull;
      } else if (field.kind == _FieldKind.multiSelect) {
        multiSelections[field.key] =
            _strings(widget.initial[field.key]).toSet();
      } else {
        final value = widget.initial[field.key];
        controllers[field.key] = TextEditingController(
          text: field.kind == _FieldKind.csv && value is List
              ? value.join(', ')
              : '${value ?? ''}',
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> result() {
    final data = <String, dynamic>{};
    for (final field in widget.fields) {
      if (field.kind == _FieldKind.boolean) {
        data[field.key] = booleans[field.key] ?? false;
      } else if (field.kind == _FieldKind.select) {
        data[field.key] = selections[field.key];
      } else if (field.kind == _FieldKind.multiSelect) {
        data[field.key] = multiSelections[field.key]?.toList() ?? <String>[];
      } else if (field.kind == _FieldKind.csv) {
        data[field.key] = controllers[field.key]!
            .text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList();
      } else if (field.kind == _FieldKind.number) {
        data[field.key] = num.tryParse(controllers[field.key]!.text) ?? 0;
      } else {
        data[field.key] = controllers[field.key]!.text.trim();
      }
    }
    return data;
  }

  Future<void> pickDate(_Field field) async {
    final current = DateTime.tryParse(controllers[field.key]!.text);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      controllers[field.key]!.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> pickTime(_Field field) async {
    final parts = controllers[field.key]!.text.split(':');
    final initial = parts.length == 2
        ? TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 8,
            minute: int.tryParse(parts[1]) ?? 0,
          )
        : const TimeOfDay(hour: 8, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      controllers[field.key]!.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.fields.map((field) {
                final selectedFeeMethod = selections['feeType'];
                if (field.key == 'dailyFee' && selectedFeeMethod != 'Day fee') {
                  return const SizedBox.shrink();
                }
                if (field.key == 'monthlyFee' &&
                    selectedFeeMethod != 'Monthly fee') {
                  return const SizedBox.shrink();
                }
                if (field.kind == _FieldKind.boolean) {
                  return SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(field.label),
                    value: booleans[field.key] ?? false,
                    onChanged: (value) =>
                        setState(() => booleans[field.key] = value),
                  );
                }
                if (field.kind == _FieldKind.select) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue:
                          field.options.contains(selections[field.key])
                              ? selections[field.key]
                              : null,
                      decoration: _input(field.label),
                      items: field.options
                          .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => selections[field.key] = value),
                    ),
                  );
                }
                if (field.kind == _FieldKind.multiSelect) {
                  final selected = multiSelections[field.key] ?? <String>{};
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InputDecorator(
                      decoration: _input(field.label),
                      child: Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: field.options
                            .map((value) => FilterChip(
                                  label: Text(value),
                                  selected: selected.contains(value),
                                  onSelected: (enabled) => setState(() {
                                    if (enabled) {
                                      selected.add(value);
                                    } else {
                                      selected.remove(value);
                                    }
                                    multiSelections[field.key] = selected;
                                  }),
                                ))
                            .toList(),
                      ),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: controllers[field.key],
                    readOnly: field.kind == _FieldKind.readOnly ||
                        field.kind == _FieldKind.date ||
                        field.kind == _FieldKind.time,
                    onTap: field.kind == _FieldKind.date
                        ? () => pickDate(field)
                        : field.kind == _FieldKind.time
                            ? () => pickTime(field)
                            : null,
                    minLines: field.lines,
                    maxLines: field.lines > 1 ? field.lines : null,
                    keyboardType: field.kind == _FieldKind.number
                        ? TextInputType.number
                        : null,
                    decoration: _input(field.label).copyWith(
                      suffixIcon: field.kind == _FieldKind.date
                          ? const Icon(Icons.calendar_month_outlined)
                          : field.kind == _FieldKind.time
                              ? const Icon(Icons.schedule_outlined)
                              : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, result()),
              child: Text(widget.confirmLabel)),
        ],
      );
}

Future<bool> _act(BuildContext context, Future<dynamic> Function() action,
    String success) async {
  try {
    await action();
    if (context.mounted) _snack(context, success);
    return true;
  } catch (error) {
    if (context.mounted) _snack(context, '$error', error: true);
    return false;
  }
}

Future<bool> _confirm(BuildContext context, String text) async =>
    await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              content: Text(text),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Confirm'))
              ],
            )) ??
    false;

Future<bool> _changeBatchThisWeek(BuildContext context,
    SessionController session, Map<String, dynamic> batch) async {
  final weekly = _list(batch['weeklySchedule']);
  final firstDate = DateTime.tryParse('${batch['classDate'] ?? ''}');
  if (weekly.isEmpty && firstDate == null) {
    _snack(context, 'Add the weekly class days and times first.', error: true);
    return false;
  }
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - DateTime.monday));
  Map<String, dynamic> selected = weekly.firstOrNull ??
      {
        'weekday': firstDate!.weekday,
        'startTime': batch['classStartTime'],
        'endTime': batch['classEndTime'],
      };
  if (weekly.length > 1) {
    final choice = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Choose this week’s class'),
        children: weekly.map((item) {
          final day = monday.add(
              Duration(days: ((item['weekday'] as num?)?.toInt() ?? 1) - 1));
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, item),
            child: Text(
                '${DateFormat('EEEE').format(day)} · ${item['startTime']}–${item['endTime']}'),
          );
        }).toList(),
      ),
    );
    if (choice == null || !context.mounted) return false;
    selected = choice;
  }
  final weekday = (selected['weekday'] as num?)?.toInt() ?? 1;
  final occurrence = monday.add(Duration(days: weekday - 1));
  final mode = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          title: Text(_title(batch),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(
              'This week: ${DateFormat('EEE, d MMM').format(occurrence)} · ${selected['startTime'] ?? ''}–${selected['endTime'] ?? ''}'),
        ),
        ListTile(
          leading: const Icon(Icons.event_busy_outlined),
          title: const Text('No class this week'),
          onTap: () => Navigator.pop(sheetContext, 'cancelled'),
        ),
        ListTile(
          leading: const Icon(Icons.edit_calendar_outlined),
          title: const Text('Adjust date or time / reschedule'),
          onTap: () => Navigator.pop(sheetContext, 'rescheduled'),
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (mode == null || !context.mounted) return false;

  var newDate = occurrence;
  var start = TimeOfDay(
      hour: int.tryParse('${selected['startTime']}'.split(':').first) ?? 8,
      minute: int.tryParse('${selected['startTime']}'.split(':').last) ?? 0);
  var end = TimeOfDay(
      hour: int.tryParse('${selected['endTime']}'.split(':').first) ?? 10,
      minute: int.tryParse('${selected['endTime']}'.split(':').last) ?? 0);
  if (mode == 'rescheduled') {
    final date = await showDatePicker(
        context: context,
        initialDate: occurrence.isBefore(DateTime(now.year, now.month, now.day))
            ? DateTime(now.year, now.month, now.day)
            : occurrence,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: monday.add(const Duration(days: 13)));
    if (date == null || !context.mounted) return false;
    newDate = date;
    final pickedStart =
        await showTimePicker(context: context, initialTime: start);
    if (pickedStart == null || !context.mounted) return false;
    start = pickedStart;
    final pickedEnd = await showTimePicker(context: context, initialTime: end);
    if (pickedEnd == null || !context.mounted) return false;
    end = pickedEnd;
  }
  final messageController = TextEditingController(
    text: mode == 'cancelled'
        ? 'There will be no class this week.'
        : 'This week’s class has been rescheduled.',
  );
  final customMessage = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Student notice'),
      content: TextField(
        controller: messageController,
        minLines: 3,
        maxLines: 5,
        decoration: _input('Custom message'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, messageController.text.trim()),
            child: const Text('Save change')),
      ],
    ),
  );
  messageController.dispose();
  if (customMessage == null || !context.mounted) return false;
  String clock(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  return _act(
    context,
    () => session.repository.saveClassScheduleOverride('${batch['id']}', {
      'occurrenceDate': DateFormat('yyyy-MM-dd').format(occurrence),
      'status': mode,
      if (mode == 'rescheduled')
        'rescheduledDate': DateFormat('yyyy-MM-dd').format(newDate),
      if (mode == 'rescheduled') 'startTime': clock(start),
      if (mode == 'rescheduled') 'endTime': clock(end),
      'message': customMessage.isEmpty
          ? (mode == 'cancelled'
              ? 'There will be no class this week.'
              : 'This week’s class time has changed.')
          : customMessage,
    }),
    mode == 'cancelled'
        ? 'Students were notified: no class this week.'
        : 'Students were notified about the new class time.',
  );
}

void _snack(BuildContext context, String text, {bool error = false}) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null));
InputDecoration _input(String label) =>
    InputDecoration(labelText: label, border: const OutlineInputBorder());
Map<String, dynamic> _map(dynamic value) =>
    value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};
List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList()
    : <Map<String, dynamic>>[];
List<String> _strings(dynamic value) =>
    value is List ? value.map((item) => '$item').toList() : <String>[];
String _title(Map<String, dynamic> item) =>
    '${item['title'] ?? item['name'] ?? item['displayName'] ?? item['studentName'] ?? item['exam'] ?? item['type'] ?? 'Item'}';
String _summary(Map<String, dynamic> item) =>
    '${item['description'] ?? item['content'] ?? item['details'] ?? item['message'] ?? item['status'] ?? item['studentId'] ?? item['email'] ?? item['date'] ?? ''}';
String _label(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
Widget _dataTile(Map<String, dynamic> item, [VoidCallback? onTap]) => Card(
    child: ListTile(
        onTap: onTap,
        title: Text(_title(item)),
        subtitle:
            Text(_summary(item), maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right)));

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

Future<bool> _showAddStudentsToBatch(
  BuildContext context,
  SessionController session, {
  String? initialBatchId,
}) async {
  try {
    final responses = await Future.wait([
      session.repository.batches(),
      session.repository.students(),
    ]);
    final batches = _list(_map(responses[0])['batches']);
    final students = _list(_map(responses[1])['students']);
    if (!context.mounted) return false;
    if (batches.isEmpty) {
      _snack(context, 'Create a batch before adding students.', error: true);
      return false;
    }
    String batchId = batches.any((item) => '${item['id']}' == initialBatchId)
        ? initialBatchId!
        : '${batches.first['id']}';
    String grade = '';
    final selected = <String>{};
    bool saving = false;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final gradeOptions = students
              .map((item) => '${item['grade'] ?? ''}'.trim())
              .where((item) => item.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          final eligible = students.where((student) {
            final matchesGrade =
                grade.isEmpty || '${student['grade'] ?? ''}' == grade;
            final notJoined = !_strings(student['batchIds']).contains(batchId);
            return matchesGrade && notJoined;
          }).toList();
          final eligibleIds = eligible
              .map((student) => '${student['uid'] ?? student['id']}')
              .toSet();
          final allSelected = eligibleIds.isNotEmpty &&
              eligibleIds.every((uid) => selected.contains(uid));
          return AlertDialog(
            scrollable: true,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: const Row(children: [
              Icon(Icons.group_add_outlined),
              SizedBox(width: 10),
              Expanded(
                child: Text('Add students to batch',
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ]),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: batchId,
                    decoration: _input('Select batch'),
                    items: batches
                        .map((batch) => DropdownMenuItem(
                            value: '${batch['id']}',
                            child: Text(_title(batch),
                                maxLines: 1, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: saving
                        ? null
                        : (value) => setDialogState(() {
                              batchId = value ?? batchId;
                              selected.clear();
                            }),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: grade,
                    decoration: _input('Filter by grade'),
                    items: [
                      const DropdownMenuItem(
                          value: '', child: Text('All grades')),
                      ...gradeOptions.map((item) =>
                          DropdownMenuItem(value: item, child: Text(item))),
                    ],
                    onChanged: saving
                        ? null
                        : (value) => setDialogState(() {
                              grade = value ?? '';
                              selected.clear();
                            }),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: allSelected,
                    title: Text('Select all (${eligible.length})'),
                    onChanged: saving || eligible.isEmpty
                        ? null
                        : (value) => setDialogState(() {
                              if (value == true) {
                                selected.addAll(eligibleIds);
                              } else {
                                selected.removeAll(eligibleIds);
                              }
                            }),
                  ),
                  const Divider(height: 1),
                  SizedBox(
                    height: 280,
                    child: eligible.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(18),
                            child: Text('No unassigned students found.'),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: eligible.length,
                            itemBuilder: (_, index) {
                              final student = eligible[index];
                              final uid = '${student['uid'] ?? student['id']}';
                              return CheckboxListTile(
                                value: selected.contains(uid),
                                title: Text(_title(student)),
                                subtitle: Text(
                                    '${student['studentId'] ?? 'ID pending'} · ${student['grade'] ?? 'Grade not set'}'),
                                onChanged: saving
                                    ? null
                                    : (value) => setDialogState(() {
                                          value == true
                                              ? selected.add(uid)
                                              : selected.remove(uid);
                                        }),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    saving ? null : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: saving || selected.isEmpty
                    ? null
                    : () async {
                        setDialogState(() => saving = true);
                        final batch = batches
                            .firstWhere((item) => '${item['id']}' == batchId);
                        try {
                          for (final uid in selected) {
                            await session.repository
                                .assignStudent(uid, batchId, _title(batch));
                          }
                          await session.repository.clearCache();
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (error) {
                          if (dialogContext.mounted) {
                            _snack(dialogContext, '$error', error: true);
                            setDialogState(() => saving = false);
                          }
                        }
                      },
                icon: saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(saving ? 'Adding...' : 'Add (${selected.length})'),
              ),
            ],
          );
        },
      ),
    );
    if (saved == true && context.mounted) {
      _snack(context, '${selected.length} students added to the batch');
    }
    return saved == true;
  } catch (error) {
    if (context.mounted) _snack(context, '$error', error: true);
    return false;
  }
}
