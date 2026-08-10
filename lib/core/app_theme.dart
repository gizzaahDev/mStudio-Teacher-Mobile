import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract final class AppTheme {
  static const _lightSeed = Color(0xff5b4df5);
  static const _darkSeed = Color(0xff8b7cff);
  static Map<String, dynamic> _remote = const {};

  static Color _remoteColor(String mode, String key, Color fallback) {
    final themes = _remote['portalThemes'];
    final teacher = themes is Map ? themes['teacher'] : null;
    final values = teacher is Map ? teacher[mode] : null;
    final raw =
        values is Map ? '${values[key] ?? ''}'.replaceFirst('#', '') : '';
    return Color(int.tryParse(raw.length == 6 ? 'ff$raw' : raw, radix: 16) ??
        fallback.toARGB32());
  }

  static void configure(Map<String, dynamic> settings) => _remote = settings;

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final mode = isDark ? 'dark' : 'light';
    final primary =
        _remoteColor(mode, 'primaryColor', isDark ? _darkSeed : _lightSeed);
    final accent = _remoteColor(mode, 'accentColor',
        isDark ? const Color(0xffff82bf) : const Color(0xffc02674));
    final mobileRoot = _remote['mobileVisualEffects'];
    final mobile = mobileRoot is Map && mobileRoot['teacher'] is Map
        ? mobileRoot['teacher'] as Map
        : const {};
    final cardOpacity = mobile['cardTransparent'] == false
        ? 1.0
        : ((mobile['cardOpacity'] as num?)?.toDouble() ?? 90) / 100;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ).copyWith(
      primary: primary,
      secondary: isDark ? const Color(0xff5fd4ff) : const Color(0xff087fbd),
      tertiary: accent,
      surface: isDark ? const Color(0xff101522) : const Color(0xfff8f9ff),
      surfaceContainer:
          isDark ? const Color(0xff171d2b) : const Color(0xffffffff),
      surfaceContainerHigh:
          isDark ? const Color(0xff202738) : const Color(0xffeef0fb),
    );

    final textTheme = ThemeData(brightness: brightness).textTheme.copyWith(
          headlineSmall: TextStyle(
            color: scheme.onSurface,
            fontSize: 27,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
          titleLarge: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.25,
          ),
          titleMedium: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          bodyMedium: TextStyle(
            color: scheme.onSurfaceVariant,
            height: 1.42,
          ),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: scheme.surface,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        actionsIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        color: scheme.surfaceContainer
            .withValues(alpha: cardOpacity.clamp(.1, 1.0)),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: .075)
                : const Color(0xffdfe3f4),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor:
            scheme.surfaceContainerHigh.withValues(alpha: isDark ? .72 : .8),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: .55),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor:
            isDark ? const Color(0xff171d2b) : const Color(0xfff5f6ff),
        surfaceTintColor: Colors.transparent,
        indicatorColor:
            isDark ? const Color(0xff2d3555) : const Color(0xffe7e4ff),
        indicatorShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 24,
              color: states.contains(WidgetState.selected)
                  ? (isDark ? const Color(0xffa99bff) : const Color(0xff5b4df5))
                  : (isDark
                      ? const Color(0xffc7cdec)
                      : const Color(0xff5f6478)),
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w600,
              color: states.contains(WidgetState.selected)
                  ? (isDark ? const Color(0xffa99bff) : const Color(0xff5b4df5))
                  : (isDark
                      ? const Color(0xffc7cdec)
                      : const Color(0xff5f6478)),
            )),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        selectedTileColor: scheme.primaryContainer.withValues(alpha: .72),
        selectedColor: scheme.onPrimaryContainer,
        iconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: .48),
        space: 24,
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isDark ? const Color(0xff252c3d) : const Color(0xff24243a),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primaryContainer,
      ),
    );
  }
}

class AppThemeController extends ChangeNotifier {
  static const _storageKey = 'teacher_theme_mode';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    final value = await _storage.read(key: _storageKey);
    _mode = switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  Future<void> setMode(ThemeMode value) async {
    if (_mode == value) return;
    _mode = value;
    notifyListeners();
    await _storage.write(key: _storageKey, value: value.name);
  }

  void applyRemoteSettings(Map<String, dynamic> settings) {
    AppTheme.configure(settings);
    notifyListeners();
  }
}

class PremiumBackdrop extends StatelessWidget {
  const PremiumBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: isDark ? const Color(0xff080b13) : const Color(0xfff6f7fc),
          ),
          IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: 370,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(54),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary.withValues(alpha: isDark ? .44 : .27),
                      scheme.tertiary.withValues(alpha: isDark ? .24 : .14),
                      scheme.secondary.withValues(alpha: isDark ? .17 : .1),
                      Colors.transparent,
                    ],
                    stops: const [0, .34, .62, 1],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
