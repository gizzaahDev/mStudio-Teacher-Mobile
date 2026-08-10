part of '../teacher_pages.dart';

class _MessagesPage extends StatefulWidget {
  const _MessagesPage({required this.session});
  final SessionController session;

  @override
  State<_MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<_MessagesPage> {
  List<Map<String, dynamic>> conversations = [];
  bool loading = true;
  String? error;
  final search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
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
      conversations = _list(
          _map(await widget.session.repository.messages())['conversations']);
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = search.text.trim().toLowerCase();
    final filtered = conversations
        .where((item) =>
            ('${item['studentName'] ?? ''} ${item['studentId'] ?? ''} ${item['phone'] ?? ''}')
                .toLowerCase()
                .contains(query))
        .toList();
    return _PageFrame(
      title: 'Messages',
      subtitle: 'Private chats with your approved students.',
      loading: loading,
      error: error,
      onRefresh: () => _load(refresh: true),
      children: [
        TextField(
            controller: search,
            decoration: _input('Search student name, ID, or phone')
                .copyWith(prefixIcon: const Icon(Icons.search)),
            onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        if (filtered.isEmpty && !loading)
          const _Message('No conversations are available yet.'),
        ...filtered.map((item) => Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: CircleAvatar(
                    backgroundImage: '${item['profileImageUrl'] ?? ''}'.isEmpty
                        ? null
                        : NetworkImage('${item['profileImageUrl']}'),
                    child: '${item['profileImageUrl'] ?? ''}'.isEmpty
                        ? Text(_initials('${item['studentName'] ?? 'Student'}'))
                        : null),
                title: Text('${item['studentName'] ?? 'Student'}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    '${item['lastMessage'] ?? item['lastMessageType'] ?? 'Start a conversation'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_chatTime('${item['lastMessageAt'] ?? ''}'),
                          style: Theme.of(context).textTheme.labelSmall),
                      const Icon(Icons.chevron_right)
                    ]),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => _TeacherChatPage(
                          session: widget.session,
                          conversation: item,
                          conversations: conversations)));
                  if (mounted) await _load();
                },
              ),
            )),
      ],
    );
  }
}

class _TeacherChatPage extends StatefulWidget {
  const _TeacherChatPage(
      {required this.session,
      required this.conversation,
      required this.conversations});
  final SessionController session;
  final Map<String, dynamic> conversation;
  final List<Map<String, dynamic>> conversations;

  @override
  State<_TeacherChatPage> createState() => _TeacherChatPageState();
}

class _TeacherChatPageState extends State<_TeacherChatPage> {
  final composer = TextEditingController();
  final scroll = ScrollController();
  static const _audioChannel =
      MethodChannel('magical_lms_teacher/audio_recorder');
  final AudioPlayer audioPreview = AudioPlayer();
  final List<PlatformFile> attachments = [];
  List<Map<String, dynamic>> outbox = [];
  Timer? retryTimer;
  bool flushing = false;
  List<Map<String, dynamic>> messages = [];
  Map<String, dynamic>? replyTo;
  Map<String, dynamic>? editing;
  bool loading = true;
  bool sending = false;
  bool recording = false;
  bool notice = false;
  String noticeColor = 'yellow';
  String? error;

  String get studentUid => '${widget.conversation['studentUid']}';
  String get studentName =>
      '${widget.conversation['studentName'] ?? 'Student'}';
  String get currentUid => widget.session.user?.uid ?? '';
  String get outboxKey => 'magical-teacher-chat-outbox:$currentUid:$studentUid';

  @override
  void initState() {
    super.initState();
    _hydrate();
    retryTimer = Timer.periodic(
        const Duration(seconds: 20), (_) => unawaited(_flushOutbox()));
  }

  @override
  void dispose() {
    composer.dispose();
    scroll.dispose();
    if (recording) _audioChannel.invokeMethod<void>('stop');
    retryTimer?.cancel();
    unawaited(audioPreview.dispose());
    super.dispose();
  }

