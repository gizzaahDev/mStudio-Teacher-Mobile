part of 'teacher_pages.dart';

class _ProfilePage extends StatefulWidget {
  const _ProfilePage({required this.session, required this.onNavigate});
  final SessionController session;
  final ValueChanged<TeacherPage> onNavigate;
  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  bool saving = false;
  Future<void> requestPrimaryChange() async {
    final profile = widget.session.profile ?? {};
    final name = TextEditingController(text: '${profile['displayName'] ?? ''}');
    final phone = TextEditingController(text: '${profile['phone'] ?? ''}');
    final email = TextEditingController(text: '${profile['email'] ?? ''}');
    final reason = TextEditingController();
    final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Request primary-detail change'),
              content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: name,
                    decoration: const InputDecoration(
                        labelText: 'Requested teacher name')),
                TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration:
                        const InputDecoration(labelText: 'Requested phone')),
                TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration:
                        const InputDecoration(labelText: 'Requested Gmail')),
                TextField(
                    controller: reason,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Reason (optional)')),
              ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Send to admin'))
              ],
            ));
    if (approved != true || !mounted) return;
    setState(() => saving = true);
    try {
      await widget.session.repository.requestPrimaryProfileChange({
        'displayName': name.text.trim(),
        'phone': phone.text.trim(),
        'email': email.text.trim(),
        'reason': reason.text.trim()
      });
      if (mounted) _snack(context, 'Change request sent to the administrator.');
    } catch (error) {
      if (mounted) _snack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> edit() async {
    final data = await _showForm(context,
        title: 'Edit teacher profile',
        initial: widget.session.profile ?? {},
        fields: [
          const _Field('displayName', 'Registered teacher name',
              kind: _FieldKind.readOnly),
          const _Field('headline', 'Teacher slogan'),
          const _Field('about', 'About', lines: 6),
          const _Field('phone', 'Registered phone', kind: _FieldKind.readOnly),
          const _Field('whatsappNumber', 'WhatsApp number'),
          const _Field('email', 'Registered Gmail', kind: _FieldKind.readOnly),
          const _Field('phones', 'Other phones', kind: _FieldKind.csv),
          const _Field('emails', 'Other emails', kind: _FieldKind.csv),
        ]);
    if (data == null || !mounted) return;
    data['instituteIds'] = _strings(widget.session.profile?['instituteIds']);
    data['grades'] = _strings(widget.session.profile?['grades']);
    data['subjects'] = _strings(widget.session.profile?['subjects']);
    data['classTypes'] = _strings(widget.session.profile?['classTypes']);
    data['resultCategories'] =
        _strings(widget.session.profile?['resultCategories']);
    data['subjectGrades'] = _map(widget.session.profile?['subjectGrades']);
    data['subjectClassTypes'] =
        _map(widget.session.profile?['subjectClassTypes']);
    data['subjectResultCategories'] =
        _map(widget.session.profile?['subjectResultCategories']);
    data['subjectGradeIdPrefixes'] =
        _map(widget.session.profile?['subjectGradeIdPrefixes']);
    data['showPhoneToStudents'] =
        widget.session.profile?['showPhoneToStudents'] == true;
    data['showWhatsappToStudents'] =
        widget.session.profile?['showWhatsappToStudents'] == true;
    data['showEmailToStudents'] =
        widget.session.profile?['showEmailToStudents'] == true;
    data['showOtherPhonesToStudents'] =
        widget.session.profile?['showOtherPhonesToStudents'] == true;
    data['showOtherEmailsToStudents'] =
        widget.session.profile?['showOtherEmailsToStudents'] == true;
    File? selectedPhoto;
    final photoAction = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(
            title: Text('Profile image',
                style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('Choose an image from this device or remove it.'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose image'),
            onTap: () async {
              final picked = await FilePicker.platform.pickFiles(
                type: FileType.image,
                allowMultiple: false,
              );
              final path = picked?.files.single.path;
              if (path != null) selectedPhoto = File(path);
              if (sheetContext.mounted) {
                Navigator.pop(sheetContext, path == null ? null : 'choose');
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Remove current image'),
            onTap: () => Navigator.pop(sheetContext, 'remove'),
          ),
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: const Text('Keep current image'),
            onTap: () => Navigator.pop(sheetContext, 'keep'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!mounted) return;
    final resolvedPhotoAction = photoAction ?? 'keep';
    setState(() => saving = true);
    try {
      if (resolvedPhotoAction == 'remove') {
        data['imageUrl'] = '';
      } else if (selectedPhoto != null) {
        final uploaded =
            await widget.session.repository.uploadFile(selectedPhoto!);
        final uploadedUrl = '${uploaded['url'] ?? ''}';
        data['imageUrl'] = uploadedUrl.startsWith('http')
            ? uploadedUrl
            : '${AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}/${uploadedUrl.replaceFirst(RegExp(r'^/+'), '')}';
      } else {
        data['imageUrl'] = widget.session.profile?['imageUrl'] ?? '';
      }
      await widget.session.repository.saveTeacherContacts({
        'whatsappNumber': data['whatsappNumber'] ?? '',
        'phones': data['phones'] ?? <String>[],
        'emails': data['emails'] ?? <String>[],
      });
      await widget.session.repository.saveProfile(data);
      await widget.session.refreshProfile();
      widget.session.markContentChanged();
      if (mounted) {
        _snack(context, 'Profile saved. Continue with ST Manage.');
        widget.onNavigate(TeacherPage.stManage);
      }
    } catch (error) {
      if (mounted) _snack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.session.profile ?? {};
    final imageUrl = '${profile['imageUrl'] ?? ''}';
    return _PageFrame(
        title: 'My profile',
        subtitle: 'Public identity and teaching details.',
        actions: [
          IconButton(
              onPressed: saving ? null : edit, icon: const Icon(Icons.edit))
        ],
        children: [
          CircleAvatar(
              radius: 48,
              child: imageUrl.isEmpty
                  ? const Icon(Icons.person, size: 48)
                  : Padding(
                      padding: const EdgeInsets.all(5),
                      child: ClipOval(
                        child: Image.network(
                          imageUrl,
                          width: 86,
                          height: 86,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.person, size: 44),
                        ),
                      ),
                    )),
          _Detail('Name', profile['displayName']),
          _Detail('Teacher ID',
              profile['teacherPublicId'] ?? profile['teacherCode']),
          _Detail('Teacher slogan', profile['headline']),
          _Detail('Email', profile['email']),
          _Detail('Phone', profile['phone']),
          _Detail('WhatsApp', profile['whatsappNumber']),
          _Detail('About', profile['about']),
          _Detail('Grades', _strings(profile['grades']).join(', ')),
          FilledButton.icon(
              onPressed: saving ? null : edit,
              icon: const Icon(Icons.edit),
              label: const Text('Edit profile')),
          OutlinedButton.icon(
              onPressed: saving ? null : requestPrimaryChange,
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Request name, phone or Gmail change')),
        ]);
  }
}

class _AboutPage extends StatelessWidget {
  const _AboutPage({required this.session});
  final SessionController session;

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
        future: session.repository.appSettings(),
        builder: (context, snapshot) {
          final settings = _map(_map(snapshot.data)['settings']);
          final about = _map(settings['about']);
          return _PageFrame(
            title: 'About',
            subtitle: 'Application and developer information.',
            loading: snapshot.connectionState == ConnectionState.waiting,
            error: snapshot.error,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('m.teacher',
                            style: Theme.of(context).textTheme.headlineSmall),
                        Text(
                            'APK version ${about['teacherApkVersion'] ?? '1.0.0 (1)'}'),
                        const Divider(height: 28),
                        Text(
                            '${about['thankYouMessage'] ?? 'Thank you for teaching with us.'}'),
                        const SizedBox(height: 18),
                        Text('Developer',
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                            '${about['developerName'] ?? 'Magical LMS Development Team'}'),
                        if ('${about['developerContact'] ?? ''}'.isNotEmpty)
                          Text('${about['developerContact']}'),
                        if ('${about['developerWebsite'] ?? ''}'.isNotEmpty)
                          Text('${about['developerWebsite']}'),
                      ]),
                ),
              ),
            ],
          );
        },
      );
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({required this.session});
  final SessionController session;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  late final TextEditingController _slugController = TextEditingController(
      text: '${widget.session.profile?['publicSlug'] ?? ''}');
  Timer? _debounce;
  Map<String, dynamic>? _availability;
  bool _checking = false;
  bool _saving = false;
  Map<String, dynamic>? _notificationPreferences;
  bool _savingNotifications = false;
  String? _notificationError;

  static const _defaultNotificationPreferences = <String, dynamic>{
    'enabled': true,
    'messages': true,
    'assignments': true,
    'curriculum': true,
    'notices': true,
    'classes': true,
    'reminders': true,
    'payments': true,
    'account': true,
    'system': true,
    'soundEnabled': true,
  };

  String _clean(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'[^a-z0-9-]'), '')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  String get _teacherId =>
      '${widget.session.profile?['teacherPublicId'] ?? widget.session.profile?['teacherCode'] ?? 'ID pending'}';
  String get _publicUrl =>
      '${AppConfig.teacherWebUrl.replaceAll(RegExp(r'/+$'), '')}/t/${_clean(_slugController.text)}';

  @override
  void initState() {
    super.initState();
    if (_slugController.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
    _loadNotificationPreferences();
  }

  Future<void> _loadNotificationPreferences() async {
    try {
      final response =
          await widget.session.repository.notificationPreferences();
      if (mounted) {
        final loaded = _map(_map(response)['preferences']);
        setState(() {
          _notificationPreferences = {
            ..._defaultNotificationPreferences,
            ...loaded,
          };
          _notificationError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _notificationPreferences =
              Map<String, dynamic>.from(_defaultNotificationPreferences);
          _notificationError = '$error';
        });
      }
    }
  }

  Future<void> _setNotification(String key, bool value) async {
    final current = _notificationPreferences;
    if (current == null || _savingNotifications) return;
    final previous = current[key];
    setState(() {
      current[key] = value;
      _savingNotifications = true;
    });
    try {
      final response =
          await widget.session.repository.saveNotificationPreferences(current);
      if (mounted) {
        setState(() =>
            _notificationPreferences = _map(_map(response)['preferences']));
      }
    } catch (error) {
      current[key] = previous;
      if (mounted) _snack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _savingNotifications = false);
    }
  }

  Future<void> _openNotificationDrawer() async {
    if (_notificationPreferences == null) {
      await _loadNotificationPreferences();
    }
    if (!mounted || _notificationPreferences == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setDrawerState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .82,
          minChildSize: .48,
          maxChildSize: .96,
          builder: (context, scrollController) => Column(children: [
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Teacher notification settings'),
              subtitle: const Text(
                  'Choose each notification type for the teacher app.'),
              trailing: IconButton(
                onPressed: () => Navigator.pop(sheetContext),
                icon: const Icon(Icons.close),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  if (_notificationError != null)
                    ListTile(
                      leading: const Icon(Icons.cloud_off_outlined),
                      title: const Text('Using saved default controls'),
                      subtitle: const Text(
                          'The server is reconnecting. This does not affect other settings.'),
                      trailing: IconButton(
                        onPressed: () async {
                          await _loadNotificationPreferences();
                          if (sheetContext.mounted) setDrawerState(() {});
                        },
                        icon: const Icon(Icons.refresh),
                      ),
                    ),
                  for (final entry in const {
                    'enabled': 'All teacher app notifications',
                    'messages': 'Messages',
                    'assignments': 'Assignments and quizzes',
                    'curriculum': 'Curriculum and learning space',
                    'notices': 'Quotes and notices',
                    'classes': 'Class starts and schedule changes',
                    'reminders': 'Calendar reminders',
                    'payments': 'Fees and subscriptions',
                    'account': 'Approvals and account activity',
                    'system': 'System announcements',
                    'soundEnabled': 'Notification sounds',
                  }.entries)
                    SwitchListTile.adaptive(
                      title: Text(entry.value),
                      value: _notificationPreferences![entry.key] != false,
                      onChanged: _savingNotifications
                          ? null
                          : (value) async {
                              await _setNotification(entry.key, value);
                              if (sheetContext.mounted) {
                                setDrawerState(() {});
                              }
                            },
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _slugController.dispose();
    super.dispose();
  }

  void _changed(String _) {
    _debounce?.cancel();
    setState(() => _availability = null);
    _debounce = Timer(const Duration(milliseconds: 450), _check);
  }

  Future<void> _check() async {
    final slug = _clean(_slugController.text);
    if (slug.length < 3) {
      if (mounted) {
        setState(() => _availability = {
              'slug': slug,
              'available': false,
              'reason': 'Use at least 3 letters or numbers.'
            });
      }
      return;
    }
    setState(() => _checking = true);
    try {
      final value =
          await widget.session.repository.teacherUrlAvailability(slug);
      if (mounted) setState(() => _availability = _map(value));
    } catch (error) {
      if (mounted) {
        setState(() => _availability = {
              'slug': slug,
              'available': false,
              'reason': '$error'
            });
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _save() async {
    final slug = _clean(_slugController.text);
    if (_availability?['available'] != true || _availability?['slug'] != slug) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.session.repository.saveTeacherUrl(slug);
      await widget.session.refreshProfile(forceNetwork: true);
      _slugController.text = '${widget.session.profile?['publicSlug'] ?? slug}';
      if (mounted) _snack(context, 'Teacher URL saved');
    } catch (error) {
      if (mounted) _snack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copy(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _snack(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final available = _availability?['available'] == true;
    final current = _availability?['isCurrent'] == true;
    final normalized = _clean(_slugController.text);
    return _PageFrame(
      title: 'Teacher settings',
      subtitle: 'Your teacher identity, shareable URL, and device controls.',
      children: [
        Card(
          key: const ValueKey('teacher-notification-settings'),
          child: ListTile(
            onTap: _openNotificationDrawer,
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Teacher notifications'),
            subtitle: const Text(
                'Minimized by default. Tap to manage every alert type.'),
            trailing: _notificationPreferences == null
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_right_rounded),
          ),
        ),
        Card(
          color: colors.primaryContainer.withValues(alpha: .28),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.link_rounded, color: colors.primary),
                  const SizedBox(width: 10),
                  Text('Custom teacher URL',
                      style: Theme.of(context).textTheme.titleMedium),
                ]),
                const SizedBox(height: 6),
                Text(
                    'Choose a unique address. Availability updates as you type.',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                TextField(
                  controller: _slugController,
                  onChanged: _changed,
                  autocorrect: false,
                  enableSuggestions: false,
                  maxLength: 40,
                  decoration: InputDecoration(
                    labelText: 'Teacher URL name',
                    prefixText: '/t/',
                    suffixIcon: _checking
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : _availability == null
                            ? null
                            : Icon(
                                available
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                color: available ? Colors.green : colors.error),
                  ),
                ),
                if (_availability != null)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(
                        available
                            ? Icons.check_circle_rounded
                            : Icons.info_outline_rounded,
                        size: 18,
                        color: available ? Colors.green : colors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        available
                            ? (current
                                ? 'This is your current URL.'
                                : 'This name is available.')
                            : '${_availability?['reason'] ?? 'This name cannot be used.'}',
                        style: TextStyle(
                            color: available ? Colors.green : colors.error,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ]),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ||
                            _checking ||
                            !available ||
                            _availability?['slug'] != normalized
                        ? null
                        : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving...' : 'Save teacher URL'),
                  ),
                ),
                if (available) ...[
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_publicUrl,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    leading: const Icon(Icons.public_rounded),
                    trailing: IconButton(
                      onPressed: () => _copy(_publicUrl, 'Teacher URL copied'),
                      icon: const Icon(Icons.copy_rounded),
                      tooltip: 'Copy URL',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: CircleAvatar(
                backgroundColor: colors.primaryContainer,
                child: Icon(Icons.badge_outlined,
                    color: colors.onPrimaryContainer)),
            title: const Text('Teacher ID'),
            subtitle: Text(_teacherId,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, letterSpacing: 1.1)),
            trailing: IconButton(
              onPressed: () => _copy(_teacherId, 'Teacher ID copied'),
              icon: const Icon(Icons.copy_rounded),
              tooltip: 'Copy teacher ID',
            ),
          ),
        ),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: const Text('Refresh teacher profile'),
              subtitle: const Text('Fetch the newest teacher account data.'),
              onTap: () async {
                await widget.session.refreshProfile(forceNetwork: true);
                if (!context.mounted) return;
                _snack(context, 'Teacher profile refreshed');
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.cleaning_services_outlined),
              title: const Text('Clear offline data cache'),
              subtitle: const Text('Your login stays saved on this device.'),
              onTap: () async {
                await widget.session.repository.clearCache();
                if (!context.mounted) return;
                _snack(context, 'Offline data cache cleared');
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.logout_rounded, color: colors.error),
              title: Text('Sign out', style: TextStyle(color: colors.error)),
              subtitle: const Text('Removes the saved login from this device.'),
              onTap: widget.session.signOut,
            ),
          ]),
        ),
      ],
    );
  }
}

