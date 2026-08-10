part of 'teacher_pages.dart';

String _subscriptionMoney(dynamic value) =>
    'LKR ${(num.tryParse('$value') ?? 0).toStringAsFixed(0)}';

class _TeacherSubscriptionPage extends StatefulWidget {
  const _TeacherSubscriptionPage({required this.session});
  final SessionController session;

  @override
  State<_TeacherSubscriptionPage> createState() =>
      _TeacherSubscriptionPageState();
}

class _TeacherSubscriptionPageState extends State<_TeacherSubscriptionPage> {
  late Future<void> _future = _load();
  final _note = TextEditingController();
  List<Map<String, dynamic>> _plans = [];
  Map<String, dynamic>? _account;
  String _tierId = '';
  String _cycle = 'monthly';
  File? _slip;
  bool _submitting = false;

  Future<void> _load() async {
    final responses = await Future.wait([
      widget.session.repository.teacherPlans(),
      widget.session.repository.teacherSubscription(),
    ]);
    final planRoot = responses[0] is Map ? responses[0] as Map : const {};
    final accountRoot = responses[1] is Map ? responses[1] as Map : const {};
    _plans = (planRoot['plans'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final value = accountRoot['subscription'];
    _account = value is Map ? Map<String, dynamic>.from(value) : null;
    final teacher = accountRoot['teacher'] is Map
        ? accountRoot['teacher'] as Map
        : const {};
    _tierId =
        '${_account?['tierId'] ?? teacher['tierId'] ?? (_plans.isEmpty ? '' : _plans.first['id'])}';
    final savedCycle =
        '${_account?['plan'] ?? teacher['billingCycle'] ?? 'monthly'}';
    _cycle = savedCycle == 'yearly' ? 'yearly' : 'monthly';
  }

  Map<String, dynamic>? get _selectedPlan {
    for (final plan in _plans) {
      if ('${plan['id']}' == _tierId) return plan;
    }
    return _plans.isEmpty ? null : _plans.first;
  }

  num _price(Map<String, dynamic> plan, String key) =>
      num.tryParse('${plan[key]}') ?? 0;

  Future<void> _pickSlip() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );
    final path = result?.files.single.path;
    if (path != null && mounted) setState(() => _slip = File(path));
  }

