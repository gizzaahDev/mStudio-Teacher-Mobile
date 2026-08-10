import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/session.dart';
import '../../localization/app_locale.dart';

class TeacherOnboardingPage extends StatefulWidget {
  const TeacherOnboardingPage({super.key, required this.session});
  final SessionController session;

  @override
  State<TeacherOnboardingPage> createState() => _TeacherOnboardingPageState();
}

class _TeacherOnboardingPageState extends State<TeacherOnboardingPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _nic = TextEditingController();
  final _students = TextEditingController(text: '50');
  File? _nicFront;
  File? _nicBack;
  int _trialDays = 30;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.text = FirebaseAuth.instance.currentUser?.displayName ?? '';
    _loadSettings();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _nic.dispose();
    _students.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final response = await widget.session.repository.appSettings();
      final root = response is Map ? response : const {};
      final settings =
          root['settings'] is Map ? root['settings'] as Map : const {};
      final deployment = settings['deployment'] is Map
          ? settings['deployment'] as Map
          : const {};
      if (mounted) {
        setState(() => _trialDays =
            (deployment['teacherTrialDays'] as num?)?.toInt() ?? 30);
      }
    } catch (_) {}
  }

  int get _studentCount => int.tryParse(_students.text.trim()) ?? 0;

  Future<void> _pick(bool front) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
          child: Wrap(children: [
        ListTile(
            leading: const Icon(Icons.folder_open_rounded),
            title: const Text('Choose image file'),
            onTap: () => Navigator.pop(context, ImageSource.gallery)),
        ListTile(
            leading: const Icon(Icons.camera_alt_rounded),
            title: const Text('Use camera'),
            subtitle: const Text(
                'Autofocus is enabled. Keep the full NIC inside the camera frame.'),
            onTap: () => Navigator.pop(context, ImageSource.camera)),
      ])),
    );
    if (source == null) return;
    String? path;
    if (source == ImageSource.camera) {
      path = (await ImagePicker().pickImage(
              source: ImageSource.camera,
              imageQuality: 88,
              preferredCameraDevice: CameraDevice.rear))
          ?.path;
    } else {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      path = result?.files.single.path;
    }
    if (path == null || !mounted) return;
    final selectedPath = path;
    setState(() {
      if (front) {
        _nicFront = File(selectedPath);
      } else {
        _nicBack = File(selectedPath);
      }
    });
  }

  Future<void> _submit() async {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final nic = _nic.text.trim();
    final validNic = RegExp(r'^(\d{9}[vVxX]|\d{12})$').hasMatch(nic);
    if (_name.text.trim().isEmpty ||
        email.isEmpty ||
        _phone.text.trim().length < 5) {
      setState(() => _error =
          'Enter your full name, registered phone number, and use an account with an email address.');
      return;
    }
    if (!validNic) {
      setState(() => _error =
          'Enter a valid 12-digit NIC or old 9-digit NIC ending in V/X.');
      return;
    }
    if (_nicFront == null || _nicBack == null) {
      setState(() => _error = 'Add clear images of both sides of your NIC.');
      return;
    }
    if (_studentCount < 1) {
      setState(() => _error = 'Enter your expected total student count.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final front =
          await widget.session.repository.uploadTeacherVerification(_nicFront!);
      final back =
          await widget.session.repository.uploadTeacherVerification(_nicBack!);
      await widget.session.repository.registerTeacher({
        'displayName': _name.text.trim(),
        'email': email,
        'phone': _phone.text.trim(),
        'role': 'teacher',
        'separateClassAccount': true,
        'nicNumber': nic.toUpperCase(),
        'nicFrontUrl': front['url'],
        'nicBackUrl': back['url'],
        'estimatedStudentCount': _studentCount,
      });
      await widget.session.refreshProfile(forceNetwork: true);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(appLocale.tr('Create teacher account')),
        actions: [
          TextButton(
              onPressed: widget.session.signOut, child: const Text('Sign out')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(appLocale.tr('Teacher verification'),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          const Text(
              'Complete every field. The dashboard opens only after an administrator reviews your NIC and approves the request.'),
          const SizedBox(height: 18),
          TextField(
              controller: _name,
              decoration: InputDecoration(
                  labelText: appLocale.tr('Full name'),
                  prefixIcon: const Icon(Icons.person_outline))),
          const SizedBox(height: 12),
          TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Registered phone number',
                  prefixIcon: Icon(Icons.phone_outlined))),
          const SizedBox(height: 12),
          TextFormField(
              initialValue: FirebaseAuth.instance.currentUser?.email ?? '',
              enabled: false,
              decoration: const InputDecoration(
                  labelText: 'Signed-in email',
                  prefixIcon: Icon(Icons.email_outlined))),
          const SizedBox(height: 12),
          TextField(
              controller: _nic,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                  labelText: appLocale.tr('NIC number'),
                  hintText: '200012345678 or 123456789V',
                  prefixIcon: const Icon(Icons.badge_outlined))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _NicPicker(
                    label: 'NIC front image',
                    file: _nicFront,
                    onTap: () => _pick(true))),
            const SizedBox(width: 10),
            Expanded(
                child: _NicPicker(
                    label: 'NIC back image',
                    file: _nicBack,
                    onTap: () => _pick(false))),
          ]),
          const SizedBox(height: 12),
          TextField(
              controller: _students,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                  labelText: appLocale.tr('Expected total students'),
                  prefixIcon: const Icon(Icons.groups_outlined))),
          const SizedBox(height: 12),
          const Text(
            'Your subscription capacity is assigned automatically from the expected student count after administrator approval.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 14),
          FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded),
              label: Text(_saving
                  ? appLocale.tr('Submitting…')
                  : appLocale.tr('Submit for admin approval'))),
          const SizedBox(height: 12),
          Text(
            'After approval, your teacher and student access includes a $_trialDays-day free trial followed by a 2-day renewal grace period.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class TeacherApprovalPage extends StatelessWidget {
  const TeacherApprovalPage(
      {super.key, required this.session, required this.profile});
  final SessionController session;
  final Map<String, dynamic> profile;

  Future<void> _contactAdmin(BuildContext context) async {
    final controller = TextEditingController(
      text: 'Hello, I need help with my teacher account approval.',
    );
    final message = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Contact administrator'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Message',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim(),
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (message == null || message.isEmpty || !context.mounted) return;
    try {
      await session.repository.sendSupportMessage(message);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent to the administrator.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send message: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rejected = profile['status'] == 'rejected';
    return Scaffold(
      appBar: AppBar(actions: [
        TextButton(onPressed: session.signOut, child: const Text('Sign out'))
      ]),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                      rejected
                          ? Icons.cancel_outlined
                          : Icons.hourglass_top_rounded,
                      size: 58,
                      color: rejected
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                      rejected
                          ? 'Teacher request needs attention'
                          : 'Waiting for administrator approval',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 10),
                  Text(
                      rejected
                          ? 'Please contact support or update the requested verification details.'
                          : 'Your teacher dashboard is locked until the administrator verifies both NIC images, expected student count, and account details.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text('${profile['displayName'] ?? ''}'),
                      subtitle: Text('${profile['email'] ?? ''}')),
                  ListTile(
                      leading: const Icon(Icons.groups_outlined),
                      title: Text(
                          '${profile['estimatedStudentCount'] ?? 0} expected students'),
                      subtitle: Text(
                          '${profile['subscriptionTierId'] ?? ''} · ${profile['billingCycle'] ?? 'monthly'}')),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: () =>
                            session.refreshProfile(forceNetwork: true),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Check approval status'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _contactAdmin(context),
                        icon: const Icon(Icons.support_agent_rounded),
                        label: const Text('Contact admin'),
                      ),
                    ],
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NicPicker extends StatelessWidget {
  const _NicPicker(
      {required this.label, required this.file, required this.onTap});
  final String label;
  final File? file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
            side: BorderSide(
                color: file == null
                    ? Theme.of(context).dividerColor
                    : Colors.yellow.shade700,
                width: 2),
            backgroundColor:
                file == null ? null : Colors.yellow.withValues(alpha: .10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14)),
        child: Column(children: [
          Icon(file == null
              ? Icons.add_a_photo_outlined
              : Icons.check_circle_rounded),
          const SizedBox(height: 6),
          Container(
              height: 52,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                  border: Border.all(
                      color: file == null
                          ? Theme.of(context).colorScheme.outline
                          : Colors.yellow.shade700),
                  borderRadius: BorderRadius.circular(8)),
              child: Center(
                  child: Text(
                      file == null
                          ? 'Keep the full NIC inside this rectangle'
                          : 'NIC image detected',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10)))),
          Text(file == null ? label : file!.uri.pathSegments.last,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
        ]),
      );
}
