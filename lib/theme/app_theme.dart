import 'package:flutter/material.dart';

/// نظام ألوان وهوية Mofradati — مأخوذ حرفياً من ملف DESIGN.md (تصميم Stitch).
///
/// المبدأ: أخضر النمو للأفعال الأساسية والتقدم، أزرق التركيز للعناصر
/// الثانوية، بنفسجي البصيرة للمسات المميزة، وخلفية Canvas فاتحة مريحة للعين.
class AppColors {
  AppColors._();

  // الألوان الأساسية من نظام التصميم
  static const Color primary = Color(0xFF006C51); // الأخضر الأساسي
  static const Color growthGreen = Color(0xFF00B98E); // أخضر النمو (تقدّم/صحيح)
  static const Color focusBlue = Color(0xFF345B8B); // أزرق التركيز
  static const Color secondary = Color(0xFF396090);
  static const Color insightPurple = Color(0xFF7C3AED); // بنفسجي البصيرة
  static const Color surface = Color(0xFFF9F9FD); // خلفية Canvas
  static const Color surfaceContainer = Color(0xFFEDEDF1);
  static const Color onSurface = Color(0xFF1A1C1F);
  static const Color onSurfaceVariant = Color(0xFF3C4A43);
  static const Color outline = Color(0xFF6C7A73);
  static const Color outlineVariant = Color(0xFFBBCAC2);

  /// تدرّج أخضر العلامة كبديل مباشر عن MaterialColor (مثل Colors.deepPurple
  /// سابقاً): الدرجة 500 هي الأخضر الأساسي #006C51، والفاتحة للخلفيات الرقيقة.
  static const MaterialColor brand = MaterialColor(0xFF006C51, {
    50: Color(0xFFE4F3EE),
    100: Color(0xFFBCE2D5),
    200: Color(0xFF90CFBA),
    300: Color(0xFF63BC9E),
    400: Color(0xFF2E9578),
    500: Color(0xFF006C51),
    600: Color(0xFF006148),
    700: Color(0xFF00523D),
    800: Color(0xFF004231),
    900: Color(0xFF002C20),
  });
}

/// ثيم التطبيق: Material 3 بألوان Mofradati وخطوط Hanken Grotesk (عناوين)
/// وInter (نصوص) كما في نظام التصميم.
class AppTheme {
  AppTheme._();

  static const String headlineFont = 'Hanken Grotesk';
  static const String bodyFont = 'Inter';

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF00B98E),
      onPrimaryContainer: Color(0xFF004231),
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFA3C9FF),
      onSecondaryContainer: Color(0xFF2C5483),
      tertiary: Color(0xFF732EE4),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFB48FFF),
      onTertiaryContainer: Color(0xFF4900A4),
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF93000A),
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      surfaceDim: Color(0xFFD9DADE),
      surfaceBright: Color(0xFFF9F9FD),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFF3F3F7),
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: Color(0xFFE8E8EC),
      surfaceContainerHighest: Color(0xFFE2E2E6),
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      inverseSurface: Color(0xFF2E3034),
      onInverseSurface: Color(0xFFF0F0F4),
      inversePrimary: Color(0xFF4BDEB0),
      surfaceTint: AppColors.primary,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    // العناوين بخط Hanken Grotesk والنصوص بخط Inter (النص العربي يسقط
    // تلقائياً إلى خط النظام لأن الخطين لاتينيان فقط).
    final textTheme = base.textTheme
        .apply(fontFamily: bodyFont)
        .copyWith(
          displayLarge: base.textTheme.displayLarge!
              .copyWith(fontFamily: headlineFont, fontWeight: FontWeight.w700),
          displayMedium: base.textTheme.displayMedium!
              .copyWith(fontFamily: headlineFont, fontWeight: FontWeight.w700),
          displaySmall: base.textTheme.displaySmall!
              .copyWith(fontFamily: headlineFont, fontWeight: FontWeight.w700),
          headlineLarge: base.textTheme.headlineLarge!
              .copyWith(fontFamily: headlineFont, fontWeight: FontWeight.w700),
          headlineMedium: base.textTheme.headlineMedium!
              .copyWith(fontFamily: headlineFont, fontWeight: FontWeight.w700),
          headlineSmall: base.textTheme.headlineSmall!
              .copyWith(fontFamily: headlineFont, fontWeight: FontWeight.w600),
          titleLarge: base.textTheme.titleLarge!
              .copyWith(fontFamily: headlineFont, fontWeight: FontWeight.w600),
        );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: headlineFont,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      // بطاقات بيضاء بزوايا كبيرة وظل ناعم (طبقات لونية بدل حدود)
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1.5,
        shadowColor: AppColors.focusBlue.withOpacity(0.18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.growthGreen,
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.growthGreen,
        linearTrackColor: AppColors.growthGreen.withOpacity(0.15),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.focusBlue, width: 2),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
