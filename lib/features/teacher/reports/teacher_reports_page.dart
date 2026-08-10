part of '../teacher_pages.dart';

class _TeacherReportsPage extends StatefulWidget {
  const _TeacherReportsPage({required this.session});
  final SessionController session;

  @override
  State<_TeacherReportsPage> createState() => _TeacherReportsPageState();
}

class _TeacherReportsPageState extends State<_TeacherReportsPage> {
  Map<String, dynamic> data = {};
  bool loading = true;
  bool exporting = false;
  String? error;
  String batchId = '';
  String grade = '';
  String exam = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      data = _map(await widget.session.repository.reports());
    } catch (exception) {
      error = '$exception';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _plain(dynamic value) => '$value'
      .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<void> _export(String kind) async {
    setState(() => exporting = true);
    try {
      final batches = _list(data['batches']);
      final students = _list(data['students']).where((student) {
        if (grade.isNotEmpty && '${student['grade']}' != grade) return false;
        if (batchId.isNotEmpty && !_strings(student['batchIds']).contains(batchId)) {
          return false;
        }
        return true;
      }).toList();
      List<String> headers;
      List<List<String>> rows;
      String title;
      switch (kind) {
        case 'payments':
          title = 'Student payment report';
          headers = ['Student', 'ID', 'Batch', 'Fee', 'Amount', 'Status', 'Paid time'];
          rows = _list(data['batchPayments']).where((row) {
            return batchId.isEmpty || '${row['batchId']}' == batchId;
          }).map((row) {
            final student = _map(row['student']);
            return [student['name'], student['studentId'], row['batchName'], row['feeType'], row['amount'], row['freeCard'] == true ? 'Free card' : row['paid'] == true ? 'Paid' : 'Due', row['paidAt']];
          }).map((row) => row.map(_plain).toList()).toList();
          break;
        case 'marks':
          title = 'Marks and results report';
          headers = ['Student', 'ID', 'Batch', 'Exam', 'Category', 'Date', 'Score'];
          rows = _list(data['results']).where((row) {
            return (batchId.isEmpty || '${row['batchId']}' == batchId) &&
                (exam.isEmpty || '${row['exam']}' == exam);
          }).map((row) {
            final student = _map(row['student']);
            return [student['name'], student['studentId'], row['batchName'], row['exam'], row['category'], row['date'], '${row['score']}/${row['total']}'];
          }).map((row) => row.map(_plain).toList()).toList();
          break;
        case 'attendance':
          title = 'Attendance report';
          headers = ['Student', 'ID', 'Batch', 'Class type', 'Date', 'Status'];
          rows = _list(data['attendance']).where((row) {
            return batchId.isEmpty || '${row['batchId']}' == batchId;
          }).map((row) {
            final student = _map(row['student']);
            return [student['name'], student['studentId'], row['batchName'], row['classType'], row['date'], row['attendance'] == 1 ? 'Present' : 'Absent'];
          }).map((row) => row.map(_plain).toList()).toList();
          break;
        default:
          title = batchId.isNotEmpty
              ? 'Batch student report'
              : grade.isNotEmpty
                  ? 'Grade student report'
                  : 'Student details report';
          headers = ['Student', 'ID', 'Grade', 'Batches', 'Free card'];
          rows = students.map((student) {
            final names = batches.where((batch) => _strings(student['batchIds']).contains('${batch['id']}')).map(_title).join(', ');
            return [student['name'], student['studentId'], student['grade'], names, student['freeCard'] == true ? 'Yes' : 'No'];
          }).map((row) => row.map(_plain).toList()).toList();
      }
      final document = pw.Document(title: title);
      document.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Text('Generated ${DateFormat('d MMM yyyy, h:mm a').format(DateTime.now())}'),
          pw.SizedBox(height: 14),
          if (rows.isEmpty) pw.Text('No matching records.') else pw.TableHelper.fromTextArray(headers: headers, data: rows, headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100), headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold), cellStyle: const pw.TextStyle(fontSize: 8), cellPadding: const pw.EdgeInsets.all(5)),
        ],
      ));
      final safeName = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
      await FilePicker.platform.saveFile(dialogTitle: 'Save report PDF', fileName: '$safeName.pdf', bytes: await document.save());
      if (mounted) _snack(context, 'Report PDF saved.');
    } catch (exception) {
      if (mounted) _snack(context, 'Could not create report: $exception', error: true);
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final batches = _list(data['batches']);
    final students = _list(data['students']);
    final grades = students.map((item) => '${item['grade'] ?? ''}').where((item) => item.isNotEmpty).toSet().toList()..sort();
    final exams = _list(data['results']).map((item) => '${item['exam'] ?? ''}').where((item) => item.isNotEmpty).toSet().toList()..sort();
    return _PageFrame(
      title: 'Reports',
      subtitle: 'Filter records and download professional PDF reports.',
      loading: loading,
      error: error,
      onRefresh: _load,
      children: [
        DropdownButtonFormField<String>(initialValue: batchId, isExpanded: true, decoration: _input('Batch filter'), items: [const DropdownMenuItem(value: '', child: Text('All batches')), ...batches.map((item) => DropdownMenuItem(value: '${item['id']}', child: Text(_title(item), overflow: TextOverflow.ellipsis)))], onChanged: (value) => setState(() => batchId = value ?? '')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(initialValue: grade, isExpanded: true, decoration: _input('Grade filter'), items: [const DropdownMenuItem(value: '', child: Text('All grades')), ...grades.map((item) => DropdownMenuItem(value: item, child: Text(item)))], onChanged: (value) => setState(() => grade = value ?? '')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(initialValue: exam, isExpanded: true, decoration: _input('Exam filter'), items: [const DropdownMenuItem(value: '', child: Text('All exams')), ...exams.map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis)))], onChanged: (value) => setState(() => exam = value ?? '')),
        const SizedBox(height: 14),
        ...[
          ('students', 'Student details', Icons.groups_outlined),
          ('payments', 'Payments and due fees', Icons.payments_outlined),
          ('attendance', 'Attendance history', Icons.fact_check_outlined),
          ('marks', 'Marks and exam results', Icons.analytics_outlined),
        ].map((item) => Card(child: ListTile(leading: Icon(item.$3), title: Text(item.$2), trailing: const Icon(Icons.picture_as_pdf_outlined), enabled: !exporting, onTap: exporting ? null : () => _export(item.$1)))),
      ],
    );
  }
}
