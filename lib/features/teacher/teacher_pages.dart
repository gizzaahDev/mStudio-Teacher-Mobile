import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_compress/video_compress.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_config.dart';
import '../../core/session.dart';
import '../../localization/app_locale.dart';
import 'teacher_shell.dart';

part 'teacher_pages_common.dart';
part 'teacher_pages_management.dart';
part 'students_workspace_page.dart';
part 'teacher_pages_learning.dart';
part 'teacher_pages_account.dart';
part 'student_portal_settings_page.dart';
part 'teacher_help_page.dart';
part 'space/teacher_space_page.dart';
part 'calendar/teacher_calendar_page.dart';
part 'messages/teacher_messages_page.dart';
part 'attendance/teacher_qr_attendance_page.dart';
part 'assignments/teacher_submissions_page.dart';
part 'reports/teacher_reports_page.dart';

class TeacherPageView extends StatelessWidget {
  const TeacherPageView(
      {super.key,
      required this.page,
      required this.session,
      required this.onNavigate,
      this.dashboardGuideKeys = const [],
      this.onDashboardGuideReady});
  final TeacherPage page;
  final SessionController session;
  final ValueChanged<TeacherPage> onNavigate;
  final List<GlobalKey> dashboardGuideKeys;
  final VoidCallback? onDashboardGuideReady;

  @override
  Widget build(BuildContext context) => switch (page) {
        TeacherPage.dashboard => _DashboardPage(
            session: session,
            onNavigate: onNavigate,
            guideKeys: dashboardGuideKeys,
            onGuideReady: onDashboardGuideReady),
        TeacherPage.classes =>
          _BatchesPage(session: session, onNavigate: onNavigate),
        TeacherPage.students => _StudentsPage(session: session),
        TeacherPage.attendance => _AttendancePage(session: session),
        TeacherPage.qr => _QrAttendancePage(session: session),
        TeacherPage.manageBatches => _BatchContentPage(session: session),
        TeacherPage.assignments => _AssignmentSubmissionsPage(session: session),
        TeacherPage.messages => _MessagesPage(session: session),
        TeacherPage.reports => _TeacherReportsPage(session: session),
        TeacherPage.calendar => _TeacherCalendarPage(session: session),
        TeacherPage.payments => _PaymentsPage(session: session),
        TeacherPage.curriculum => _CurriculumPage(session: session),
        TeacherPage.quotes => _DashboardContentPage(session: session),
        TeacherPage.institute => _InstituteWorkspacePage(session: session),
        TeacherPage.notifications => _TeacherNotificationsPage(
            session: session,
            onNavigate: onNavigate,
          ),
        TeacherPage.profile =>
          _ProfilePage(session: session, onNavigate: onNavigate),
        TeacherPage.stManage =>
          _StudentPortalSettingsPage(session: session, onNavigate: onNavigate),
        TeacherPage.subscription => _TeacherSubscriptionPage(session: session),
        TeacherPage.help => _TeacherHelpPage(session: session),
        TeacherPage.settings => _SettingsPage(session: session),
        TeacherPage.about => _AboutPage(session: session),
      };
}
