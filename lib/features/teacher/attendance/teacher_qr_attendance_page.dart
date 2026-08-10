part of '../teacher_pages.dart';

class _QrAttendancePage extends StatefulWidget {
  const _QrAttendancePage({required this.session});
  final SessionController session;

  @override
  State<_QrAttendancePage> createState() => _QrAttendancePageState();
}

class _QrAttendancePageState extends State<_QrAttendancePage> {
  final token = TextEditingController();
  final camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    cameraResolution: const Size(1280, 720),
    detectionTimeoutMs: 100,
  );
  List<Map<String, dynamic>> batches = [];
  final List<Map<String, String>> recent = [];
  final ValueNotifier<Map<String, dynamic>> scanFeedback =
      ValueNotifier<Map<String, dynamic>>(<String, dynamic>{});
  final ValueNotifier<bool> qrDetected = ValueNotifier<bool>(false);
  final ValueNotifier<bool> autoFocusEnabled = ValueNotifier<bool>(true);
  String? batchId;
  String classType = 'Theory';
  DateTime date = DateTime.now();
  bool loading = true;
  bool busy = false;
  bool qrCardsLoading = false;
  String lastToken = '';
  DateTime? lastScanAt;
  Map<String, dynamic>? suggestedClass;

  Map<String, dynamic>? get selectedBatch =>
      batches.where((item) => '${item['id']}' == batchId).firstOrNull;
  List<String> get classTypes => _strings(selectedBatch?['classTypes']);
  String get dateValue => DateFormat('yyyy-MM-dd').format(date);
  Map<String, String> get selectedClassPeriod {
    final weekday = date.weekday;
    final schedule = _list(selectedBatch?['weeklySchedule'])
        .where((item) => (item['weekday'] as num?)?.toInt() == weekday)
        .firstOrNull;
    return {
      'classStartTime': '${schedule?['startTime'] ?? ''}',
      'classEndTime': '${schedule?['endTime'] ?? ''}',
    };
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    token.dispose();
    camera.dispose();
    scanFeedback.dispose();
    qrDetected.dispose();
    autoFocusEnabled.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() => loading = true);
    try {
      if (refresh) await widget.session.repository.clearCache();
      final responses = await Future.wait([
        widget.session.repository.batches(),
        widget.session.repository.dashboard(),
      ]);
      batches = _list(_map(responses[0])['batches']);
      final summary = _map(_map(responses[1])['summary']);
      final live = _list(summary['liveClasses']);
      final scheduled = _list(summary['scheduledClasses'])
          .where((item) =>
              item['status'] != 'cancelled' && item['status'] != 'ended')
          .toList();
      suggestedClass = live.firstOrNull ?? scheduled.firstOrNull;
      if (batchId == null ||
          !batches.any((item) => '${item['id']}' == batchId)) {
        batchId = batches.firstOrNull?['id']?.toString();
      }
      final types = classTypes;
      if (types.isNotEmpty && !types.contains(classType)) {
        classType = types.first;
      }
    } catch (e) {
      if (mounted) _snack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _extractToken(String raw) =>
      raw.trim().split('/').where((part) => part.isNotEmpty).lastOrNull ?? '';

  Future<void> _scan(String raw) async {
    final value = _extractToken(raw);
    if (value.isEmpty || batchId == null || busy) return;
    final now = DateTime.now();
    if (value == lastToken &&
        lastScanAt != null &&
        now.difference(lastScanAt!).inSeconds < 5) {
      _snack(context, 'This student QR was already scanned for this class.');
      scanFeedback.value = {
        'success': false,
        'message': 'Already scanned for this class date and time period.',
      };
      return;
    }
    lastToken = value;
    lastScanAt = now;
    setState(() => busy = true);
    try {
      var response = _map(await widget.session.repository.markQrAttendance(
        value,
        {
          'batchId': batchId,
          'classType': classType,
          'date': dateValue,
          ...selectedClassPeriod,
        },
      ));
      final student = _map(response['student']);
      final name = '${student['displayName'] ?? 'Student'}';
      final studentId = '${student['studentId'] ?? 'ID pending'}';
      var payment = _map(response['payment']);
      if (payment['enabled'] == true &&
          payment['freeCard'] == true &&
          mounted) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('$name · Free card student'),
            content: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: true,
              title: const Text('Free card enabled'),
              subtitle: Text(
                '${payment['feeType'] == 'daily' ? 'Day fee' : 'Monthly fee'}: LKR ${payment['amount'] ?? 0}\nNo payment is required for this student.',
              ),
              onChanged: null,
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      }
      if (payment['paymentRequired'] == true && mounted) {
        final markPaid = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: Text(
                '$name · ${payment['feeType'] == 'daily' ? 'Day fee' : 'Monthly fee'}'),
            content: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: false,
              title: Text(
                'Paid LKR ${(payment['amount'] as num?)?.toStringAsFixed(0) ?? '0'}',
              ),
              subtitle: Text(payment['feeType'] == 'daily'
                  ? '${payment['paymentDate'] ?? dateValue} · ${_title(selectedBatch ?? {})}'
                  : '${payment['year'] ?? ''}-${('${payment['month'] ?? ''}').padLeft(2, '0')} · ${_title(selectedBatch ?? {})}'),
              onChanged: (value) => Navigator.pop(dialogContext, value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Not paid'),
              ),
            ],
          ),
        );
        if (markPaid == true) {
          response = _map(await widget.session.repository.markQrAttendance(
            value,
            {
              'batchId': batchId,
              'classType': classType,
              'date': dateValue,
              ...selectedClassPeriod,
              'paid': true,
            },
          ));
          payment = _map(response['payment']);
        }
      }
      final paymentLabel = payment['enabled'] != true
          ? 'Fee not managed'
          : payment['freeCard'] == true
              ? 'Free card'
              : payment['paid'] == true
                  ? 'Paid · LKR ${payment['amount'] ?? 0}'
                  : 'Payment due · LKR ${payment['amount'] ?? 0}';
      if (mounted) {
        setState(() {
          recent.insert(0, {
            'name': name,
            'studentId': studentId,
            'time': DateFormat('h:mm:ss a').format(now),
            'payment': paymentLabel,
            'paid': '${payment['paid'] == true || payment['freeCard'] == true}',
            'amount': '${payment['amount'] ?? 0}',
            'paidDate': '${payment['paidAt'] ?? ''}',
          });
          if (recent.length > 8) recent.removeLast();
        });
        scanFeedback.value = {
          'success': true,
          'message': 'QR scanned successfully',
          'name': name,
          'studentId': studentId,
          'payment': paymentLabel,
          'paidDate': payment['paidAt'],
          'count': response['attendanceCount'] ?? recent.length,
        };
        _snack(context, '$name marked present · $paymentLabel');
      }
      token.clear();
    } catch (e) {
      scanFeedback.value = {'success': false, 'message': '$e'};
      if (mounted) _snack(context, '$e', error: true);
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (mounted) setState(() => busy = false);
      if (autoFocusEnabled.value) await _refocusCamera();
    }
  }

  Future<void> _refocusCamera() async {
    try {
      await camera.stop();
      await Future<void>.delayed(const Duration(milliseconds: 140));
      await camera.start();
    } catch (_) {
      // The scanner may already be closing.
    }
  }

  Future<void> _chooseDate() async {
    final result = await showDatePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        initialDate: date);
    if (result != null) setState(() => date = result);
  }

  Future<void> _openScanner() async {
    if (batchId == null || !mounted) return;
    scanFeedback.value = <String, dynamic>{};
    qrDetected.value = false;
    await camera.start();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 40),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 420,
          height: 590,
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.qr_code_scanner_rounded),
              title: const Text('Scan student QR'),
              subtitle: Text(
                  '${_title(selectedBatch ?? {})} · $classType · $dateValue'),
              trailing: IconButton(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Expanded(
              child: Stack(fit: StackFit.expand, children: [
                MobileScanner(
                  controller: camera,
                  onDetect: (capture) {
                    final raw = capture.barcodes.firstOrNull?.rawValue;
                    if (raw != null) {
                      qrDetected.value = true;
                      Future<void>.delayed(const Duration(milliseconds: 850),
                          () {
                        if (mounted) qrDetected.value = false;
                      });
                      _scan(raw);
                    }
                  },
                ),
                IgnorePointer(
                  child: Center(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: qrDetected,
                      builder: (context, detected, _) => AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 230,
                        height: 230,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: detected ? Colors.yellow : Colors.white,
                              width: detected ? 5 : 3),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: detected
                              ? [
                                  BoxShadow(
                                    color: Colors.yellow.withValues(alpha: .55),
                                    blurRadius: 20,
                                  )
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Icon(Icons.qr_code_2_rounded,
                              color: detected ? Colors.yellow : Colors.white54,
                              size: 76),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: autoFocusEnabled,
                        builder: (context, enabled, _) => FilterChip(
                          selected: enabled,
                          onSelected: (value) => autoFocusEnabled.value = value,
                          avatar: const Icon(Icons.center_focus_weak_rounded,
                              size: 18),
                          label: const Text('Auto focus'),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _refocusCamera,
                        icon: const Icon(Icons.center_focus_strong_rounded),
                        label: const Text('Focus'),
                      ),
                    ],
                  ),
                ),
                if (busy) const Center(child: CircularProgressIndicator()),
              ]),
            ),
            ValueListenableBuilder<Map<String, dynamic>>(
              valueListenable: scanFeedback,
              builder: (context, feedback, _) {
                final success = feedback['success'] == true;
                final paidAt =
                    DateTime.tryParse('${feedback['paidDate'] ?? ''}');
                return Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 90),
                  padding: const EdgeInsets.all(14),
                  color: feedback.isEmpty
                      ? Theme.of(context).colorScheme.surfaceContainer
                      : success
                          ? Colors.green.withValues(alpha: .14)
                          : Theme.of(context).colorScheme.errorContainer,
                  child: feedback.isEmpty
                      ? const Text(
                          'Auto focus is active. Keep the QR inside the square.',
                          textAlign: TextAlign.center,
                        )
                      : Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('${feedback['message']}',
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)),
                          if (success)
                            Text(
                                '${feedback['name']} · ${feedback['studentId']}'),
                          if (success)
                            Text(
                                'Attendance count: ${feedback['count']} · ${feedback['payment']}'),
                          if (paidAt != null)
                            Text(
                                'Fee paid: ${DateFormat.yMMMd().add_jm().format(paidAt.toLocal())}'),
                        ]),
                );
              },
            ),
          ]),
        ),
      ),
    );
    await camera.stop();
  }

  void _selectBatch(String? value) {
    if (value == null) return;
    setState(() {
      batchId = value;
      final types = classTypes;
      classType = types.firstOrNull ?? 'Theory';
    });
  }

  void _useSuggested() {
    final item = suggestedClass;
    if (item == null) return;
    final batch = batches
        .where((value) => '${value['id']}' == '${item['batchId']}')
        .firstOrNull;
    if (batch == null) return;
    setState(() {
      batchId = '${batch['id']}';
      classType = _strings(batch['classTypes']).firstOrNull ?? 'Theory';
      date = DateTime.tryParse('${item['classDate']}') ?? date;
    });
    _snack(context, '${item['batchName']} selected');
  }

  Future<void> _copyScanLink() async {
    if (batchId == null) return;
    final link =
        '${AppConfig.teacherWebUrl}/teacher/attendance/camera?batchId=${Uri.encodeComponent(batchId!)}&classType=${Uri.encodeComponent(classType)}&date=$dateValue';
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) _snack(context, 'QR scan link copied');
  }

  Future<void> _openStudentQrCards() async {
    final selectedId = batchId;
    if (selectedId == null || qrCardsLoading) return;
    setState(() => qrCardsLoading = true);
    try {
      final response = _map(await widget.session.repository
          .batchQrCards(selectedId, refresh: true));
      final cards = _list(response['cards']);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: FractionallySizedBox(
            heightFactor: .92,
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.qr_code_2_rounded),
                title: Text(
                    '${_map(response['batch'])['name'] ?? 'Student QR cards'}'),
                subtitle:
                    Text('${cards.length} students · Opens inside m.teacher'),
                trailing: FilledButton.icon(
                  onPressed: cards.isEmpty
                      ? null
                      : () => _downloadStudentQrPdf(response),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download PDF'),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: cards.isEmpty
                    ? const Center(
                        child: Text('No approved students in this batch.'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: .76,
                        ),
                        itemCount: cards.length,
                        itemBuilder: (context, index) {
                          final card = cards[index];
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(children: [
                                Expanded(
                                  child: QrImageView(
                                    data: '${card['qrToken'] ?? ''}',
                                    backgroundColor: Colors.white,
                                    padding: const EdgeInsets.all(7),
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  '${card['displayName'] ?? 'Student'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  [card['studentId'], card['grade']]
                                      .where((value) => '$value'.isNotEmpty)
                                      .join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ]),
                            ),
                          );
                        },
                      ),
              ),
            ]),
          ),
        ),
      );
    } catch (error) {
      if (mounted) _snack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => qrCardsLoading = false);
    }
  }

  Future<void> _downloadStudentQrPdf(Map<String, dynamic> response) async {
    try {
      final cards = _list(response['cards']);
      final batch = _map(response['batch']);
      final teacher = _map(response['teacher']);
      final branding = _map(response['branding']);
      final logoData = await rootBundle.load('assets/app_logo.png');
      final logo = pw.MemoryImage(logoData.buffer
          .asUint8List(logoData.offsetInBytes, logoData.lengthInBytes));
      final document = pw.Document(
        title: '${batch['name'] ?? 'Batch'} student QR cards',
        author: '${teacher['displayName'] ?? 'Teacher'}',
      );
      for (var offset = 0; offset < cards.length; offset += 16) {
        final pageCards = cards.skip(offset).take(16).toList();
        document.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (context) => pw.Column(children: [
            pw.Row(children: [
              pw.Image(logo, width: 28, height: 28, fit: pw.BoxFit.contain),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('${branding['appName'] ?? 'Magical LMS'}',
                          style: pw.TextStyle(
                              fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                          '${batch['name'] ?? ''} · ${teacher['displayName'] ?? ''}',
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey700)),
                    ]),
              ),
              pw.Text('Page ${(offset ~/ 16) + 1}',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey600)),
            ]),
            pw.SizedBox(height: 10),
            pw.Expanded(
              child: pw.GridView(
                crossAxisCount: 4,
                mainAxisSpacing: 7,
                crossAxisSpacing: 7,
                childAspectRatio: .72,
                children: pageCards
                    .map((card) => pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            border: pw.Border.all(color: PdfColors.blueGrey300),
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Column(children: [
                            pw.Expanded(
                              child: pw.BarcodeWidget(
                                barcode: pw.Barcode.qrCode(),
                                data: '${card['qrToken'] ?? ''}',
                                drawText: false,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text('${card['displayName'] ?? 'Student'}',
                                maxLines: 1,
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Text(
                                [card['studentId'], card['grade']]
                                    .where((value) => '$value'.isNotEmpty)
                                    .join(' · '),
                                maxLines: 1,
                                style: const pw.TextStyle(
                                    fontSize: 6.5, color: PdfColors.grey700)),
                          ]),
                        ))
                    .toList(),
              ),
            ),
          ]),
        ));
      }
      final safeName = '${batch['name'] ?? 'batch'}'
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-');
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save student QR cards',
        fileName: '$safeName-student-qr-cards.pdf',
        bytes: await document.save(),
      );
      if (mounted) {
        _snack(context, 'Student QR cards PDF saved.');
      }
    } catch (error) {
      if (mounted) {
        _snack(context, 'Could not create QR PDF: $error', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => _PageFrame(
        title: 'QR quick attendance',
        subtitle:
            'Choose the register, then scan each student QR. Present status saves immediately.',
        loading: loading,
        onRefresh: () => _load(refresh: true),
        children: [
          if (suggestedClass != null) ...[
            Card(
                child: ListTile(
                    leading: const Icon(Icons.auto_awesome_rounded),
                    title: Text('Suggested: ${suggestedClass!['batchName']}'),
                    subtitle: Text(
                        '${suggestedClass!['classDate']} • ${suggestedClass!['classStartTime']}–${suggestedClass!['classEndTime']}'),
                    trailing: FilledButton(
                        onPressed: _useSuggested, child: const Text('Use')))),
            const SizedBox(height: 10),
          ],
          DropdownButtonFormField<String>(
              initialValue: batchId,
              decoration: _input('Batch'),
              items: batches
                  .map((item) => DropdownMenuItem(
                      value: '${item['id']}', child: Text(_title(item))))
                  .toList(),
              onChanged: _selectBatch),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
              initialValue: classTypes.contains(classType) ? classType : null,
              decoration: _input('Class type'),
              items: classTypes
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) =>
                  setState(() => classType = value ?? classType)),
          const SizedBox(height: 10),
          InkWell(
              onTap: _chooseDate,
              child: InputDecorator(
                  decoration: _input('Attendance date'),
                  child: Row(children: [
                    Expanded(
                        child:
                            Text(DateFormat('EEEE, d MMMM yyyy').format(date))),
                    const Icon(Icons.calendar_month)
                  ]))),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
                onPressed: batchId == null ? null : _copyScanLink,
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('Copy QR scan link')),
            OutlinedButton.icon(
              onPressed: batchId == null || qrCardsLoading
                  ? null
                  : _openStudentQrCards,
              icon: qrCardsLoading
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.qr_code_2_rounded),
              label: const Text('Student QR cards'),
            ),
          ]),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              ListTile(
                  leading: const Icon(Icons.qr_code_scanner),
                  title: const Text('Camera QR scanner'),
                  subtitle: Text(batchId == null
                      ? 'Select a batch first'
                      : '${_title(selectedBatch ?? {})} · $classType · $dateValue'),
                  trailing: FilledButton.icon(
                      onPressed: batchId == null ? null : _openScanner,
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text('Open'))),
            ]),
          ),
          const SizedBox(height: 12),
          TextField(
              controller: token,
              decoration: _input('QR token or scanned link')
                  .copyWith(prefixIcon: const Icon(Icons.key)),
              onSubmitted: _scan),
          const SizedBox(height: 8),
          FilledButton.icon(
              onPressed:
                  busy || batchId == null ? null : () => _scan(token.text),
              icon: const Icon(Icons.how_to_reg),
              label: const Text('Mark present')),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
                'Scanned this session · ${recent.length} present · Paid total LKR ${recent.where((item) => item['paid'] == 'true').fold<double>(0, (sum, item) => sum + (double.tryParse(item['amount'] ?? '') ?? 0)).toStringAsFixed(0)}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            ...recent.map((item) => ListTile(
                leading: const CircleAvatar(child: Icon(Icons.check)),
                title: Text('${item['name']} · ${item['studentId']}'),
                subtitle: Text([
                  item['payment'] ?? '',
                  if (DateTime.tryParse(item['paidDate'] ?? '') != null)
                    'Paid ${DateFormat.yMMMd().add_jm().format(DateTime.parse(item['paidDate']!).toLocal())}',
                ].join('\n')),
                trailing: Text(item['time']!))),
          ],
        ],
      );
}
