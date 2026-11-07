import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'app_colors.dart';

class AppTheme {
  static const fontFamily = 'Inter';
  static const fontStyle = TextStyle(fontFamily: fontFamily);

  static TextStyle _withFont(TextStyle style) =>
      style.copyWith(fontFamily: fontFamily);

  static final lightTheme = _build(Brightness.light);
  static final darkTheme = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: dark ? AppColors.darkPrimary : AppColors.primary,
      onPrimary: dark ? const Color(0xFF10382C) : Colors.white,
      primaryContainer:
          dark ? const Color(0xFF244B3E) : const Color(0xFFE1EFE7),
      onPrimaryContainer:
          dark ? const Color(0xFFBEEBD7) : const Color(0xFF204D3D),
      secondary: dark ? AppColors.darkSecondary : AppColors.secondary,
      onSecondary: dark ? const Color(0xFF542B1D) : Colors.white,
      secondaryContainer:
          dark ? const Color(0xFF4F352A) : const Color(0xFFF6E7DE),
      onSecondaryContainer:
          dark ? const Color(0xFFF5D5C2) : const Color(0xFF763E2B),
      surface: dark ? AppColors.darkSurface : AppColors.surface,
      onSurface: dark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      onSurfaceVariant:
          dark ? AppColors.darkTextSecondary : AppColors.textSecondary,
      surfaceContainerLow:
          dark ? const Color(0xFF1C2721) : const Color(0xFFF1F3ED),
      surfaceContainerHighest:
          dark ? const Color(0xFF303E35) : const Color(0xFFE5EAE2),
      outline: dark ? const Color(0xFF87998D) : const Color(0xFF79877D),
      outlineVariant: dark ? const Color(0xFF3C4B41) : const Color(0xFFDCE3DA),
      error: dark ? const Color(0xFFFFB3B3) : AppColors.error,
      onError: dark ? const Color(0xFF650E1A) : Colors.white,
      errorContainer: dark ? const Color(0xFF53272C) : const Color(0xFFFBE8E7),
      onErrorContainer:
          dark ? const Color(0xFFFFDAD8) : const Color(0xFF872E35),
    );
    final base = ThemeData(
        useMaterial3: true, colorScheme: scheme, fontFamily: fontFamily);
    final cupertinoText = CupertinoTextThemeData(primaryColor: scheme.primary);

    return base.copyWith(
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: scheme.primary,
        primaryContrastingColor: scheme.onPrimary,
        scaffoldBackgroundColor: scheme.surface,
        barBackgroundColor: scheme.surface,
        textTheme: cupertinoText.copyWith(
          textStyle: _withFont(cupertinoText.textStyle),
          actionTextStyle: _withFont(cupertinoText.actionTextStyle)
              .copyWith(fontWeight: FontWeight.w500),
          actionSmallTextStyle: _withFont(cupertinoText.actionSmallTextStyle)
              .copyWith(fontWeight: FontWeight.w500),
          tabLabelTextStyle: _withFont(cupertinoText.tabLabelTextStyle),
          navTitleTextStyle: _withFont(cupertinoText.navTitleTextStyle),
          navLargeTitleTextStyle:
              _withFont(cupertinoText.navLargeTitleTextStyle),
          navActionTextStyle: _withFont(cupertinoText.navActionTextStyle),
          pickerTextStyle: _withFont(cupertinoText.pickerTextStyle),
          dateTimePickerTextStyle:
              _withFont(cupertinoText.dateTimePickerTextStyle),
        ),
      ),
      scaffoldBackgroundColor: scheme.surface,
      textTheme: base.textTheme.copyWith(
        bodyLarge: base.textTheme.bodyLarge?.copyWith(color: scheme.onSurface),
        bodyMedium:
            base.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurfaceVariant,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        dragHandleColor: scheme.outlineVariant,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: fontStyle.copyWith(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
