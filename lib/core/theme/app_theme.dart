import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(AppColors.light, Brightness.light);

  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors colors, Brightness brightness) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: colors.primary,
          brightness: brightness,
        ).copyWith(
          primary: colors.primary,
          onPrimary: colors.onPrimary,
          primaryContainer: colors.primaryContainer,
          onPrimaryContainer: colors.onPrimaryContainer,
          secondaryContainer: colors.secondaryContainer,
          onSecondaryContainer: colors.onSecondaryContainer,
          error: colors.danger,
          errorContainer: colors.dangerContainer,
          surface: colors.surface,
          onSurface: colors.textPrimary,
        );

    const modalRadius = Radius.circular(24);
    const modalShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(modalRadius),
    );
    final modalBarrier = colors.shadow.withAlpha(148);
    const fontFallback = ['Noto Sans Lao', 'Torsilp Kanittha'];

    return ThemeData(
      useMaterial3: true,
      fontFamilyFallback: fontFallback,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.background,
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: modalShape,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        barrierColor: modalBarrier,
        titleTextStyle: TextStyle(
          fontSize: 22,
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
          fontFamilyFallback: fontFallback,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: modalBarrier,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: modalRadius),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: modalShape,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: colors.surface,
        shape: modalShape,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide.none,
        ),
      ),
      extensions: [colors],
    );
  }
}
