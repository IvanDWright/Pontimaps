import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/config/app_config.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/theme/pontimaps_theme.dart';

void main() {
  group('PontiMapsTheme', () {
    test('usa la paleta oficial', () {
      expect(PontiMapsTheme.primary, const Color(0xFF002D72));
      expect(PontiMapsTheme.accent, const Color(0xFFF2A900));
      expect(PontiMapsTheme.background, const Color(0xFFF8F9FA));
      expect(PontiMapsTheme.surface, const Color(0xFFFFFFFF));
      final tema = PontiMapsTheme.light;
      expect(tema.colorScheme.primary, PontiMapsTheme.primary);
      expect(tema.colorScheme.secondary, PontiMapsTheme.accent);
      expect(tema.scaffoldBackgroundColor, PontiMapsTheme.background);
      expect(tema.colorScheme.surface, PontiMapsTheme.surface);
    });

    test('todo par texto/fondo cumple WCAG 2.2 · 1.4.3 (≥ 4,5:1)', () {
      final pares = <String, (Color, Color)>{
        'blanco sobre azul': (PontiMapsTheme.onPrimary, PontiMapsTheme.primary),
        'azul sobre dorado': (PontiMapsTheme.onAccent, PontiMapsTheme.accent),
        'negro sobre dorado': (PontiMapsTheme.textPrimary, PontiMapsTheme.accent),
        'texto sobre fondo': (PontiMapsTheme.textPrimary, PontiMapsTheme.background),
        'texto sobre superficie': (PontiMapsTheme.textPrimary, PontiMapsTheme.surface),
        'secundario sobre fondo': (PontiMapsTheme.textSecondary, PontiMapsTheme.background),
        'secundario sobre superficie': (PontiMapsTheme.textSecondary, PontiMapsTheme.surface),
        'azul sobre fondo': (PontiMapsTheme.primary, PontiMapsTheme.background),
        'azul sobre aviso': (PontiMapsTheme.primary, PontiMapsTheme.infoContainer),
        'texto sobre aviso': (PontiMapsTheme.textPrimary, PontiMapsTheme.infoContainer),
        'azul sobre icono': (PontiMapsTheme.primary, PontiMapsTheme.iconContainer),
        'error sobre superficie': (PontiMapsTheme.error, PontiMapsTheme.surface),
        'error sobre fondo': (PontiMapsTheme.error, PontiMapsTheme.background),
        'éxito sobre superficie': (PontiMapsTheme.success, PontiMapsTheme.surface),
        'advertencia sobre superficie': (PontiMapsTheme.warningText, PontiMapsTheme.surface),
        'advertencia sobre dorado suave': (PontiMapsTheme.warningText, PontiMapsTheme.accentContainer),
        'blanco sobre error': (PontiMapsTheme.onPrimary, PontiMapsTheme.error),
      };
      pares.forEach((nombre, par) {
        expect(PontiMapsTheme.contrastRatio(par.$1, par.$2), greaterThanOrEqualTo(4.5), reason: nombre);
      });
    });

    test('el dorado no se puede usar como texto sobre fondo claro', () {
      expect(PontiMapsTheme.contrastRatio(PontiMapsTheme.accent, PontiMapsTheme.background), lessThan(4.5));
    });

    test('la escala tipográfica es solo 22 / 16 / 12 sp', () {
      final t = PontiMapsTheme.textTheme;
      final estilos = <TextStyle?>[
        t.displayLarge, t.displayMedium, t.displaySmall,
        t.headlineLarge, t.headlineMedium, t.headlineSmall,
        t.titleLarge, t.titleMedium, t.titleSmall,
        t.bodyLarge, t.bodyMedium, t.bodySmall,
        t.labelLarge, t.labelMedium, t.labelSmall,
      ];
      final tamanos = estilos.map((e) => e!.fontSize).toSet();
      expect(tamanos, <double>{22, 16, 12});
      expect(t.titleLarge!.fontSize, 22);
      expect(t.bodyLarge!.fontSize, 16);
      expect(t.bodySmall!.fontSize, 12);
    });

    test('los botones respetan el área táctil de 48 × 48 dp', () {
      final tema = PontiMapsTheme.light;
      const minimo = Size(48, 48);
      expect(tema.filledButtonTheme.style?.minimumSize?.resolve(<WidgetState>{}), minimo);
      expect(tema.elevatedButtonTheme.style?.minimumSize?.resolve(<WidgetState>{}), minimo);
      expect(tema.outlinedButtonTheme.style?.minimumSize?.resolve(<WidgetState>{}), minimo);
      expect(tema.textButtonTheme.style?.minimumSize?.resolve(<WidgetState>{}), minimo);
      expect(tema.iconButtonTheme.style?.minimumSize?.resolve(<WidgetState>{}), minimo);
      expect(tema.materialTapTargetSize, MaterialTapTargetSize.padded);
    });
  });

  group('LayoutMetrics', () {
    test('plano acotado de 360 × 800 dp con margen de 16 y grilla de 4', () {
      expect(LayoutMetrics.baseWidth, 360);
      expect(LayoutMetrics.baseHeight, 800);
      expect(LayoutMetrics.screenMargin, 16);
      expect(LayoutMetrics.gridColumns, 4);
      expect(LayoutMetrics.minTouchTarget, 48);
    });

    test('los espaciados son múltiplos de 8', () {
      for (final valor in <double>[
        LayoutMetrics.space8,
        LayoutMetrics.space16,
        LayoutMetrics.space24,
        LayoutMetrics.space32,
        LayoutMetrics.space48,
        LayoutMetrics.screenMargin,
        LayoutMetrics.minTouchTarget,
      ]) {
        expect(LayoutMetrics.isMultipleOf8(valor), isTrue, reason: '$valor');
      }
      expect(LayoutMetrics.isMultipleOf8(12), isFalse);
    });
  });

  group('AppConfig', () {
    test('por defecto usa el modo sin conexión y el proyecto pontimaps-puj', () {
      const config = AppConfig();
      expect(config.useOfflineFallback, isTrue);
      expect(config.firebaseProjectId, 'pontimaps-puj');
      expect(config.useFirebase, isFalse);
    });

    test('fromEnvironment usa los valores por defecto cuando no hay --dart-define', () {
      final config = AppConfig.fromEnvironment();
      expect(config.useOfflineFallback, isTrue);
      expect(config.firebaseProjectId, 'pontimaps-puj');
    });

    test('copyWith, igualdad y modo en línea', () {
      const base = AppConfig();
      final enLinea = base.copyWith(useOfflineFallback: false);
      expect(enLinea.useFirebase, isTrue);
      expect(enLinea, isNot(base));
      expect(enLinea.copyWith(useOfflineFallback: true), base);
    });
  });
}