  Future<void> _submit() async {
    final plan = _selectedPlan;
    if (plan == null) {
      return _snack(context, 'Choose a subscription plan', error: true);
    }
    if (_slip == null) {
      return _snack(context, 'Choose your payment slip', error: true);
    }
    setState(() => _submitting = true);
    try {
      final uploaded = await widget.session.repository.uploadFile(_slip!);
      final response =
          await widget.session.repository.submitTeacherSubscription({
        'tierId': plan['id'],
        'billingCycle': _cycle,
        'slipUrl': uploaded['url'],
        'slipName': uploaded['fileName'] ??
            _slip!.path.split(Platform.pathSeparator).last,
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      });
      final root = response is Map ? response : const {};
      final value = root['subscription'];
      if (mounted) {
        setState(() {
          _account = value is Map ? Map<String, dynamic>.from(value) : _account;
          _slip = null;
        });
        _snack(context, 'Payment sent for admin approval');
      }
    } catch (error) {
      if (mounted) _snack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openPaymentPopup(Map<String, dynamic> plan) async {
    File? selectedSlip;
    bool sending = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final normal = _price(plan, _cycle);
          final offer = _price(
              plan, _cycle == 'monthly' ? 'monthlyOffer' : 'yearlyOffer');
          final payable = offer > 0 && offer < normal ? offer : normal;
          return AlertDialog(
            title: const Text('Submit subscription payment'),
            content: SizedBox(
              width: 390,
              child: SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Text(
                        '${plan['label']} · $_cycle · ${_subscriptionMoney(payable)}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: sending
                          ? null
                          : () async {
                              final result = await FilePicker.platform
                                  .pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: const [
                                    'jpg',
                                    'jpeg',
                                    'png',
                                    'webp',
                                    'pdf'
                                  ]);
                              final path = result?.files.single.path;
                              if (path != null) {
                                setDialogState(() => selectedSlip = File(path));
                              }
                            },
                      icon: const Icon(Icons.upload_file_rounded),
                      label: Text(selectedSlip?.path
                              .split(Platform.pathSeparator)
                              .last ??
                          'Choose payment slip'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _note,
                        maxLines: 3,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: const InputDecoration(
                            labelText: 'Payment reference',
                            hintText: 'Bank reference number or payment note',
                            border: OutlineInputBorder())),
                  ])),
            ),
            actions: [
              TextButton(
                  onPressed:
                      sending ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel')),
              FilledButton.icon(
                onPressed: sending ||
                        selectedSlip == null ||
                        _note.text.trim().isEmpty
                    ? null
                    : () async {
                        setDialogState(() => sending = true);
                        try {
                          final uploaded = await widget.session.repository
                              .uploadFile(selectedSlip!);
                          final response = await widget.session.repository
                              .submitTeacherSubscription({
                            'tierId': plan['id'],
                            'billingCycle': _cycle,
                            'slipUrl': uploaded['url'],
                            'slipName': uploaded['fileName'] ??
                                selectedSlip!.path
                                    .split(Platform.pathSeparator)
                                    .last,
                            if (_note.text.trim().isNotEmpty)
                              'note': _note.text.trim()
                          });
                          final root = response is Map ? response : const {};
                          final value = root['subscription'];
                          if (!mounted) return;
                          setState(() => _account = value is Map
                              ? Map<String, dynamic>.from(value)
                              : _account);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          _snack(
                              context, 'Payment slip sent for admin approval');
                        } catch (error) {
                          if (dialogContext.mounted) {
                            setDialogState(() => sending = false);
                          }
                          if (mounted) _snack(context, '$error', error: true);
                        }
                      },
                icon: sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded),
                label: const Text('Send for admin approval'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: _future,
        builder: (context, snapshot) {
          final plan = _selectedPlan;
          final regular = plan == null ? 0 : _price(plan, _cycle);
          final offerKey = _cycle == 'monthly' ? 'monthlyOffer' : 'yearlyOffer';
          final offer = plan == null ? 0 : _price(plan, offerKey);
          final payable = offer > 0 && offer < regular ? offer : regular;
          return _PageFrame(
            title: 'Manage subscription',
            subtitle:
                'Choose any package, view admin offers, and submit your payment slip.',
            loading: snapshot.connectionState == ConnectionState.waiting,
            error: snapshot.error,
            onRefresh: () async {
              setState(() => _future = _load());
              await _future;
              if (mounted) setState(() {});
            },
            children: [
              if (snapshot.connectionState != ConnectionState.waiting &&
                  _plans.isEmpty)
                const Card(
                    child: ListTile(
                        leading: Icon(Icons.visibility_off_outlined),
                        title: Text(
                            'Subscription packages are currently unavailable'),
                        subtitle: Text(
                            'The administrator has temporarily hidden package details. Your current access status is unchanged.'))),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xff151c43),
                      Color(0xff5631a8),
                      Color(0xff087c8f)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x334f46e5),
                        blurRadius: 24,
                        offset: Offset(0, 10))
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.auto_awesome_rounded,
                          color: Color(0xffc4b5fd)),
                      SizedBox(width: 8),
                      Text('TAPP PREMIUM',
                          style: TextStyle(
                              color: Color(0xffddd6fe),
                              fontWeight: FontWeight.w800))
                    ]),
                    SizedBox(height: 12),
                    Text('Your classroom, your plan',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            fontWeight: FontWeight.w900)),
                    SizedBox(height: 8),
                    Text(
                        'The first 30 days are free. Select any package and continue after admin payment approval.',
                        style:
                            TextStyle(color: Color(0xffdbeafe), height: 1.4)),
                  ],
                ),
              ),
              if (_account != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.verified_rounded),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text('Subscription status',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w900))),
                            Chip(
                                label: Text(
                                    '${_account!['status'] ?? 'pending'}'
                                        .toUpperCase())),
                          ]),
                          const SizedBox(height: 8),
                          Text(
                              '${_account!['tierId'] ?? ''} · ${_account!['plan'] ?? _cycle}'),
                          Text(
                              'Payment: ${('${_account!['paymentStatus'] ?? 'not submitted'}').replaceAll('_', ' ')}'),
                          if (_account!['trialEndsAt'] != null)
                            Text(
                                'Trial ends: ${DateFormat('MMM d, yyyy').format(DateTime.tryParse('${_account!['trialEndsAt']}')?.toLocal() ?? DateTime.now())}'),
                        ]),
                  ),
                ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'monthly',
                      label: Text('Monthly'),
                      icon: Icon(Icons.calendar_view_month_rounded)),
                  ButtonSegment(
                      value: 'yearly',
                      label: Text('Yearly'),
                      icon: Icon(Icons.event_available_rounded)),
                ],
                selected: {_cycle},
                onSelectionChanged: (value) =>
                    setState(() => _cycle = value.first),
              ),
              ..._plans.map((item) {
                final active = '${item['id']}' == _tierId;
                final normal = _price(item, _cycle);
                final currentOffer = _price(
                    item, _cycle == 'monthly' ? 'monthlyOffer' : 'yearlyOffer');
                final hasOffer = currentOffer > 0 && currentOffer < normal;
                return InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () {
                    setState(() => _tierId = '${item['id']}');
                    _openPaymentPopup(item);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: active
                          ? Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: .45)
                          : Theme.of(context).colorScheme.surfaceContainer,
                      border: Border.all(
                          color: active
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).dividerColor,
                          width: active ? 2 : 1),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text('${item['label']}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                              fontWeight: FontWeight.w900)),
                                  Text('${item['studentLabel']}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                ])),
                            if (active)
                              Icon(Icons.check_circle_rounded,
                                  color: Theme.of(context).colorScheme.primary),
                          ]),
                          const SizedBox(height: 14),
                          if (hasOffer)
                            Text(_subscriptionMoney(normal),
                                style: const TextStyle(
                                    decoration: TextDecoration.lineThrough)),
                          Text(
                              _subscriptionMoney(
                                  hasOffer ? currentOffer : normal),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900)),
                          Text('per ${_cycle == 'monthly' ? 'month' : 'year'}'),
                          if (hasOffer)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Chip(
                                  avatar: const Icon(Icons.local_offer_rounded,
                                      size: 17),
                                  label: Text(
                                      'Admin offer · Save ${_subscriptionMoney(normal - currentOffer)}')),
                            ),
                        ]),
                  ),
                );
              }),
              if (_submitting && plan != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Submit payment',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(
                              '${plan['label']} · $_cycle · ${_subscriptionMoney(payable)}'),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                              onPressed: _submitting ? null : _pickSlip,
                              icon: const Icon(Icons.upload_file_rounded),
                              label: Text(_slip?.path
                                      .split(Platform.pathSeparator)
                                      .last ??
                                  'Choose bank slip (image or PDF)')),
                          const SizedBox(height: 10),
                          TextField(
                              controller: _note,
                              decoration: const InputDecoration(
                                  labelText:
                                      'Payment reference or note (optional)',
                                  border: OutlineInputBorder())),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                              onPressed:
                                  _submitting || _slip == null ? null : _submit,
                              icon: _submitting
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.send_rounded),
                              label: const Text('Send for admin approval')),
                        ]),
                  ),
                ),
            ],
          );
        },
      );
}

