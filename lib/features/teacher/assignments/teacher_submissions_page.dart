part of '../teacher_pages.dart';

class _AssignmentSubmissionsPage extends StatefulWidget {
  const _AssignmentSubmissionsPage({required this.session});
  final SessionController session;

  @override
  State<_AssignmentSubmissionsPage> createState() =>
      _AssignmentSubmissionsPageState();
}

class _AssignmentSubmissionsPageState
    extends State<_AssignmentSubmissionsPage> {
  final search = TextEditingController();
  List<Map<String, dynamic>> submissions = [];
  String batchId = 'all';
  String contentId = 'all';
  bool loading = true;
  String? error;

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
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (refresh) await widget.session.repository.clearCache();
      submissions = _list(
          _map(await widget.session.repository.assignments())['submissions']);
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<MapEntry<String, String>> get batches =>
      Map<String, String>.fromEntries(submissions.map((item) => MapEntry(
              '${item['batchId']}', '${item['batchName'] ?? 'Batch'}')))
          .entries
          .toList();
  List<MapEntry<String, String>> get assignments =>
      Map<String, String>.fromEntries(submissions
          .where((item) => batchId == 'all' || '${item['batchId']}' == batchId)
          .map((item) => MapEntry('${item['contentId']}',
              '${item['assignmentTitle'] ?? 'Assignment'}'))).entries.toList();
  List<Map<String, dynamic>> get visible {
    final query = search.text.toLowerCase();
    return submissions.where((item) {
      if (batchId != 'all' && '${item['batchId']}' != batchId) return false;
      if (contentId != 'all' && '${item['contentId']}' != contentId) {
        return false;
      }
      return ('${item['studentName']} ${item['studentId']} ${item['studentEmail']} ${item['assignmentTitle']} ${item['batchName']}')
          .toLowerCase()
          .contains(query);
    }).toList();
  }

  Future<void> _openFile(Map<String, dynamic> item) async {
    final uri = Uri.tryParse('${item['fileUrl'] ?? ''}');
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        _snack(context, 'Could not open this submission file', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final late =
        submissions.where((item) => '${item['status']}' == 'late').length;
    return _PageFrame(
      title: 'Assignment submissions',
      subtitle:
          'Find every submitted file by batch, assignment, student, and deadline.',
      loading: loading,
      error: error,
      onRefresh: () => _load(refresh: true),
      children: [
        Row(children: [
          Expanded(
              child: _SubmissionStat(
                  icon: Icons.description_outlined,
                  label: 'Total',
                  value: submissions.length,
                  color: Theme.of(context).colorScheme.primary)),
          const SizedBox(width: 8),
          Expanded(
              child: _SubmissionStat(
                  icon: Icons.check_circle_outline,
                  label: 'On time',
                  value: submissions.length - late,
                  color: Colors.green)),
          const SizedBox(width: 8),
          Expanded(
              child: _SubmissionStat(
                  icon: Icons.schedule,
                  label: 'Late',
                  value: late,
                  color: Colors.red)),
        ]),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
            initialValue: batchId,
            decoration: _input('Batch'),
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All batches')),
              ...batches.map((entry) =>
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)))
            ],
            onChanged: (value) => setState(() {
                  batchId = value ?? 'all';
                  contentId = 'all';
                })),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
            initialValue: contentId,
            decoration: _input('Assignment'),
            items: [
              const DropdownMenuItem(
                  value: 'all', child: Text('All assignments')),
              ...assignments.map((entry) =>
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)))
            ],
            onChanged: (value) => setState(() => contentId = value ?? 'all')),
        const SizedBox(height: 10),
        TextField(
            controller: search,
            decoration: _input('Student name, ID, email, batch, or assignment')
                .copyWith(prefixIcon: const Icon(Icons.search)),
            onChanged: (_) => setState(() {})),
        const SizedBox(height: 14),
        Text('${visible.length} submission${visible.length == 1 ? '' : 's'}',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        if (visible.isEmpty && !loading)
          const _Message('No submissions match these filters.'),
        ...visible.map((item) {
          final isLate = '${item['status']}' == 'late';
          final submitted =
              DateTime.tryParse('${item['submittedAt'] ?? ''}')?.toLocal();
          final deadline =
              DateTime.tryParse('${item['deadline'] ?? ''}')?.toLocal();
          return Card(
            margin: const EdgeInsets.only(top: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                              child: Text(_initials(
                                  '${item['studentName'] ?? 'Student'}'))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('${item['studentName'] ?? 'Student'}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                Text(
                                    '${item['studentId'] ?? 'Student ID pending'}',
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary)),
                                Text('${item['studentEmail'] ?? ''}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall)
                              ])),
                          Chip(
                              avatar: Icon(
                                  isLate ? Icons.schedule : Icons.check,
                                  size: 16),
                              label: Text(isLate ? 'Late' : 'On time'),
                              backgroundColor:
                                  (isLate ? Colors.red : Colors.green)
                                      .withValues(alpha: .12)),
                        ]),
                    const Divider(height: 22),
                    Text('${item['assignmentTitle'] ?? 'Assignment'}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${item['batchName'] ?? ''}'),
                    if (submitted != null)
                      Text(
                          'Submitted: ${DateFormat('d MMM yyyy, h:mm a').format(submitted)}',
                          style: Theme.of(context).textTheme.bodySmall),
                    if (deadline != null)
                      Text(
                          'Deadline: ${DateFormat('d MMM yyyy, h:mm a').format(deadline)}',
                          style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 10),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                            onPressed: '${item['fileUrl'] ?? ''}'.isEmpty
                                ? null
                                : () => _openFile(item),
                            icon: const Icon(Icons.download),
                            label: Text(
                                '${item['fileName'] ?? 'Open submitted file'}'))),
                  ]),
            ),
          );
        }),
      ],
    );
  }
}

class _SubmissionStat extends StatelessWidget {
  const _SubmissionStat(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
          child: Column(children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text('$value',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(context).textTheme.labelSmall)
          ])));
}
