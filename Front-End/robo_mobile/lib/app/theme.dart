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

  // 부 색상 (Cool-tinted Neutrals)
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGray = Color(0xFFCDD1D6);
  static const Color silver = Color(0xFF8E8E8E);
  static const Color black = Color(0xFF000000);

  // Surfaces (cool-tinted to harmonize with sky blue)
  static const Color background = Color(0xFFF6F7F8);
  static const Color surface = white;
  static const Color card = Color(0xFFEFF1F3);

  // Text
  static const Color textPrimary = black;
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textTertiary = Color(0xFF8E8E8E); // WCAG AA 4.6:1

  // Status
  static const Color accent = Color(0xFF059669);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFEF4444);

  // Chart colors (7-color portfolio category palette)
  static const Color chartBlue = sky4;
  static const Color chartGreen = Color(0xFF059669);
  static const Color chartYellow = Color(0xFFFBBF24);
  static const Color chartPurple = Color(0xFF8B5CF6);
  static const Color chartOrange = Color(0xFFF97316);
  static const Color chartPink = Color(0xFFEC4899);
  static const Color chartTeal = Color(0xFF14B8A6);

  /// Ordered chart palette for portfolio categories.
  static const List<Color> chartPalette = [
    chartBlue,
    chartGreen,
    chartYellow,
    chartPurple,
    chartOrange,
    chartPink,
    chartTeal,
  ];

  // Social auth brand colors
  static const Color kakaoYellow = Color(0xFFFEE500);
  static const Color kakaoBrown = Color(0xFF3C1E1E);
  static const Color naverGreen = Color(0xFF03C75A);

  // Standard radii (from DESIGN.md)
  static const double radiusS = 6;
  static const double radiusM = 10;
  static const double radiusL = 12;
  static const double radiusXL = 16;
  static const double radiusFull = 9999;

  // Dot indicator
  static const Color dotActive = sky4;
  static const Color dotInactive = lightGray;

  // Interactive states
  static const double disabledOpacity = 0.4;
  static const Color focusRing = Color(0x4D20A7DB); // sky4 at 30%
}

/// Spacing scale — base unit 4px, all multiples of 4.
class WeRoboSpacing {
  WeRoboSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 28;
  static const double xxxxl = 32;

  /// Standard horizontal screen padding.
  static const EdgeInsets screenH =
      EdgeInsets.symmetric(horizontal: xxl);

  /// Bottom button area: 24px sides, 32px bottom clearance.
  static const EdgeInsets bottomButton =
      EdgeInsets.fromLTRB(xxl, 0, xxl, xxxxl);
}

/// 3-tier elevation system for visual depth.
class WeRoboElevation {
  WeRoboElevation._();

  static const List<BoxShadow> subtle = [
    BoxShadow(
      offset: Offset(0, 1),
      blurRadius: 3,
      color: Color(0x0A000000),
    ),
    BoxShadow(
      offset: Offset(0, 1),
      blurRadius: 2,
      color: Color(0x05000000),
    ),
  ];

  static const List<BoxShadow> medium = [
    BoxShadow(
      offset: Offset(0, 4),
      blurRadius: 12,
      color: Color(0x0F000000),
    ),
    BoxShadow(
      offset: Offset(0, 1),
      blurRadius: 4,
      color: Color(0x0A000000),
    ),
  ];

  static const List<BoxShadow> elevated = [
    BoxShadow(
      offset: Offset(0, 12),
      blurRadius: 32,
      color: Color(0x14000000),
    ),
    BoxShadow(
      offset: Offset(0, 4),
      blurRadius: 12,
      color: Color(0x0A000000),
    ),
  ];

  /// Dark mode shadows — stronger to compensate for dark backgrounds.
  static const List<BoxShadow> subtleDark = [
    BoxShadow(
      offset: Offset(0, 1),
      blurRadius: 3,
      color: Color(0x1F000000),
    ),
  ];

  static const List<BoxShadow> mediumDark = [
    BoxShadow(
      offset: Offset(0, 4),
      blurRadius: 12,
      color: Color(0x2E000000),
    ),
  ];

  static const List<BoxShadow> elevatedDark = [
    BoxShadow(
      offset: Offset(0, 12),
      blurRadius: 32,
      color: Color(0x3D000000),
    ),
  ];
}

/// Animation duration and curve constants.
class WeRoboMotion {
  WeRoboMotion._();