class _TeacherHelpPage extends StatefulWidget {
  const _TeacherHelpPage({required this.session});
  final SessionController session;

  @override
  State<_TeacherHelpPage> createState() => _TeacherHelpPageState();
}

class _TeacherHelpPageState extends State<_TeacherHelpPage> {
  final _message = TextEditingController();
  late Future<List<Object>> _data = _load();
  bool _sending = false;

  Future<List<Object>> _load({bool refresh = false}) async {
    final responses = await Future.wait([
      widget.session.repository.helpVideos(),
      widget.session.repository.supportMessages(refresh: refresh),
    ]);
    final videoRoot = responses[0] is Map ? responses[0] as Map : const {};
    final messageRoot = responses[1] is Map ? responses[1] as Map : const {};
    final videos = (videoRoot['videos'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) =>
            item['audience'] == 'all' || item['audience'] == 'teacher')
        .toList();
    final messages = (messageRoot['messages'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    return [videos, messages];
  }

  Future<void> _refresh() async {
    setState(() => _data = _load(refresh: true));
    await _data;
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.session.repository.sendSupportMessage(text);
      _message.clear();
      await _refresh();
    } catch (error) {
      if (mounted) _snack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openAdminChat(List<Map<String, dynamic>> source) async {
    final messages = [...source];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.admin_panel_settings_outlined),
            SizedBox(width: 10),
            Expanded(child: Text('Private administrator chat'))
          ]),
          content: SizedBox(
            width: 390,
            height: 430,
            child: Column(children: [
              Expanded(
                  child: messages.isEmpty
                      ? const Center(
                          child: Text('Send your first support message.'))
                      : ListView.builder(
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final item = messages[index];
                            final mine = item['senderRole'] != 'admin';
                            return Align(
                              alignment: mine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                constraints:
                                    const BoxConstraints(maxWidth: 280),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                    color: mine
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                        : Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(16)),
                                child: Text('${item['text'] ?? ''}'),
                              ),
                            );
                          })),
              const Divider(),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: _message,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                            hintText: 'Message the administrator'))),
                IconButton(
                  onPressed: _sending
                      ? null
                      : () async {
                          final text = _message.text.trim();
                          if (text.isEmpty) return;
                          setDialogState(() => _sending = true);
                          try {
                            await widget.session.repository
                                .sendSupportMessage(text);
                            _message.clear();
                            messages
                                .add({'text': text, 'senderRole': 'teacher'});
                            setDialogState(() => _sending = false);
                            if (mounted) {
                              setState(() => _data = _load(refresh: true));
                            }
                          } catch (_) {
                            setDialogState(() => _sending = false);
                          }
                        },
                  icon: _sending
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                ),
              ]),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'))
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Object>>(
        future: _data,
        builder: (context, snapshot) {
          final videos = snapshot.hasData
              ? List<Map<String, dynamic>>.from(snapshot.data![0] as List)
              : <Map<String, dynamic>>[];
          final messages = snapshot.hasData
              ? List<Map<String, dynamic>>.from(snapshot.data![1] as List)
              : <Map<String, dynamic>>[];
          return Stack(children: [
            _PageFrame(
              title: 'Help & admin support',
              subtitle:
                  'Watch help videos inside the app or privately contact the administrator.',
              loading: snapshot.connectionState == ConnectionState.waiting,
              error: snapshot.error,
              onRefresh: _refresh,
              children: [
                Text('Help videos',
                    style: Theme.of(context).textTheme.titleLarge),
                if (videos.isEmpty)
                  const _Message('No help videos have been published yet.'),
                ...videos.map((video) => Card(
                        child: ListTile(
                      leading: const CircleAvatar(
                          child: Icon(Icons.play_arrow_rounded)),
                      title: Text('${video['title'] ?? 'Help video'}'),
                      subtitle: const Text('Opens in the secure in-app viewer'),
                      trailing: const Icon(Icons.open_in_new_rounded),
                      onTap: () async {
                        final uri =
                            Uri.tryParse('${video['youtubeUrl'] ?? ''}');
                        if (uri == null ||
                            !await launchUrl(uri,
                                mode: LaunchMode.inAppBrowserView)) {
                          if (context.mounted) {
                            _snack(context, 'Could not open this help video',
                                error: true);
                          }
                        }
                      },
                    ))),
                if (_sending && messages.isEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Private admin support',
                      style: Theme.of(context).textTheme.titleLarge),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(children: [
                        if (messages.isEmpty)
                          const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text('Send your first support message.')),
                        ...messages.map((item) {
                          final mine = item['senderRole'] != 'admin';
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 330),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                  color: mine
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(14)),
                              child: Text('${item['text'] ?? ''}'),
                            ),
                          );
                        }),
                        const Divider(),
                        Row(children: [
                          Expanded(
                              child: TextField(
                                  controller: _message,
                                  minLines: 1,
                                  maxLines: 4,
                                  decoration: const InputDecoration(
                                      hintText: 'Message the administrator'))),
                          IconButton(
                              onPressed: _sending ? null : _send,
                              icon: _sending
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.send_rounded)),
                        ]),
                      ]),
                    ),
                  ),
                ],
              ],
            ),
            Positioned(
                top: 18,
                right: 18,
                child: FloatingActionButton.small(
                    heroTag: 'teacher-admin-chat',
                    tooltip: 'Private administrator chat',
                    onPressed: () => _openAdminChat(messages),
                    child: const Icon(Icons.chat_bubble_outline_rounded)))
          ]);
        },
      );
}
