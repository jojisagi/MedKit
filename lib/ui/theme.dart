import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/profile_colors.dart';

/// Mundo visual: señalética hospitalaria. Muro claro, placas azul marino,
/// una línea de color por integrante de la familia. El rojo solo significa
/// omitida, caducada o caja equivocada.
abstract final class Palette {
  static const wall = Color(0xFFF4F6F3);
  static const wallDeep = Color(0xFFE8ECE7);
  static const panel = Color(0xFFFFFFFF);
  static const ink = Color(0xFF14213D);
  static const inkSoft = Color(0xFF4A5670);
  static const inkFaint = Color(0xFF7D879A);
  static const rule = Color(0xFFD5DBD4);
  static const plate = Color(0xFF14213D);
  static const plateRaised = Color(0xFF1E2E52);
  static const onPlate = Color(0xFFFFFFFF);
  static const onPlateSoft = Color(0xFFB9C3D9);

  static const danger = Color(0xFFC8322C);
  static const dangerWash = Color(0xFFFBE9E7);
  static const caution = Color(0xFF9A6200);
  static const cautionWash = Color(0xFFFFF3D6);
  static const cautionLine = Color(0xFFF2B705);
  static const ok = Color(0xFF1F7A5A);

  /// Colores de zona por persona: ver `domain/profile_colors.dart` (10 tonos, ΔE ≥ 15 entre sí).
  static final zones = <Color>[for (final c in profilePalette) Color(c.argb)];
  static final zoneNames = <String>[for (final c in profilePalette) c.name];
}

/// Peso real del eje variable (Flutter no siempre lo deriva de FontWeight).
TextStyle _w(double size, double weight, {double height = 1.3, double spacing = 0, Color? color}) => TextStyle(
  fontFamily: 'Atkinson',
  fontSize: size,
  height: height,
  letterSpacing: spacing,
  color: color,
  fontWeight: FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
  fontVariations: [FontVariation.weight(weight)],
);

const tabular = [FontFeature.tabularFigures()];

TextStyle numerals(TextStyle s) => s.copyWith(fontFeatures: tabular);

TextTheme _textTheme(Color ink, Color soft) => TextTheme(
  displayLarge: _w(56, 700, height: 1.0, spacing: -1.2, color: ink),
  displayMedium: _w(44, 700, height: 1.05, spacing: -0.8, color: ink),
  displaySmall: _w(34, 700, height: 1.1, spacing: -0.4, color: ink),
  headlineLarge: _w(30, 700, height: 1.15, spacing: -0.3, color: ink),
  headlineMedium: _w(26, 700, height: 1.2, spacing: -0.2, color: ink),
  headlineSmall: _w(22, 700, height: 1.25, color: ink),
  titleLarge: _w(20, 700, height: 1.25, color: ink),
  titleMedium: _w(17, 650, height: 1.3, color: ink),
  titleSmall: _w(15, 650, height: 1.3, color: ink),
  bodyLarge: _w(17, 400, height: 1.45, color: ink),
  bodyMedium: _w(16, 400, height: 1.45, color: soft),
  bodySmall: _w(14, 400, height: 1.4, color: soft),
  labelLarge: _w(16, 650, height: 1.2, spacing: 0.1, color: ink),
  labelMedium: _w(14, 600, height: 1.2, spacing: 0.2, color: soft),
  labelSmall: _w(12.5, 600, height: 1.2, spacing: 0.4, color: soft),
);

/// Tokens que Material no modela.
@immutable
class SignTokens extends ThemeExtension<SignTokens> {
  final Color wall, panel, ink, inkSoft, inkFaint, rule, plate, onPlate, onPlateSoft;
  final Color danger, dangerWash, caution, cautionWash;

  const SignTokens({
    required this.wall,
    required this.panel,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.rule,
    required this.plate,
    required this.onPlate,
    required this.onPlateSoft,
    required this.danger,
    required this.dangerWash,
    required this.caution,
    required this.cautionWash,
  });

  static const light = SignTokens(
    wall: Palette.wall,
    panel: Palette.panel,
    ink: Palette.ink,
    inkSoft: Palette.inkSoft,
    inkFaint: Palette.inkFaint,
    rule: Palette.rule,
    plate: Palette.plate,
    onPlate: Palette.onPlate,
    onPlateSoft: Palette.onPlateSoft,
    danger: Palette.danger,
    dangerWash: Palette.dangerWash,
    caution: Palette.caution,
    cautionWash: Palette.cautionWash,
  );

  /// Noche: el pasillo con la luz baja. Placas siguen azul marino, el muro se oscurece.
  static const dark = SignTokens(
    wall: Color(0xFF0D1424),
    panel: Color(0xFF151F35),
    ink: Color(0xFFEFF2F8),
    inkSoft: Color(0xFFB4BDD0),
    inkFaint: Color(0xFF8792A8),
    rule: Color(0xFF2A3655),
    plate: Color(0xFF1E2E52),
    onPlate: Color(0xFFFFFFFF),
    onPlateSoft: Color(0xFFB9C3D9),
    danger: Color(0xFFFF8A80),
    dangerWash: Color(0xFF3A1A1C),
    caution: Color(0xFFFFC94D),
    cautionWash: Color(0xFF332A12),
  );

  @override
  SignTokens copyWith() => this;

