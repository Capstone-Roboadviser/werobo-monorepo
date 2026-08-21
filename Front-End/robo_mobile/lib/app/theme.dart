import 'package:flutter/material.dart';

/// WeRobo design tokens — extracted from 캡스톤 UI/UX Figma
class WeRoboColors {
  WeRoboColors._();

  // Primary — deep navy (#0614A7), key icon color (capstone 2026-05-12).
  static const Color primary = Color(0xFF0614A7);
  static const Color primaryDark = Color(0xFF0713A7); // CTA (확인/다음)
  static const Color primaryLight = Color(0xFFEFF2F7); // pressed/secondary

  // 부 색상 — cool-tinted neutrals to harmonize with navy.
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGray = Color(0xFFE2E5EE); // cool hairline
  static const Color silver = Color(0xFF8E8E8E);
  static const Color black = Color(0xFF1A1919); // warm black

  // Surfaces (cool-tinted to harmonize with navy).
  static const Color background = Color(0xFFF7F9FC);
  static const Color surface = white;
  static const Color card = white;

  // Text
  static const Color textPrimary = black;
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textTertiary = Color(0xFF8E8E8E);

  // Status
  static const Color accent = Color(0xFF059669);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFEF4444);

  /// Hot red used by the risk gauge's high zone and (later) the home-tab
  /// loss indicator. Sourced from the UIUX-2026-05-19 spec.
  static const Color dangerRed = Color(0xFFFF0200);

  // Korean financial convention: red = gain (up), blue = loss/warning (down).
  // Values from the UIUX-2026-05-20 spec.
  static const Color gainRed = Color(0xFFFF0200);
  static const Color lossBlue = Color(0xFF267ACF);

  // Asset class colors. One distinct hue per asset class so users learn
  // each color over time. Order matches AssetClass enum (defensive to
  // aggressive). Seven-hue palette from capstone 2026-05-12 spec.
  static const Color assetCash = Color(0xFF870BE6); // 현금성자산, purple
  static const Color assetShortBond = Color(0xFF5568E3); // 단기채권, blue
  static const Color assetInfraBond = Color(0xFF85C410); // 인프라채권, green
  static const Color assetGold = Color(0xFFE6CC0B); // 금, yellow
  static const Color assetUSValue = Color(0xFF01A1D6); // 미국가치주, cyan
  static const Color assetUSGrowth = Color(0xFFFF708F); // 미국성장주, pink
  static const Color assetNewGrowth = Color(0xFFFF4141); // 신성장주, red

  // Navy brand shade aliases (tier5 = lightest, tier1 = primary). Used by
  // a few visual treatments outside the asset palette (glow color, gradient
  // backgrounds, benchmark line). New code should prefer primary or
  // primaryLight, or one of the asset class colors above.
  static const Color assetTier5 = Color(0xFFC9CEEC);
  static const Color assetTier4 = Color(0xFF969FDD);
  static const Color assetTier3 = Color(0xFF6371CE);
  static const Color assetTier2 = Color(0xFF3142BD);
  static const Color assetTier1 = primary;

  /// Ordered palette indexed by AssetClass. Use `assetColor(AssetClass)`
  /// for ergonomic lookup.
  static const List<Color> _assetPalette = [
    assetCash, // index 0, 현금성자산
    assetShortBond, // index 1, 단기채권
    assetInfraBond, // index 2, 인프라채권
    assetGold, // index 3, 금
    assetUSValue, // index 4, 미국가치주
    assetUSGrowth, // index 5, 미국성장주
    assetNewGrowth, // index 6, 신성장주
  ];

  static Color assetColor(AssetClass cls) => _assetPalette[cls.index];

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
  static const Color dotActive = primary;
  static const Color dotInactive = lightGray;

  // Interactive states
  static const double disabledOpacity = 0.4;
  static const Color focusRing = Color(0x4D0614A7); // primary @ 30%
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
  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: xxl);

  /// Bottom button area: 24px sides, 32px bottom clearance.
  static const EdgeInsets bottomButton =
      EdgeInsets.fromLTRB(xxl, 0, xxl, xxxxl);
}

/// 3-tier elevation system for visual depth.
class WeRoboElevation {
  WeRoboElevation._();

  static const List<BoxShadow> subtle = [
    BoxShadow(
      offset: Offset(0, 2),
      blurRadius: 8,
      color: Color(0x140B1F46),
    ),
    BoxShadow(
      offset: Offset(0, 0),
      blurRadius: 1,
      color: Color(0x120B1F46),
    ),
  ];

