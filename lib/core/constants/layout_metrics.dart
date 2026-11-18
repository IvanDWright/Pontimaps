/// Plano acotado de PontiMaps. Todas las medidas en dp.
///
/// Regla: todo `padding`, `margin` y `SizedBox` usa únicamente múltiplos de 8
/// ([space8] … [space48]); los márgenes laterales de pantalla son [screenMargin].
abstract final class LayoutMetrics {
  /// Marco de diseño base: 360 × 800 dp.
  static const double baseWidth = 360;
  static const double baseHeight = 800;

  /// Grilla base de 4 columnas.
  static const int gridColumns = 4;

  /// Margen lateral constante de pantalla.
  static const double screenMargin = 16;

  /// Área táctil mínima (WCAG 2.2 · 2.5.8 y Material): 48 × 48 dp.
  static const double minTouchTarget = 48;

  /// Espaciados permitidos (múltiplos de 8).
  static const double space8 = 8;
  static const double space16 = 16;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space48 = 48;

  /// Radios de esquina del mockup.
  static const double radiusControl = 12;
  static const double radiusCard = 16;
  static const double radiusSheet = 24;

  /// Tamaños fijos de los elementos de marca (mockup `.brand-mark` y `.hero-map`).
  static const double brandMarkSize = 40;
  static const double heroMarkSize = 88;

  /// Escala máxima de texto que debe soportar el diseño (200 %).
  static const double maxTextScale = 2.0;

  /// `true` si [value] es múltiplo de 8 (útil en pruebas de layout).
  static bool isMultipleOf8(double value) => value % 8 == 0;
}