  @override
  SignTokens lerp(ThemeExtension<SignTokens>? other, double t) => t < 0.5 ? this : (other as SignTokens? ?? this);
}

extension SignContext on BuildContext {
  SignTokens get sign => Theme.of(this).extension<SignTokens>()!;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

/// En oscuro, los colores de zona se aclaran para mantener contraste.
Color zoneOn(BuildContext context, Color zone) => context.isDark ? Color.lerp(zone, Colors.white, 0.35)! : zone;

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final t = dark ? SignTokens.dark : SignTokens.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: dark ? const Color(0xFFB8C8F0) : Palette.ink,
    onPrimary: dark ? Palette.ink : Colors.white,
    primaryContainer: dark ? const Color(0xFF2A3D6B) : const Color(0xFFDCE3F2),
    onPrimaryContainer: dark ? Colors.white : Palette.ink,
    secondary: dark ? const Color(0xFF7FD1AE) : Palette.ok,
    onSecondary: dark ? Palette.ink : Colors.white,
    secondaryContainer: dark ? const Color(0xFF1C3D33) : const Color(0xFFD7EEE4),
    onSecondaryContainer: dark ? const Color(0xFFCFF2E2) : const Color(0xFF0E3F2E),
    tertiary: t.caution,
    onTertiary: Colors.white,
    error: t.danger,
    onError: dark ? Palette.ink : Colors.white,
    errorContainer: t.dangerWash,
    onErrorContainer: dark ? const Color(0xFFFFDAD6) : const Color(0xFF7A1B16),
    surface: t.wall,
    onSurface: t.ink,
    onSurfaceVariant: t.inkSoft,
    surfaceContainerLowest: t.panel,
    surfaceContainerLow: t.panel,
    surfaceContainer: dark ? const Color(0xFF18233B) : const Color(0xFFEEF1ED),
    surfaceContainerHigh: dark ? const Color(0xFF1C2842) : Palette.wallDeep,
    surfaceContainerHighest: dark ? const Color(0xFF223050) : const Color(0xFFDFE4DE),
    outline: dark ? const Color(0xFF55627F) : const Color(0xFF8A94A6),
    outlineVariant: t.rule,
    inverseSurface: dark ? const Color(0xFFEFF2F8) : Palette.ink,
    onInverseSurface: dark ? Palette.ink : Colors.white,
    inversePrimary: dark ? Palette.ink : const Color(0xFFB8C8F0),
    shadow: Colors.black,
    scrim: Colors.black,
  );
  final text = _textTheme(t.ink, t.inkSoft);
  final shape12 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  const minTap = Size(48, 52);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: 'Atkinson',
    textTheme: text,
    scaffoldBackgroundColor: t.wall,
    extensions: [t],
    visualDensity: VisualDensity.standard,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: t.wall,
      foregroundColor: t.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.panel,
      surfaceTintColor: Colors.transparent,
      indicatorColor: dark ? const Color(0xFF2A3D6B) : const Color(0xFFDCE3F2),
      height: 72,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => _w(
          13,
          s.contains(WidgetState.selected) ? 700 : 550,
          color: s.contains(WidgetState.selected) ? t.ink : t.inkSoft,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(size: 26, color: s.contains(WidgetState.selected) ? t.ink : t.inkSoft),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: minTap,
        shape: shape12,
        textStyle: text.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: minTap,
        shape: shape12,
        foregroundColor: t.ink,
        side: BorderSide(color: scheme.outline, width: 1.25),
        textStyle: text.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: t.ink, textStyle: text.labelLarge),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: t.plate,
      foregroundColor: t.onPlate,
      extendedTextStyle: _w(17, 700, color: t.onPlate),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      highlightElevation: 5,
      extendedSizeConstraints: const BoxConstraints.tightFor(height: 64),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.panel,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: _w(16, 500, color: t.inkSoft),
      floatingLabelStyle: _w(15, 650, color: t.ink),
      helperStyle: _w(13.5, 400, color: t.inkSoft),
      errorStyle: _w(13.5, 600, color: t.danger),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: t.rule),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: t.rule, width: 1.25),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: t.danger, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: _w(15, 600, color: t.ink),
      side: BorderSide(color: t.rule, width: 1.25),
      backgroundColor: t.panel,
      selectedColor: dark ? const Color(0xFF2A3D6B) : const Color(0xFFDCE3F2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(48, 52),
        textStyle: text.labelLarge,
        selectedBackgroundColor: dark ? const Color(0xFF2A3D6B) : const Color(0xFFDCE3F2),
        selectedForegroundColor: t.ink,
        side: BorderSide(color: t.rule, width: 1.25),
        shape: shape12,
      ),
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: 12,
      titleTextStyle: text.titleMedium,
      subtitleTextStyle: text.bodyMedium,
      iconColor: t.inkSoft,
    ),
    dividerTheme: DividerThemeData(color: t.rule, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.plate,
      contentTextStyle: _w(16, 500, color: t.onPlate),
      actionTextColor: const Color(0xFFFFD873),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: text.headlineSmall,
      contentTextStyle: text.bodyLarge,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.panel,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Palette.ok : null),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: scheme.primary,
      selectionColor: scheme.primary.withValues(alpha: 0.22),
      selectionHandleColor: scheme.primary,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: PredictiveBackPageTransitionsBuilder()},
    ),
  );
}