class _InstituteWorkspacePage extends StatefulWidget {
  const _InstituteWorkspacePage({required this.session});
  final SessionController session;
  @override
  State<_InstituteWorkspacePage> createState() =>
      _InstituteWorkspacePageState();
}

class _InstituteWorkspacePageState extends State<_InstituteWorkspacePage> {
  late Future<dynamic> request = load();
  Future<dynamic> load() => Future.wait([
        widget.session.repository.ownerWorkspace(),
        widget.session.repository.invitations()
      ]);
  Future<void> refresh() async {
    setState(() => request = load());
    await request;
  }

  Future<void> respond(Map<String, dynamic> invitation, bool accept) async {
    await _act(
        context,
        () => widget.session.repository
            .respondInvitation('${invitation['id']}', accept),
        accept ? 'Invitation accepted' : 'Invitation rejected');
    await refresh();
  }

  Future<void> invite(List<Map<String, dynamic>> institutes) async {
    final data = await _showForm(context, title: 'Invite teacher', initial: {
      'instituteId': institutes.firstOrNull?['id'] ?? ''
    }, fields: const [
      _Field('instituteId', 'Institute ID'),
      _Field('teacherCode', 'Teacher ID / code')
    ]);
    if (data == null || !mounted) return;
    await _act(
        context,
        () => widget.session.repository.createInstituteInvitation(data),
        'Teacher invitation sent');
    await refresh();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
      future: request,
      builder: (context, snapshot) {
        final values = snapshot.data is List ? snapshot.data as List : const [];
        final workspace =
            values.isNotEmpty ? _map(values[0]) : <String, dynamic>{};
        final institutes = _list(workspace['institutes']);
        final invitations = values.length > 1
            ? _list(_map(values[1])['invitations'])
            : <Map<String, dynamic>>[];
        return _PageFrame(
            title: 'Institute workspace',
            subtitle: 'View connected institutes and respond to invitations.',
            loading: snapshot.connectionState == ConnectionState.waiting,
            error: snapshot.error,
            onRefresh: refresh,
            actions: [
              IconButton(
                  onPressed: () => invite(institutes),
                  icon: const Icon(Icons.person_add_alt_1),
                  tooltip: 'Invite teacher')
            ],
            children: [
              _Section(
                  'My institutes',
                  institutes
                      .map((item) => Card(
                          child: ListTile(
                              leading: const Icon(Icons.apartment),
                              title: Text(_title(item)),
                              subtitle: Text(
                                  '${item['subscription']?['status'] ?? item['status'] ?? ''}'))))
                      .toList()),
              _Section(
                  'Invitations',
                  invitations
                      .map((item) => Card(
                          child: ListTile(
                              title: Text(
                                  '${item['instituteName'] ?? 'Institute invitation'}'),
                              subtitle: Text('${item['status'] ?? ''}'),
                              trailing: item['status'] == 'pending'
                                  ? Wrap(spacing: 4, children: [
                                      IconButton(
                                          onPressed: () => respond(item, true),
                                          icon: const Icon(Icons.check)),
                                      IconButton(
                                          onPressed: () => respond(item, false),
                                          icon: const Icon(Icons.close))
                                    ])
                                  : null)))
                      .toList()),
            ]);
      });
}

