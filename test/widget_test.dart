import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/app.dart';
import 'package:pontimaps_app/core/config/app_config.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/routing/app_router.dart';
import 'package:pontimaps_app/core/theme/pontimaps_theme.dart';
import 'package:pontimaps_app/data/campus_cartography.dart';

void main() {
  late CampusCartography cartografia;

  setUp(() => cartografia = CampusCartography.seed());

  testWidgets('muestra la confirmación de la base cartográfica cargada', (tester) async {
    await tester.pumpWidget(
      PontiMapsApp(cartography: cartografia, initialLocation: Rutas.estado),
    );
    await tester.pumpAndSettle();

    expect(find.text('Base cartográfica cargada'), findsOneWidget);
    expect(find.text('La Pontimaps'), findsOneWidget);
    expect(find.text('Conexo'), findsOneWidget);
    expect(find.text('${cartografia.edificios.length}'), findsWidgets);
    expect(find.textContaining('Modo demostración sin conexión'), findsOneWidget);
    expect(find.textContaining('OpenStreetMap'), findsOneWidget);
    expect(find.textContaining('aproximadas'), findsNothing);
  });

  testWidgets('la app se llama PontiMaps y usa PontiMapsTheme', (tester) async {
    await tester.pumpWidget(PontiMapsApp(cartography: cartografia));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'PontiMaps');
    expect(app.theme?.colorScheme.primary, PontiMapsTheme.primary);
    expect(app.theme?.scaffoldBackgroundColor, PontiMapsTheme.background);
  });

  testWidgets('en modo en línea muestra el proyecto de Firebase', (tester) async {
    await tester.pumpWidget(
      PontiMapsApp(
        cartography: cartografia,
        config: const AppConfig(useOfflineFallback: false),
        initialLocation: Rutas.estado,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('pontimaps-puj'), findsOneWidget);
    expect(find.textContaining('Modo demostración'), findsNothing);
  });

  testWidgets('cabe en 360 × 800 dp con texto al 200 % sin desbordes', (tester) async {
    tester.view.physicalSize = const Size(LayoutMetrics.baseWidth, LayoutMetrics.baseHeight);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = LayoutMetrics.maxTextScale;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(
      PontiMapsApp(cartography: cartografia, initialLocation: Rutas.estado),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Base cartográfica cargada'), findsOneWidget);
  });
}
