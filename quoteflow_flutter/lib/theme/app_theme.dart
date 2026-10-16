import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// QuoteFlow design tokens — an Apple-grade palette.
///
/// Colors mirror the iOS system palette so the app feels native on iOS and
/// Apple-clean everywhere else. Status colors are the iOS system colors
/// (blue/green/teal/red/orange/gray), and surfaces use the iOS grouped
/// hierarchy: a light gray canvas with white cards floating on it.
class AppColors {
  AppColors._();

  // Accent — iOS system blue.
  static const Color accent = Color(0xFF0662F0);
  static const Color accentDark = Color(0xFF0064D8);
  static const Color accentTint = Color(0xFFE3F0FF);

  // Surfaces — iOS system grouped background hierarchy.
  static const Color background = Color(0xFFF6F8FE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color backgroundDark = Color(0xFF101421);
  static const Color surfaceDark = Color(0xFF1B2233);
  static const Color fill = Color(0xFF767680);
  static const Color fillDark = Color(0xFF48484A);

  // Separators / outlines.
  static const Color separator = Color(0xFFC6C6C8);
  static const Color separatorDark = Color(0xFF38383A);
  static const Color separatorLight = Color(0xFFE5E5EA);
  static const Color separatorLightDark = Color(0xFF262628);

  // iOS system semantic colors.
  static const Color blue = Color(0xFF005FCC);
  static const Color green = Color(0xFF187A35);
  static const Color teal = Color(0xFF087587);
  static const Color red = Color(0xFFC62828);
  static const Color orange = Color(0xFF995700);
  static const Color yellow = Color(0xFFFFCC00);
  static const Color gray = Color(0xFF616169);

  static const Color blueDark = Color(0xFF0A84FF);
  static const Color greenDark = Color(0xFF30D158);
  static const Color tealDark = Color(0xFF40C8E0);
  static const Color redDark = Color(0xFFFF453A);
  static const Color orangeDark = Color(0xFFFF9F0A);
  static const Color yellowDark = Color(0xFFFFD60A);
  static const Color grayDark = Color(0xFF98989F);
}

/// The app-wide theme: iOS-flavored light and dark modes.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final accent = isDark ? AppColors.accentDark : AppColors.accent;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surface;
    final separator = isDark
        ? AppColors.separatorDark
        : AppColors.separatorLight;
    final onSurface = isDark ? Colors.white : const Color(0xFF000000);
    // Secondary text: iOS uses 60% for secondaryLabel — black60 on white is
    // ~5.9:1, comfortably above the 4.5:1 AA threshold for small text.
    final muted = isDark ? Colors.white70 : const Color(0xFF54545C);
    final fill = isDark ? AppColors.fillDark : AppColors.fill;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? const Color(0xFF82B9FF) : accent,
          onPrimary: isDark ? const Color(0xFF082244) : Colors.white,
          primaryContainer: isDark
              ? accent.withValues(alpha: 0.35)
              : AppColors.accentTint,
          // Text on the tinted container must be darker (light) / lighter (dark)
          // than the accent itself to clear the 4.5:1 AA bar.
          onPrimaryContainer: isDark
              ? const Color(0xFF64B4FF)
              : const Color(0xFF0055D4),
          secondary: isDark ? AppColors.grayDark : AppColors.gray,
          onSecondary: isDark ? Colors.black : Colors.white,
          error: isDark ? AppColors.redDark : AppColors.red,
          surface: surface,
          onSurface: onSurface,
          onSurfaceVariant: muted,
          // Pin the filled-card grays to iOS systemGray values instead of the
          // seed-derived tones, so secondary surfaces stay predictable in both
          // modes (light: systemGray5, dark: systemGray6).
          surfaceContainerHighest: isDark
              ? const Color(0xFF2C2C2E)
              : const Color(0xFFE5E5EA),
          surfaceContainer: isDark
              ? const Color(0xFF262628)
              : const Color(0xFFEFEFF4),
          surfaceContainerLow: isDark
              ? const Color(0xFF1C1C1E)
              : const Color(0xFFF7F7FA),
          outline: isDark ? AppColors.separatorDark : AppColors.separator,
          outlineVariant: separator,
          surfaceTint: Colors.transparent,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      splashFactory: InkSparkle.splashFactory,
    );

    final text = base.textTheme
        .copyWith(
          // iOS large title / headlines.
          headlineLarge: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            height: 1.1,
          ),
          headlineMedium: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            height: 1.15,
          ),
          headlineSmall: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            height: 1.2,
          ),
          titleLarge: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
          titleMedium: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
          titleSmall: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
          bodyLarge: const TextStyle(fontSize: 17, height: 1.35),
          bodyMedium: const TextStyle(fontSize: 15, height: 1.35),
          bodySmall: const TextStyle(fontSize: 13, height: 1.3),
          labelLarge: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          labelMedium: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          labelSmall: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        )
        .apply(bodyColor: onSurface, displayColor: onSurface);

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: surface,
      dividerColor: separator,
      splashColor: accent.withValues(alpha: 0.12),
      highlightColor: accent.withValues(alpha: 0.06),

      // iOS push transition on every platform.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.primary, size: 22),
        actionsIconTheme: IconThemeData(color: scheme.primary, size: 22),
        surfaceTintColor: Colors.transparent,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 66,
        indicatorColor: accent.withValues(alpha: .075),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? accent
                : (isDark ? Colors.white70 : Colors.black54),
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 10,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected
                ? accent
                : (isDark ? Colors.white70 : Colors.black54),
          );
        }),
      ),

      // iOS text fields: filled gray wells, no outline.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? fill.withValues(alpha: .22)
            : const Color(0xFFF1F4FC),
        hintStyle: TextStyle(color: muted, fontSize: 15),
        labelStyle: TextStyle(color: muted, fontSize: 15),
        prefixIconColor: muted,
        suffixIconColor: muted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: accent.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: isDark
              ? Colors.white12
              : Colors.black.withValues(alpha: 0.08),
          disabledForegroundColor: isDark
              ? Colors.white38
              : Colors.black.withValues(alpha: 0.35),
          elevation: 0,
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: separator),
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: scheme.primary),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 6,
        highlightElevation: 4,
        shape: const CircleBorder(),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 1,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0xFF7994C1).withValues(alpha: .12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        margin: EdgeInsets.zero,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        contentTextStyle: TextStyle(fontSize: 13, height: 1.4, color: muted),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? Colors.white : const Color(0xFF1C1C1E),
        contentTextStyle: TextStyle(
          color: isDark ? Colors.black87 : Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: isDark ? AppColors.accent : AppColors.accentDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      dividerTheme: DividerThemeData(
        color: separator,
        thickness: 0.5,
        space: 0.5,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isDark ? Colors.white70 : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return isDark ? Colors.white24 : Colors.black26;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? accent
              : (isDark ? Colors.white24 : Colors.black26),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: separator,
        circularTrackColor: separator,
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.25),
        selectionHandleColor: accent,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        textColor: onSurface,
        titleTextStyle: TextStyle(fontSize: 16, color: onSurface),
        subtitleTextStyle: TextStyle(fontSize: 13, color: muted),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? Colors.white : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          color: isDark ? Colors.black87 : Colors.white,
          fontSize: 12,
        ),
        waitDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}
