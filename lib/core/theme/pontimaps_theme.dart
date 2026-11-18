import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';

/// Tema oficial de PontiMaps, tomado del mockup `index.css`.
///
/// * Paleta institucional: Azul Javeriana `#002D72`, Dorado `#F2A900`,
///   fondo `#F8F9FA`, superficies `#FFFFFF`.
/// * Contraste WCAG 2.2 · 1.4.3 ≥ 4,5:1 para todo texto (verificado en
///   `test/core/pontimaps_theme_test.dart`). **El dorado nunca se usa como
///   color de texto sobre fondo claro** (solo 1,9:1): únicamente como relleno
///   con texto azul oscuro o negro.
/// * Escala tipográfica de tres tamaños: título 22 sp, cuerpo 16 sp, notas 12 sp.
/// * Zonas táctiles mínimas de 48 × 48 dp en todos los controles.
abstract final class PontiMapsTheme {
  // --- Paleta ---------------------------------------------------------------
  static const Color primary = Color(0xFF002D72);
  static const Color primaryDark = Color(0xFF001F52);
  static const Color accent = Color(0xFFF2A900);
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);

  /// Texto sobre [primary].
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Texto sobre [accent] (6,5:1). También vale `#121212` (9,3:1).
  static const Color onAccent = Color(0xFF002D72);

  static const Color textPrimary = Color(0xFF121212);

  /// Texto secundario (≥ 5,9:1 sobre fondo y superficie).
  static const Color textSecondary = Color(0xFF526276);

  /// Bordes y divisores (no son texto).
  static const Color border = Color(0xFFCCD5DF);
  static const Color divider = Color(0xFFE5E9ED);

  static const Color error = Color(0xFFA32017);
  static const Color success = Color(0xFF246B36);

  /// Texto de advertencia (≥ 5,5:1 sobre [accentContainer] y [surface]).
  static const Color warningText = Color(0xFF8A5A00);

  /// Rellenos suaves del mockup (`.quick-class`, `.info-card`, `.place-icon`).
  static const Color accentContainer = Color(0xFFFFF8DF);
  static const Color infoContainer = Color(0xFFEAF0F7);
  static const Color iconContainer = Color(0xFFE7EDF5);

  // --- Tipografía -----------------------------------------------------------
  static const double titleSize = 22;
  static const double bodySize = 16;
  static const double noteSize = 12;

  /// Contraste WCAG 2.x entre dos colores (1 a 21).
  static double contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final lighter = la > lb ? la : lb;
    final darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }

  static const TextStyle _title = TextStyle(
    fontSize: titleSize,
    height: 1.25,
    fontWeight: FontWeight.w800,
    color: primary,
    letterSpacing: -0.4,
  );
  static const TextStyle _bodyStrong = TextStyle(
    fontSize: bodySize,
    height: 1.4,
    fontWeight: FontWeight.w700,
    color: primary,
  );
  static const TextStyle _body = TextStyle(
    fontSize: bodySize,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );
  static const TextStyle _note = TextStyle(
    fontSize: noteSize,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  /// Las 15 variantes de Material se reducen a 22 / 16 / 12 sp.
  static const TextTheme textTheme = TextTheme(
    displayLarge: _title,
    displayMedium: _title,
    displaySmall: _title,
    headlineLarge: _title,
    headlineMedium: _title,
    headlineSmall: _title,
    titleLarge: _title,
    titleMedium: _bodyStrong,
    titleSmall: _bodyStrong,
    bodyLarge: _body,
    bodyMedium: _body,
    bodySmall: _note,
    labelLarge: TextStyle(
      fontSize: bodySize,
      fontWeight: FontWeight.w800,
      color: primary,
    ),
    labelMedium: _note,
    labelSmall: _note,
  );

  static const ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: iconContainer,
    onPrimaryContainer: primary,
    secondary: accent,
    onSecondary: onAccent,
    secondaryContainer: accentContainer,
    onSecondaryContainer: primary,
    tertiary: success,
    onTertiary: onPrimary,
    error: error,
    onError: onPrimary,
    surface: surface,
    onSurface: textPrimary,
    onSurfaceVariant: textSecondary,
    outline: border,
    outlineVariant: divider,
    surfaceContainerLowest: surface,
    surfaceContainerLow: background,
    surfaceContainer: background,
    surfaceContainerHigh: iconContainer,
    surfaceContainerHighest: iconContainer,
  );

  static const Size _minTouchSize = Size(
    LayoutMetrics.minTouchTarget,
    LayoutMetrics.minTouchTarget,
  );

  static final RoundedRectangleBorder _controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(LayoutMetrics.radiusControl),
  );

  /// Tema claro de la app.
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      dividerColor: divider,
      focusColor: accent,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: _title,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: _minTouchSize,
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: _controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: _minTouchSize,
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: _controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: _minTouchSize,
          foregroundColor: primary,
          backgroundColor: surface,
          side: const BorderSide(color: Color(0xFFBDC9D8)),
          shape: _controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: _minTouchSize,
          foregroundColor: primary,
          shape: _controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: _minTouchSize,
          foregroundColor: primary,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccent,
        elevation: 4,
        extendedTextStyle: TextStyle(
          fontSize: noteSize,
          fontWeight: FontWeight.w800,
          color: onAccent,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: LayoutMetrics.space16,
          vertical: LayoutMetrics.space16,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LayoutMetrics.radiusControl),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LayoutMetrics.radiusControl),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LayoutMetrics.radiusControl),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LayoutMetrics.radiusControl),
          borderSide: const BorderSide(color: error),
        ),
        errorStyle: textTheme.bodySmall?.copyWith(color: error),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LayoutMetrics.radiusCard),
          side: const BorderSide(color: Color(0xFFDCE2E8)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primary,
        side: const BorderSide(color: border),
        labelStyle: textTheme.bodySmall,
        shape: const StadiumBorder(),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(LayoutMetrics.radiusSheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LayoutMetrics.radiusSheet),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: onPrimary),
        behavior: SnackBarBehavior.floating,
        shape: _controlShape,
      ),
      dividerTheme: const DividerThemeData(color: divider, space: 1),
    );
  }
}