  Future<void> _hydrate() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(outboxKey);
    if (raw != null) {
      try {
        outbox = (jsonDecode(raw) as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      } catch (_) {}
    }
    await _load();
    unawaited(_flushOutbox());
  }

  Future<void> _saveOutbox() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(outboxKey, jsonEncode(outbox));
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
      final server = _list(
          _map(await widget.session.repository.conversation(studentUid))[
              'messages']);
      final pendingIds = outbox.map((item) => '${item['localId']}').toSet();
      final pending = messages
          .where((item) => pendingIds.contains('${item['id']}'))
          .toList();
      messages = [...server, ...pending]
        ..sort((a, b) => '${a['createdAt']}'.compareTo('${b['createdAt']}'));
      WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _toBottom() {
    if (scroll.hasClients) {
      scroll.animateTo(scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    }
  }

  Future<void> _send() async {
    final value = composer.text.trim();
    if (editing != null) {
      if (value.isEmpty) return;
      setState(() => sending = true);
      try {
        await widget.session.repository
            .editMessage(studentUid, '${editing!['id']}', value);
        composer.clear();
        editing = null;
        await _load();
      } catch (e) {
        if (mounted) _snack(context, '$e', error: true);
      } finally {
        if (mounted) setState(() => sending = false);
      }
      return;
    }
    if (value.isEmpty && attachments.isEmpty) return;
    final selected = List<PlatformFile>.from(attachments);
    final reply = replyTo == null ? null : Map<String, dynamic>.from(replyTo!);
    final wasNotice = notice;
    composer.clear();
    setState(() {
      attachments.clear();
      replyTo = null;
      notice = false;
    });
    try {
      final jobs = <Map<String, dynamic>>[];
      if (selected.isEmpty) {
        jobs.add(await _createOutboxJob(
            text: value, reply: reply, noticeMessage: wasNotice));
      } else {
        for (var index = 0; index < selected.length; index++) {
          jobs.add(await _createOutboxJob(
              text: index == 0 ? value : '',
              file: selected[index],
              reply: index == 0 ? reply : null));
        }
      }
      outbox.addAll(jobs);
      messages.addAll(jobs.map(_localMessage));
      messages.sort((a, b) => '${a['createdAt']}'.compareTo('${b['createdAt']}'));
      await _saveOutbox();
      if (mounted) setState(() {});
      _toBottom();
      unawaited(_flushOutbox());
    } catch (e) {
      if (mounted) _snack(context, '$e', error: true);
    }
  }

  Future<void> _attach() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;
    setState(() => attachments.addAll(
        result.files.where((file) => file.path != null && file.size > 0)));
  }