  static const List<BoxShadow> medium = [
    BoxShadow(
      offset: Offset(0, 6),
      blurRadius: 18,
      color: Color(0x1A0B1F46),
    ),
    BoxShadow(
      offset: Offset(0, 2),
      blurRadius: 5,
      color: Color(0x100B1F46),
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

  /// Card shadow that follows the active app brightness.
  static List<BoxShadow> card(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? subtleDark : subtle;

  /// Raised surface shadow that follows the active app brightness.
  static List<BoxShadow> raised(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? mediumDark : medium;

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
///
/// Custom curves use steeper slopes than Flutter built-ins for a snappier,
/// more intentional feel (Emil Kowalski / Vercel / Linear style).
class WeRoboMotion {
  WeRoboMotion._();

  // Durations
  static const Duration micro = Duration(milliseconds: 75);
  static const Duration short = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration long = Duration(milliseconds: 400);
  static const Duration pageTransition = Duration(milliseconds: 220);
  static const Duration stagger = Duration(milliseconds: 50);
  static const Duration chartDraw = Duration(milliseconds: 800);

  // Curves — custom cubics with punchier initial slopes
  static const Curve enter = Cubic(0.16, 1, 0.3, 1);
  static const Curve exit = Cubic(0.4, 0, 1, 1);
  static const Curve move = Cubic(0.4, 0, 0.2, 1);
  static const Curve emphasize = Cubic(0.34, 1.56, 0.64, 1);
  static const Curve chartReveal = Cubic(0.65, 0, 0.35, 1);

  /// Standard page route with iOS-style horizontal slide transition.
  /// On push, the incoming page slides in from the right; on pop, it
  /// slides back to the right. The outgoing page also slides slightly
  /// left during push for a parallax feel.
  ///
  /// Uses the symmetric `move` curve (not `enter`) so push and pop
  /// feel identical in speed — `enter` is decelerating, which on pop
  /// would read as a slow start before a rush.
  static Route<T> fadeRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, secAnim, child) {
        final inSlide = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: move)).animate(anim);
        final outSlide = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.25, 0),
        ).chain(CurveTween(curve: move)).animate(secAnim);
        return SlideTransition(
          position: outSlide,
          child: SlideTransition(position: inSlide, child: child),
        );
      },
      transitionDuration: pageTransition,
      reverseTransitionDuration: pageTransition,
    );
  }
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
    background: Color(0xFFF7F9FC), // near-white neutral scaffold
    surface: Color(0xFFFFFFFF), // white frames, no border
    card: Color(0xFFFFFFFF), // inset frames also white
    border: Color(0xFFDFE5EF), // visible cool hairline
    textPrimary: Color(0xFF1A1919),
    textSecondary: Color(0xFF6B6B6B),
    textTertiary: Color(0xFF8E8E8E),
    accent: Color(0xFF059669),
  );

  static const dark = WeRoboThemeColors(
    background: Color(0xFF1A1919), // warm black (was #141414)
    surface: Color(0xFF232020), // warm card surface
    card: Color(0xFF2A2625), // warm inset card
    border: Color(0xFF3A3636), // warm hairline
    textPrimary: Color(0xFFF0EEEC), // warm off-white
    textSecondary: Color(0xFFA39E99),
    textTertiary: Color(0xFF7A7470),
    accent: Color(0xFF34D399), // green stays unchanged
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
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
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
          backgroundColor: WeRoboColors.primaryDark,
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
      cardTheme: CardThemeData(
        color: WeRoboThemeColors.light.card,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x240B1F46),
        elevation: 3,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WeRoboColors.radiusXL),
          side: BorderSide(color: WeRoboThemeColors.light.border),
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
        headlineLarge: WeRoboTypography.heading1
            .copyWith(color: WeRoboThemeColors.dark.textPrimary),
        headlineMedium: WeRoboTypography.heading2
            .copyWith(color: WeRoboThemeColors.dark.textPrimary),
        headlineSmall: WeRoboTypography.heading3
            .copyWith(color: WeRoboThemeColors.dark.textPrimary),
        bodyLarge: WeRoboTypography.body
            .copyWith(color: WeRoboThemeColors.dark.textSecondary),
        bodyMedium: WeRoboTypography.bodySmall
            .copyWith(color: WeRoboThemeColors.dark.textSecondary),
        labelLarge: WeRoboTypography.button,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WeRoboColors.primaryDark,
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
      cardTheme: CardThemeData(
        color: WeRoboThemeColors.dark.card,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x52000000),
        elevation: 3,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WeRoboColors.radiusXL),
          side: BorderSide(color: WeRoboThemeColors.dark.border),
        ),
      ),
      extensions: const [WeRoboThemeColors.dark],
    );
  }
}

/// Canonical order for portfolio asset classes. Order is defensive→aggressive
/// to match the tonal palette (lightest tier = least risky).
enum AssetClass {
  cash, // 현금성자산
  shortBond, // 단기채권
  infraBond, // 인프라채권
  gold, // 금
  usValue, // 미국가치주
  usGrowth, // 미국성장주
  newGrowth, // 신성장주
}

extension AssetClassLabel on AssetClass {
  String get koLabel => switch (this) {
        AssetClass.cash => '현금성자산',
        AssetClass.shortBond => '단기채권',
        AssetClass.infraBond => '인프라채권',
        AssetClass.gold => '금',
        AssetClass.usValue => '미국가치주',
        AssetClass.usGrowth => '미국성장주',
        AssetClass.newGrowth => '신성장주',
      };
}