  // Durations
  static const Duration micro = Duration(milliseconds: 75);
  static const Duration short = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 350);
  static const Duration long = Duration(milliseconds: 500);
  static const Duration pageTransition = Duration(milliseconds: 400);
  static const Duration stagger = Duration(milliseconds: 80);
  static const Duration chartDraw = Duration(milliseconds: 1000);

  // Curves
  static const Curve enter = Curves.easeOut;
  static const Curve exit = Curves.easeIn;
  static const Curve move = Curves.easeInOut;
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

/// Brightness-sensitive colors — access via WeRoboThemeColors.of(context).
class WeRoboThemeColors extends ThemeExtension<WeRoboThemeColors> {
  final Color background;
  final Color surface;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;

  const WeRoboThemeColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
  });

  static const light = WeRoboThemeColors(
    background: Color(0xFFF6F7F8),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFEFF1F3),
    border: Color(0xFFCDD1D6),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF6B6B6B),
    textTertiary: Color(0xFF8E8E8E),
    accent: Color(0xFF059669),
  );

  static const dark = WeRoboThemeColors(
    background: Color(0xFF0F0F0F),
    surface: Color(0xFF1A1A1A),
    card: Color(0xFF232528),
    border: Color(0xFF363840),
    textPrimary: Color(0xFFF0F0F0),
    textSecondary: Color(0xFF999999),
    textTertiary: Color(0xFF6B6B6B),
    accent: Color(0xFF34D399),
  );

  static WeRoboThemeColors of(BuildContext context) =>
      Theme.of(context).extension<WeRoboThemeColors>()!;

  @override
  WeRoboThemeColors copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
  }) =>
      WeRoboThemeColors(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        card: card ?? this.card,
        border: border ?? this.border,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textTertiary: textTertiary ?? this.textTertiary,
        accent: accent ?? this.accent,
      );

  @override
  WeRoboThemeColors lerp(WeRoboThemeColors? other, double t) {
    if (other == null) return this;
    return WeRoboThemeColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary:
          Color.lerp(textTertiary, other.textTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}

/// Resolves baked-in light-mode colors to current brightness.
extension ThemedTextStyle on TextStyle {
  TextStyle themed(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    if (color == WeRoboColors.textPrimary) {
      return copyWith(color: tc.textPrimary);
    }
    if (color == WeRoboColors.textSecondary) {
      return copyWith(color: tc.textSecondary);
    }
    if (color == WeRoboColors.textTertiary) {
      return copyWith(color: tc.textTertiary);
    }
    return this;
  }
}

class WeRoboTheme {
  WeRoboTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: WeRoboThemeColors.light.background,
      colorScheme: ColorScheme.light(
        primary: WeRoboColors.primary,
        secondary: WeRoboColors.accent,
        surface: WeRoboThemeColors.light.surface,
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
            borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
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
            borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
          ),
          side: const BorderSide(
            color: WeRoboColors.primary,
            width: 1.5,
          ),
          textStyle: WeRoboTypography.button,
        ),
      ),
      extensions: const [WeRoboThemeColors.light],
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: WeRoboThemeColors.dark.background,
      colorScheme: ColorScheme.dark(
        primary: WeRoboColors.primary,
        secondary: const Color(0xFF34D399),
        surface: WeRoboThemeColors.dark.surface,
        error: WeRoboColors.error,
      ),
      textTheme: TextTheme(
        headlineLarge: WeRoboTypography.heading1.copyWith(
            color: WeRoboThemeColors.dark.textPrimary),
        headlineMedium: WeRoboTypography.heading2.copyWith(
            color: WeRoboThemeColors.dark.textPrimary),
        headlineSmall: WeRoboTypography.heading3.copyWith(
            color: WeRoboThemeColors.dark.textPrimary),
        bodyLarge: WeRoboTypography.body.copyWith(
            color: WeRoboThemeColors.dark.textSecondary),
        bodyMedium: WeRoboTypography.bodySmall.copyWith(
            color: WeRoboThemeColors.dark.textSecondary),
        labelLarge: WeRoboTypography.button,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WeRoboColors.primary,
          foregroundColor: WeRoboColors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
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
            borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
          ),
          side: const BorderSide(
            color: WeRoboColors.primary,
            width: 1.5,
          ),
          textStyle: WeRoboTypography.button,
        ),
      ),
      extensions: const [WeRoboThemeColors.dark],
    );
  }
}
