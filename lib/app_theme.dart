import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const Color primaryColor = Color(0xFF298E4D); // Official Green
  static const Color accentColor = Color(0xFFFA9527); // Official Orange
  static const Color backgroundColor = Color(0xFFF9FAFB);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textBody = Color(0xFF374151);
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color lightBorderColor = Color(0xFFF3F4F6);
  static const Color shadowColor = Color(
    0x0A000000,
  ); // 0.04 opacity black approx

  // Functional Colors
  static const Color success = Color(0xFF10B981);
  static const Color info = Color(0xFF3B82F6);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color teal = Color(0xFF06B6D4);
  static const Color lightGreen = Color(0xFF8BC34A);

  // Spacing
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;
  static const double spacing2XL = 40.0;
  static const double spacing3XL = 48.0;

  // Responsive Padding
  static const EdgeInsets mobilePadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 16,
  );
  static const EdgeInsets tabletPadding = EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 20,
  );
  static const EdgeInsets desktopPadding = EdgeInsets.symmetric(
    horizontal: 32,
    vertical: 24,
  );

  static EdgeInsets getResponsivePadding(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    if (width >= 1200) return desktopPadding;
    if (width >= 768) return tabletPadding;
    return mobilePadding;
  }

  // Responsive Gaps
  static const double mobileGap = 16.0;
  static const double tabletGap = 20.0;
  static const double desktopGap = 24.0;

  static double getResponsiveGap(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    if (width >= 1200) return desktopGap;
    if (width >= 768) return tabletGap;
    return mobileGap;
  }

  // Border Radius
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;
  static const double borderRadiusXLarge = 20.0;

  // ---------------------------------------------------------------------------
  // Typography — single source of truth for the entire app.
  // All text styles use Outfit via the global textTheme. Use these tokens
  // everywhere instead of calling GoogleFonts.outfit(...) ad-hoc.
  // ---------------------------------------------------------------------------

  // Display / Hero
  static TextStyle get displayLarge => GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    color: textPrimary,
  );
  static TextStyle get displayMedium => GoogleFonts.outfit(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: textPrimary,
  );

  // Headings
  static TextStyle get headingXL => GoogleFonts.outfit(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: textPrimary,
  );
  static TextStyle get headingLG => GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: textPrimary,
  );
  static TextStyle get headingMD => GoogleFonts.outfit(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );
  static TextStyle get headingSM => GoogleFonts.outfit(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );

  // Body
  static TextStyle get bodyLG => GoogleFonts.outfit(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: textBody,
  );
  static TextStyle get bodyMD => GoogleFonts.outfit(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: textBody,
  );
  static TextStyle get bodySM => GoogleFonts.outfit(
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    color: textBody,
  );

  // Labels / UI
  static TextStyle get labelLG => GoogleFonts.outfit(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: textSecondary,
  );
  static TextStyle get labelMD => GoogleFonts.outfit(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    color: textSecondary,
  );
  static TextStyle get labelSM => GoogleFonts.outfit(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: textSecondary,
  );

  // Values / Stats (big numbers)
  static TextStyle get statValue => GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: textPrimary,
  );
  static TextStyle get statValueSM => GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: textPrimary,
  );

  // Caption / Hint
  static TextStyle get hint => GoogleFonts.outfit(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );

  // Button
  static TextStyle get button => GoogleFonts.outfit(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  // Table header / column
  static TextStyle get tableHeader => GoogleFonts.outfit(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: textSecondary,
    letterSpacing: 0.5,
  );
  static TextStyle get tableCell => GoogleFonts.outfit(
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: textBody,
  );

  // Legacy aliases — keep these so existing const TextStyle refs still compile
  static TextStyle get heading => headingXL;
  static TextStyle get subHeading => headingMD;
  static TextStyle get body => bodyMD;
  static TextStyle get caption => hint;

  static ThemeData get lightTheme {
    // Outfit is our single brand font. GoogleFonts.outfitTextTheme() applies it
    // to every Flutter TextTheme slot, so even raw Text() widgets without an
    // explicit style automatically render in Outfit.
    final TextTheme outfitTextTheme = GoogleFonts.outfitTextTheme(
      ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: Colors.white,
      cardColor: cardColor,
      textTheme: outfitTextTheme,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        surface: cardColor,
        error: error,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: NoTransitionsBuilder(),
          TargetPlatform.iOS: NoTransitionsBuilder(),
          TargetPlatform.windows: NoTransitionsBuilder(),
          TargetPlatform.macOS: NoTransitionsBuilder(),
          TargetPlatform.linux: NoTransitionsBuilder(),
          TargetPlatform.fuchsia: NoTransitionsBuilder(),
        },
      ),
    );
  }

  // Shadow
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 15,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.02),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
}

class NoTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
