import 'package:flutter/material.dart';

/// WeRobo design tokens — extracted from 캡스톤 UI/UX Figma
class WeRoboColors {
  WeRoboColors._();

  // 주 색상 (Primary sky blue palette)
  static const Color sky1 = Color(0xFFCFECF7);
  static const Color sky2 = Color(0xFFA0D9EF);
  static const Color sky3 = Color(0xFF62C1E5);
  static const Color sky4 = Color(0xFF20A7DB);
  static const Color sky5 = Color(0xFF1C96C5);

  // Semantic aliases
  static const Color primary = sky4;
  static const Color primaryLight = sky2;
  static const Color primaryDark = sky5;

  // 부 색상 (Neutrals)
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGray = Color(0xFFD3D3D3);
  static const Color silver = Color(0xFFC0C0C0);
  static const Color black = Color(0xFF000000);

  // Surfaces
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = white;
  static const Color card = Color(0xFFF0F0F0);

  // Text
  static const Color textPrimary = black;
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textTertiary = silver;

  // Status
  static const Color accent = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFEF4444);

  // Chart colors
  static const Color chartBlue = sky4;
  static const Color chartGreen = Color(0xFF34D399);
  static const Color chartYellow = Color(0xFFFBBF24);
  static const Color chartPurple = Color(0xFF8B5CF6);

  // Social auth brand colors
  static const Color kakaoYellow = Color(0xFFFEE500);
  static const Color kakaoBrown = Color(0xFF3C1E1E);
  static const Color naverGreen = Color(0xFF03C75A);

  // Standard radii
  static const double radiusS = 8;
  static const double radiusM = 12;
  static const double radiusL = 16;

  // Dot indicator
  static const Color dotActive = sky4;
  static const Color dotInactive = lightGray;
}

/// Font families from Figma:
/// - 디스플레이용: Jalnan (여기어때 잘난체)
/// - 본문용: Noto Sans Korean
/// - 캡션용: Gothic A1
/// - 숫자용: Google Sans Flex
/// - 영어용: IBM Plex Sans
class WeRoboFonts {
  WeRoboFonts._();

  static const String display = 'Jalnan';
  static const String body = 'NotoSansKR';
  static const String caption = 'GothicA1';
  static const String number = 'GoogleSansFlex';
  static const String english = 'IBMPlexSans';
}

class WeRoboTypography {
  WeRoboTypography._();

  // Logo — Jalnan 48px bold white (from Figma CSS)
  static const TextStyle logo = TextStyle(
    fontFamily: WeRoboFonts.display,
    fontSize: 48,
    fontWeight: FontWeight.w700,
    color: WeRoboColors.white,
    letterSpacing: -0.5,
    height: 51 / 48,
  );

  static const TextStyle heading1 = TextStyle(
    fontFamily: WeRoboFonts.body,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: WeRoboColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle heading2 = TextStyle(
    fontFamily: WeRoboFonts.body,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: WeRoboColors.textPrimary,
    height: 1.35,
  );

  static const TextStyle heading3 = TextStyle(
    fontFamily: WeRoboFonts.body,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: WeRoboColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle body = TextStyle(
    fontFamily: WeRoboFonts.body,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: WeRoboColors.textSecondary,
    height: 1.6,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: WeRoboFonts.body,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: WeRoboColors.textSecondary,
    height: 1.5,
  );

  static const TextStyle button = TextStyle(
    fontFamily: WeRoboFonts.body,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.0,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: WeRoboFonts.caption,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: WeRoboColors.textTertiary,
    height: 1.4,
  );

  /// For percentage numbers in charts
  static const TextStyle number = TextStyle(
    fontFamily: WeRoboFonts.number,
    fontSize: 28,
    fontWeight: FontWeight.w500,
    color: WeRoboColors.textPrimary,
    height: 36 / 28,
  );
}

class WeRoboTheme {
  WeRoboTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: WeRoboColors.background,
      colorScheme: const ColorScheme.light(
        primary: WeRoboColors.primary,
        secondary: WeRoboColors.accent,
        surface: WeRoboColors.surface,
        error: WeRoboColors.error,
      ),
      textTheme: const TextTheme(
        headlineLarge: WeRoboTypography.heading1,
        headlineMedium: WeRoboTypography.heading2,
        headlineSmall: WeRoboTypography.heading3,
        bodyLarge: WeRoboTypography.body,
        bodyMedium: WeRoboTypography.bodySmall,
        labelLarge: WeRoboTypography.button,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WeRoboColors.primary,
          foregroundColor: WeRoboColors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: WeRoboTypography.button,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: WeRoboColors.primary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(
            color: WeRoboColors.primary,
            width: 1.5,
          ),
          textStyle: WeRoboTypography.button,
        ),
      ),
    );
  }
}
