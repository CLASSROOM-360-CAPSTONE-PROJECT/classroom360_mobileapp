import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/presence.dart';

/// The same palette as the web app (`web/src/index.css`): ink navy for structure, brass for the
/// key-tag motif, and green / amber / rose for status. Nothing here is invented for the phone.
class Palette {
  static const canvas = Color(0xFFEDF0F5);
  static const ink950 = Color(0xFF0B1524);
  static const ink900 = Color(0xFF111F33);
  static const ink800 = Color(0xFF1A2C45);
  static const ink700 = Color(0xFF263D5C);
  static const ink600 = Color(0xFF3A5578);
  static const ink500 = Color(0xFF5A7396);
  static const ink400 = Color(0xFF8499B6);
  static const ink300 = Color(0xFFA9B8CD);
  static const ink200 = Color(0xFFCFD8E5);
  static const ink100 = Color(0xFFE6EBF2);
  static const ink50 = Color(0xFFF4F6FA);

  static const brass700 = Color(0xFF7D5112);
  static const brass600 = Color(0xFF9A6516);
  static const brass500 = Color(0xFFB7791F);
  static const brass400 = Color(0xFFD29A3F);
  static const brass300 = Color(0xFFE3B96A);
  static const brass200 = Color(0xFFEFD9AC);
  static const brass100 = Color(0xFFF7EBCF);
  static const brass50 = Color(0xFFFBF5E6);

  static const rose50 = Color(0xFFFFF1F2);
  static const rose200 = Color(0xFFFECDD3);
  static const rose300 = Color(0xFFFDA4AF);
  static const rose400 = Color(0xFFFB7185);
  static const rose700 = Color(0xFFBE123C);
  static const rose800 = Color(0xFF9F1239);

  static const emerald100 = Color(0xFFD1FAE5);
  static const emerald400 = Color(0xFF34D399);
  static const emerald800 = Color(0xFF065F46);

  static const amber100 = Color(0xFFFEF3C7);
  static const amber400 = Color(0xFFFBBF24);
  static const amber800 = Color(0xFF92400E);

  /// the cabinet's steel: a locker door runs from [ink800] at the top to this at the bottom
  static const steelDeep = Color(0xFF16273E);
}

/// The three type families, bundled with the app (`assets/fonts`, SIL Open Font License) so the phone
/// shows the same letters as the web app without needing a network.
class Fonts {
  static const sans = 'IBMPlexSans';
  static const condensed = 'IBMPlexSansCondensed';
  static const mono = 'IBMPlexMono';
}

/// Titles, figures and door numbers: the condensed face.
TextStyle displayStyle(double size, {Color color = Palette.ink900, FontWeight weight = FontWeight.w600, double? height, double letterSpacing = 0}) =>
    TextStyle(fontFamily: Fonts.condensed, fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: letterSpacing);

/// Room codes, times and digits: the monospaced face.
TextStyle monoStyle(double size, {Color color = Palette.ink900, FontWeight weight = FontWeight.w500, double? height, double letterSpacing = 0}) =>
    TextStyle(fontFamily: Fonts.mono, fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: letterSpacing);

/// Running text.
TextStyle bodyStyle(double size, {Color color = Palette.ink800, FontWeight weight = FontWeight.w400, double? height}) =>
    TextStyle(fontFamily: Fonts.sans, fontSize: size, fontWeight: weight, color: color, height: height);

/// True when the person asked their phone for less motion; every animation in the app checks it.
bool motionReduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

class ToneColors {
  const ToneColors(this.background, this.foreground);
  final Color background;
  final Color foreground;
}

ToneColors toneColors(Tone tone) {
  switch (tone) {
    case Tone.good:
      return const ToneColors(Palette.emerald100, Palette.emerald800);
    case Tone.warn:
      return const ToneColors(Palette.amber100, Palette.amber800);
    case Tone.bad:
      return const ToneColors(Color(0xFFFFE4E6), Palette.rose800);
    case Tone.brass:
      return const ToneColors(Palette.brass50, Palette.brass700);
    case Tone.neutral:
      return const ToneColors(Palette.ink100, Palette.ink700);
  }
}

/// The colour of the small lamp that goes with a tone: green, amber, red, brass, or dim steel.
Color toneLamp(Tone tone) {
  switch (tone) {
    case Tone.good:
      return Palette.emerald400;
    case Tone.warn:
      return Palette.amber400;
    case Tone.bad:
      return Palette.rose400;
    case Tone.brass:
      return Palette.brass400;
    case Tone.neutral:
      return Palette.ink400;
  }
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.ink800,
    brightness: Brightness.light,
  ).copyWith(
    primary: Palette.ink800,
    onPrimary: Colors.white,
    secondary: Palette.brass500,
    onSecondary: Colors.white,
    tertiary: Palette.brass500,
    surface: Colors.white,
    onSurface: Palette.ink900,
    outline: Palette.ink300,
    outlineVariant: Palette.ink200,
    error: Palette.rose700,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: Fonts.sans);
  final buttonText = bodyStyle(15.5, weight: FontWeight.w600);
  return base.copyWith(
    scaffoldBackgroundColor: Palette.canvas,
    textTheme: base.textTheme.apply(bodyColor: Palette.ink900, displayColor: Palette.ink900),
    splashColor: Palette.brass200.withValues(alpha: 0.35),
    highlightColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: Palette.ink900,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: displayStyle(22, color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Palette.ink200),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titleTextStyle: displayStyle(22),
      contentTextStyle: bodyStyle(15, color: Palette.ink700, height: 1.4),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Palette.ink200,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.ink900,
      contentTextStyle: bodyStyle(14, color: Colors.white, height: 1.35),
      actionTextColor: Palette.brass300,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Palette.ink200)),
      textStyle: bodyStyle(15, color: Palette.ink900),
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: Palette.brass500,
      textColor: Colors.white,
      textStyle: bodyStyle(11, color: Colors.white, weight: FontWeight.w700),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Palette.brass500),
    dividerTheme: const DividerThemeData(color: Palette.ink100, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      labelStyle: bodyStyle(15, color: Palette.ink500),
      floatingLabelStyle: bodyStyle(14, color: Palette.ink800, weight: FontWeight.w600),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Palette.ink300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Palette.ink300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Palette.brass500, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Palette.rose700)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Palette.rose700, width: 2)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.ink900,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Palette.ink200,
        disabledForegroundColor: Palette.ink400,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: buttonText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.ink800,
        disabledForegroundColor: Palette.ink400,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: buttonText,
        side: const BorderSide(color: Palette.ink300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Palette.ink800,
        minimumSize: const Size(48, 48),
        textStyle: buttonText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

/// A page route that fades in while rising a few pixels, used for every page the app pushes so they arrive
/// the same way. With reduced motion it simply appears.
Route<T> softRoute<T>(WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondary) => builder(context),
    transitionsBuilder: (context, animation, secondary, child) {
      if (motionReduced(context)) return child;
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero).animate(curved), child: child),
      );
    },
  );
}