class _TeacherNotificationsPage extends StatefulWidget {
  const _TeacherNotificationsPage({
    required this.session,
    required this.onNavigate,
  });

  final SessionController session;
  final ValueChanged<TeacherPage> onNavigate;

  @override
  State<_TeacherNotificationsPage> createState() =>
      _TeacherNotificationsPageState();
}

class _TeacherNotificationsPageState extends State<_TeacherNotificationsPage> {
  late Future<dynamic> _request =
      widget.session.repository.notifications(refresh: true);
  String _opening = '';

  Future<void> _refresh() async {
    setState(() =>
        _request = widget.session.repository.notifications(refresh: true));
    await _request;
  }

  Future<void> _open(Map<String, dynamic> item) async {
    final id = '${item['id'] ?? ''}';
    setState(() => _opening = id);
    try {
      if (id.isNotEmpty && item['readAt'] == null) {
        await widget.session.repository.markNotificationRead(id);
      }
      final destination = '${item['destination'] ?? item['path'] ?? ''}';
      widget.onNavigate(destination.contains('/messages')
          ? TeacherPage.messages
          : destination.contains('/students')
              ? TeacherPage.students
              : destination.contains('/institute')
                  ? TeacherPage.institute
                  : TeacherPage.dashboard);
    } finally {
      if (mounted) setState(() => _opening = '');
    }
  }

