import 'package:flutter/material.dart';

/// Semantic color tokens so every screen adapts to light/dark mode
/// instead of hardcoding hex values. Access via `context.colors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.primaryContainerStrong,
    required this.onPrimaryContainer,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.success,
    required this.successContainer,
    required this.successContainerBorder,
    required this.danger,
    required this.dangerContainer,
    required this.warning,
    required this.warningContainer,
    required this.shadow,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color primaryContainerStrong;
  final Color onPrimaryContainer;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color success;
  final Color successContainer;
  final Color successContainerBorder;
  final Color danger;
  final Color dangerContainer;
  final Color warning;
  final Color warningContainer;

  /// Full-opacity base used with `.withAlpha(...)` for shadows and scrims.
  final Color shadow;

  static const light = AppColors(
    background: Color(0xFFF8FAFC),
    surface: Colors.white,
    surfaceMuted: Color(0xFFF1F5F9),
    border: Color(0xFFE2E8F0),
    borderStrong: Color(0xFFCBD5E1),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF64748B),
    primary: Color(0xFF2563EB),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFDBEAFE),
    primaryContainerStrong: Color(0xFFBFDBFE),
    onPrimaryContainer: Color(0xFF1E3A8A),
    secondaryContainer: Color(0xFFEEF2FF),
    onSecondaryContainer: Color(0xFF3730A3),
    success: Color(0xFF16A34A),
    successContainer: Color(0xFFDCFCE7),
    successContainerBorder: Color(0xFF86EFAC),
    danger: Color(0xFFDC2626),
    dangerContainer: Color(0xFFFEE2E2),
    warning: Color(0xFFF59E0B),
    warningContainer: Color(0xFFFFFBEB),
    shadow: Color(0xFF0F172A),
  );

  static const dark = AppColors(
    background: Color(0xFF0B1220),
    surface: Color(0xFF1A2335),
    surfaceMuted: Color(0xFF232E44),
    border: Color(0xFF334155),
    borderStrong: Color(0xFF475569),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFFCBD5E1),
    textMuted: Color(0xFF94A3B8),
    primary: Color(0xFF3B82F6),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFF1E3A5F),
    primaryContainerStrong: Color(0xFF24466E),
    onPrimaryContainer: Color(0xFFBFDBFE),
    secondaryContainer: Color(0xFF312E52),
    onSecondaryContainer: Color(0xFFC7D2FE),
    success: Color(0xFF4ADE80),
    successContainer: Color(0xFF14532D),
    successContainerBorder: Color(0xFF16A34A),
    danger: Color(0xFFF87171),
    dangerContainer: Color(0xFF4C1414),
    warning: Color(0xFFFBBF24),
    warningContainer: Color(0xFF452B07),
    shadow: Color(0xFF000000),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? primaryContainerStrong,
    Color? onPrimaryContainer,
    Color? secondaryContainer,
    Color? onSecondaryContainer,
    Color? success,
    Color? successContainer,
    Color? successContainerBorder,
    Color? danger,
    Color? dangerContainer,
    Color? warning,
    Color? warningContainer,
    Color? shadow,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      primaryContainerStrong:
          primaryContainerStrong ?? this.primaryContainerStrong,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      onSecondaryContainer: onSecondaryContainer ?? this.onSecondaryContainer,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      successContainerBorder:
          successContainerBorder ?? this.successContainerBorder,
      danger: danger ?? this.danger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primaryContainer: Color.lerp(primaryContainer, other.primaryContainer, t)!,
      primaryContainerStrong: Color.lerp(
        primaryContainerStrong,
        other.primaryContainerStrong,
        t,
      )!,
      onPrimaryContainer:
          Color.lerp(onPrimaryContainer, other.onPrimaryContainer, t)!,
      secondaryContainer:
          Color.lerp(secondaryContainer, other.secondaryContainer, t)!,
      onSecondaryContainer:
          Color.lerp(onSecondaryContainer, other.onSecondaryContainer, t)!,
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      successContainerBorder: Color.lerp(
        successContainerBorder,
        other.successContainerBorder,
        t,
      )!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