  Future<void> _toggleRecording() async {
    if (recording) {
      final recordedPath = await _audioChannel.invokeMethod<String>('stop');
      if (mounted) setState(() => recording = false);
      if (recordedPath != null) {
        final file = File(recordedPath);
        setState(() => attachments.add(PlatformFile(
            name: recordedPath.split(Platform.pathSeparator).last,
            path: recordedPath,
            size: file.lengthSync())));
      }
      return;
    }
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      if (mounted) {
        _snack(context, 'Microphone permission is required', error: true);
      }
      return;
    }
    try {
      await _audioChannel.invokeMethod<String>('start');
      if (mounted) setState(() => recording = true);
    } catch (e) {
      if (mounted) {
        _snack(context, 'Could not start recording: $e', error: true);
      }
    }
  }

  String _fileType(PlatformFile file) {
    final extension = (file.extension ?? file.name.split('.').last).toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) return 'image';
    if (['mp3', 'wav', 'm4a', 'aac', 'ogg'].contains(extension)) return 'audio';
    if (['mp4', 'mov', 'mkv', 'webm'].contains(extension)) return 'video';
    return 'file';
  }

  String _contentType(PlatformFile file) {
    final extension = (file.extension ?? file.name.split('.').last).toLowerCase();
    return const {
          'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
          'webp': 'image/webp', 'mp3': 'audio/mpeg', 'm4a': 'audio/mp4',
          'aac': 'audio/aac', 'ogg': 'audio/ogg', 'mp4': 'video/mp4',
          'pdf': 'application/pdf',
        }[extension] ??
        'application/octet-stream';
  }

  Future<File> _prepareOutboxFile(PlatformFile selected) async {
    final source = File(selected.path!);
    final directory = Directory(
        '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}teacher_chat_outbox');
    await directory.create(recursive: true);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final copied = File('${directory.path}${Platform.pathSeparator}$stamp-${selected.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '-')}');
    await source.copy(copied.path);
    if (selected.size <= 5 * 1024 * 1024) return copied;
    if (_fileType(selected) == 'image') {
      final target = File('${directory.path}${Platform.pathSeparator}$stamp-compressed.jpg');
      final compressed = await FlutterImageCompress.compressAndGetFile(
          copied.path, target.path,
          quality: 76, minWidth: 1920, minHeight: 1920);
      if (compressed != null) {
        await copied.delete().catchError((_) => copied);
        return File(compressed.path);
      }
    }
    if (_fileType(selected) == 'video') {
      final compressed = await VideoCompress.compressVideo(copied.path,
          quality: VideoQuality.Res1280x720Quality,
          deleteOrigin: false,
          includeAudio: true);
      if (compressed?.path != null) {
        final target = File('${directory.path}${Platform.pathSeparator}$stamp-compressed.mp4');
        await File(compressed!.path!).copy(target.path);
        await VideoCompress.deleteAllCache();
        await copied.delete().catchError((_) => copied);
        return target;
      }
    }
    return copied;
  }

  Future<Map<String, dynamic>> _createOutboxJob({
    required String text,
    PlatformFile? file,
    Map<String, dynamic>? reply,
    bool noticeMessage = false,
  }) async {
    final prepared = file == null ? null : await _prepareOutboxFile(file);
    return {
      'localId': 'local-${DateTime.now().microsecondsSinceEpoch}',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'text': text,
      'type': file == null ? (noticeMessage ? 'notice' : 'text') : _fileType(file),
      if (noticeMessage) 'noticeColor': noticeColor,
      if (prepared != null) 'path': prepared.path,
      if (file != null) 'fileName': file.name,
      if (file != null)
        'contentType': prepared?.path.endsWith('.jpg') == true
            ? 'image/jpeg'
            : prepared?.path.endsWith('.mp4') == true
                ? 'video/mp4'
                : _contentType(file),
      if (reply != null) ...{
        'replyToId': reply['id'], 'replyText': reply['text'],
        'replyType': reply['type'], 'replyFileName': reply['fileName'],
      },
    };
  }

  Map<String, dynamic> _localMessage(Map<String, dynamic> job) => {
        'id': job['localId'], 'text': job['text'], 'type': job['type'],
        'fileUrl': job['path'], 'fileName': job['fileName'],
        'contentType': job['contentType'], 'noticeColor': job['noticeColor'],
        'senderUid': currentUid, 'senderRole': 'teacher',
        'senderName': widget.session.profile?['displayName'] ?? 'Teacher',
        'createdAt': job['createdAt'], 'replyToId': job['replyToId'],
        'replyText': job['replyText'], 'replyType': job['replyType'],
        'replyFileName': job['replyFileName'], 'pending': true,
      };

  Future<void> _flushOutbox() async {
    if (flushing || outbox.isEmpty) return;
    flushing = true;
    try {
      while (outbox.isNotEmpty) {
        final job = outbox.first;
        try {
          final payload = <String, dynamic>{
            'type': job['type'],
            if ('${job['text'] ?? ''}'.isNotEmpty) 'text': job['text'],
            for (final key in ['noticeColor', 'replyToId', 'replyText', 'replyType', 'replyFileName'])
              if (job[key] != null) key: job[key],
          };
          final path = '${job['path'] ?? ''}';
          if (path.isNotEmpty) {
            final upload = await widget.session.repository.uploadFile(File(path));
            final raw = '${upload['url'] ?? ''}';
            payload.addAll({
              'fileUrl': raw.startsWith('http') ? raw : '${AppConfig.apiBaseUrl}${raw.startsWith('/') ? raw : '/$raw'}',
              'fileName': job['fileName'], 'contentType': job['contentType'],
            });
          }
          await widget.session.repository.sendMessage(studentUid, payload);
          outbox.removeAt(0);
          messages.removeWhere((item) => item['id'] == job['localId']);
          await _saveOutbox();
          if (path.isNotEmpty) await File(path).delete().catchError((_) => File(path));
        } catch (_) { break; }
      }
      if (outbox.isEmpty) await _load();
      if (mounted) setState(() {});
    } finally { flushing = false; }
  }

  Future<void> _delete(Map<String, dynamic> message) async {
    if (!await _confirm(context, 'Delete this message?')) return;
    try {
      await widget.session.repository
          .deleteMessage(studentUid, '${message['id']}');
      await _load();
    } catch (e) {
      if (mounted) _snack(context, '$e', error: true);
    }
  }

  Future<void> _forward(Map<String, dynamic> message) async {
    String? target;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: const Text('Forward message'),
                  content: DropdownButtonFormField<String>(
                    decoration: _input('Student'),
                    initialValue: target,
                    items: widget.conversations
                        .where((item) => '${item['studentUid']}' != studentUid)
                        .map((item) => DropdownMenuItem(
                            value: '${item['studentUid']}',
                            child: Text('${item['studentName'] ?? 'Student'}')))
                        .toList(),
                    onChanged: (value) => setDialogState(() => target = value),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: target == null
                            ? null
                            : () => Navigator.pop(context, true),
                        child: const Text('Forward'))
                  ],
                )));
    if (confirmed != true || target == null) return;
    try {
      await widget.session.repository.sendMessage(target!, {
        'type': message['type'] ?? 'text',
        'text': message['text'] ?? '',
        'fileUrl': message['fileUrl'],
        'fileName': message['fileName'],
        'contentType': message['contentType'],
        'noticeColor': message['noticeColor'],
      });
      if (mounted) _snack(context, 'Message forwarded');
    } catch (e) {
      if (mounted) _snack(context, '$e', error: true);
    }
  }

  void _action(String value, Map<String, dynamic> message) {
    if (value == 'reply') {
      setState(() {
        replyTo = message;
        editing = null;
      });
    }
    if (value == 'forward') _forward(message);
    if (value == 'edit') {
      setState(() {
        editing = message;
        replyTo = null;
        composer.text = '${message['text'] ?? ''}';
      });
    }
    if (value == 'delete') _delete(message);
  }

  Widget _attachmentPreview() => SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: attachments.length,
          separatorBuilder: (_, __) => const SizedBox(width: 7),
          itemBuilder: (context, index) {
            final file = attachments[index];
            final type = _fileType(file);
            return Container(
              width: 108,
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant)),
              child: Stack(children: [
                Positioned.fill(
                  child: type == 'image' && file.path != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.file(File(file.path!), fit: BoxFit.cover))
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(type == 'audio'
                              ? Icons.audio_file
                              : type == 'video'
                                  ? Icons.video_file
                                  : Icons.insert_drive_file),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Text(file.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 10)),
                          ),
                        ]),
                ),
                if (type == 'audio' && file.path != null)
                  Positioned(
                      left: 2,
                      top: 2,
                      child: IconButton.filledTonal(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => audioPreview
                              .play(DeviceFileSource(file.path!)),
                          icon: const Icon(Icons.play_arrow, size: 18))),
                Positioned(
                    right: 2,
                    top: 2,
                    child: IconButton.filled(
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            setState(() => attachments.removeAt(index)),
                        icon: const Icon(Icons.close, size: 16))),
              ]),
            );
          },
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: '${widget.conversation['profileImageUrl'] ?? ''}'
                      .isEmpty
                  ? null
                  : NetworkImage('${widget.conversation['profileImageUrl']}'),
              child: '${widget.conversation['profileImageUrl'] ?? ''}'.isEmpty
                  ? Text(_initials(studentName))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(studentName, style: const TextStyle(fontSize: 16)),
                  Text('${widget.conversation['studentId'] ?? 'Student'}',
                      style: Theme.of(context).textTheme.labelSmall)
                ]))
          ]),
          actions: [
            IconButton(
                onPressed: () => _load(refresh: true),
                icon: const Icon(Icons.refresh))
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xff0b141a)
                  : const Color(0xffefeae2)),
          child: Column(children: [
            if (error != null) _Message(error!, error: true),
            Expanded(
                child: loading && messages.isEmpty
                    ? const _DelayedLoading(loading: true)
                    : RefreshIndicator(
                        onRefresh: () => _load(refresh: true),
                        child: ListView.builder(
                          controller: scroll,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 14),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final mine =
                                '${message['senderUid']}' == currentUid;
                            return _ChatBubble(
                                message: message,
                                mine: mine,
                                onAction: (value) => _action(value, message));
                          },
                        ),
                      )),
            if (replyTo != null || editing != null)
              Container(
                color: Theme.of(context).colorScheme.surface,
                padding: const EdgeInsets.fromLTRB(14, 8, 6, 4),
                child: Row(children: [
                  Container(
                      width: 4,
                      height: 42,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            editing != null
                                ? 'Editing message'
                                : 'Replying to ${replyTo!['senderName'] ?? 'message'}',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold)),
                        Text(
                            '${(editing ?? replyTo)!['text'] ?? (editing ?? replyTo)!['fileName'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)
                      ])),
                  IconButton(
                      onPressed: () => setState(() {
                            replyTo = null;
                            editing = null;
                            if (composer.text.isNotEmpty) composer.clear();
                          }),
                      icon: const Icon(Icons.close))
                ]),
              ),
            SafeArea(
                top: false,
                child: Container(
                  color: Theme.of(context).colorScheme.surface,
                  padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
                  child: Column(children: [
                    if (notice)
                      Row(children: [
                        const Text('Private notice:'),
                        const SizedBox(width: 8),
                        ...['yellow', 'green', 'orange', 'red'].map((value) =>
                            Padding(
                                padding: const EdgeInsets.only(right: 5),
                                child: ChoiceChip(
                                    label: Text(value),
                                    selected: noticeColor == value,
                                    onSelected: (_) =>
                                        setState(() => noticeColor = value))))
                      ]),
                    if (attachments.isNotEmpty) _attachmentPreview(),
                    Row(children: [
                      IconButton(
                          onPressed: sending || recording ? null : _attach,
                          icon: const Icon(Icons.attach_file),
                          tooltip: 'Attach file'),
                      IconButton(
                          onPressed: sending ? null : _toggleRecording,
                          icon: Icon(recording ? Icons.stop_circle : Icons.mic,
                              color: recording ? Colors.red : null),
                          tooltip: recording
                              ? 'Stop recording'
                              : 'Record voice message'),
                      IconButton(
                          onPressed: () => setState(() => notice = !notice),
                          icon: Icon(Icons.campaign_outlined,
                              color: notice
                                  ? Theme.of(context).colorScheme.primary
                                  : null),
                          tooltip: 'Private notice'),
                      Expanded(
                          child: TextField(
                              controller: composer,
                              minLines: 1,
                              maxLines: 5,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: _input(editing != null
                                      ? 'Edit message'
                                      : 'Message')
                                  .copyWith(
                                      fillColor: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      filled: true),
                              onSubmitted: (_) => _send())),
                      const SizedBox(width: 5),
                      CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: IconButton(
                              onPressed: sending ? null : _send,
                              icon: sending
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.send),
                              color: Theme.of(context).colorScheme.onPrimary)),
                    ]),
                  ]),
                )),
          ]),
        ),
      );
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble(
      {required this.message, required this.mine, required this.onAction});
  final Map<String, dynamic> message;
  final bool mine;
  final ValueChanged<String> onAction;

  Color? _noticeColour() => switch ('${message['noticeColor']}') {
        'red' => const Color(0xffffe0e0),
        'green' => const Color(0xffdcfce7),
        'orange' => const Color(0xffffedd5),
        _ => const Color(0xfffef9c3)
      };

  @override
  Widget build(BuildContext context) {
    final type = '${message['type'] ?? 'text'}';
    final canEdit = mine && (type == 'text' || type == 'notice');
    final hasFile = '${message['fileUrl'] ?? ''}'.isNotEmpty;
    final pending = message['pending'] == true;
    final background = type == 'notice'
        ? _noticeColour()
        : mine
            ? (Theme.of(context).brightness == Brightness.dark
                ? const Color(0xff005c4b)
                : const Color(0xffd9fdd3))
            : Theme.of(context).colorScheme.surface;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .82),
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.fromLTRB(11, 7, 4, 5),
        decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(13),
                topRight: const Radius.circular(13),
                bottomLeft: Radius.circular(mine ? 13 : 3),
                bottomRight: Radius.circular(mine ? 3 : 13))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (type == 'notice')
            const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.campaign, size: 16),
              SizedBox(width: 5),
              Text('PRIVATE NOTICE',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87))
            ]),
          if ('${message['replyToId'] ?? ''}'.isNotEmpty)
            Container(
                margin: const EdgeInsets.only(top: 4, right: 7, bottom: 5),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(7)),
                child: Text(
                    '${message['replyText'] ?? message['replyFileName'] ?? 'Attachment'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis)),
          if (hasFile && type == 'image')
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 7, bottom: 5),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: pending && File('${message['fileUrl']}').existsSync()
                    ? Image.file(File('${message['fileUrl']}'),
                        height: 180, width: 240, fit: BoxFit.cover)
                    : Image.network('${message['fileUrl']}',
                        height: 180, width: 240, fit: BoxFit.cover),
              ),
            ),
          if (hasFile)
            InkWell(
              onTap: pending
                  ? null
                  : () => launchUrl(Uri.parse('${message['fileUrl']}'),
                      mode: LaunchMode.externalApplication),
              child: Container(
                  margin: const EdgeInsets.only(top: 4, right: 7, bottom: 5),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(9)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(type == 'image'
                        ? Icons.image
                        : type == 'audio'
                            ? Icons.audio_file
                            : type == 'video'
                                ? Icons.video_file
                                : Icons.insert_drive_file),
                    const SizedBox(width: 8),
                    Flexible(
                        child: Text(
                            '${message['fileName'] ?? 'Open attachment'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis)),
                    const Icon(Icons.open_in_new, size: 16)
                  ])),
            ),
          if ('${message['text'] ?? ''}'.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text('${message['text']}',
                    style: TextStyle(
                        color: type == 'notice' ? Colors.black87 : null))),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (pending) ...[
              const Icon(Icons.schedule, size: 13),
              const SizedBox(width: 3),
            ],
            Text(_chatTime('${message['createdAt'] ?? ''}'),
                style: TextStyle(
                    fontSize: 10,
                    color: type == 'notice'
                        ? Colors.black54
                        : Theme.of(context).textTheme.bodySmall?.color)),
            PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 18,
                onSelected: onAction,
                itemBuilder: (_) => [
                      const PopupMenuItem(value: 'reply', child: Text('Reply')),
                      const PopupMenuItem(
                          value: 'forward', child: Text('Forward')),
                      if (canEdit)
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (mine)
                        const PopupMenuItem(
                            value: 'delete', child: Text('Delete'))
                    ]),
          ]),
        ]),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((item) => item.isNotEmpty)
      .toList();
  return parts.take(2).map((item) => item[0].toUpperCase()).join();
}

String _chatTime(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return '';
  final now = DateTime.now();
  return DateUtils.isSameDay(date, now)
      ? DateFormat('h:mm a').format(date)
      : DateFormat('MMM d').format(date);
}