  IconData _icon(String type) => switch (type) {
        'message' => Icons.mark_chat_unread_rounded,
        'access_request' => Icons.person_add_alt_1_rounded,
        'assignment' => Icons.assignment_rounded,
        _ => Icons.notifications_active_rounded,
      };

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
        future: _request,
        builder: (context, snapshot) {
          final response = _map(snapshot.data);
          final items = _list(response['notifications'])
            ..sort((a, b) =>
                '${b['createdAt'] ?? ''}'.compareTo('${a['createdAt'] ?? ''}'));
          final colors = Theme.of(context).colorScheme;
          return _PageFrame(
            title: 'Notifications',
            subtitle:
                'Newest messages and student access requests appear first.',
            loading: snapshot.connectionState == ConnectionState.waiting,
            error: snapshot.error,
            onRefresh: _refresh,
            children: [
              if (items.isEmpty && snapshot.hasData)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(children: [
                      Icon(Icons.notifications_none_rounded,
                          size: 46, color: colors.onSurfaceVariant),
                      const SizedBox(height: 12),
                      const Text('No teacher notifications yet.'),
                    ]),
                  ),
                )
              else
                ...items.map((item) {
                  final unread = item['readAt'] == null;
                  final opening = _opening == '${item['id'] ?? ''}';
                  final type = '${item['type'] ?? 'update'}';
                  final batchName = '${item['batchName'] ?? ''}';
                  final created =
                      DateTime.tryParse('${item['createdAt'] ?? ''}')
                          ?.toLocal();
                  return Card(
                    color: unread
                        ? colors.primaryContainer.withValues(alpha: .30)
                        : null,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: opening ? null : () => _open(item),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: unread
                                  ? colors.primary
                                  : colors.surfaceContainerHighest,
                              foregroundColor: unread
                                  ? colors.onPrimary
                                  : colors.onSurfaceVariant,
                              child: Icon(_icon(type), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${item['title'] ?? 'New update'}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900)),
                                  if ('${item['body'] ?? ''}'.isNotEmpty) ...[
                                    const SizedBox(height: 5),
                                    Text('${item['body']}'),
                                  ],
                                  const SizedBox(height: 9),
                                  Wrap(spacing: 6, children: [
                                    if (batchName.isNotEmpty)
                                      Chip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text(batchName),
                                      ),
                                    if (created != null)
                                      Chip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text(
                                            DateFormat('MMM d, yyyy · h:mm a')
                                                .format(created)),
                                      ),
                                  ]),
                                ],
                              ),
                            ),
                            opening
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      );
}
