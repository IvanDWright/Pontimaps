import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/app.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/routing/app_router.dart';
import 'package:pontimaps_app/data/campus_cartography.dart';
import 'package:pontimaps_app/data/consent_repository.dart';
import 'package:pontimaps_app/data/location_service.dart';

import '../helpers/test_doubles.dart';

void main() {
  late CampusCartography cartografia;

  setUp(() => cartografia = CampusCartography.seed());

  /// Marco de diseño 360 × 800 dp, con texto al 200 % si [textoAl200] es `true`.
  void configurarPantalla(WidgetTester tester, {bool textoAl200 = false}) {
    tester.view.physicalSize = const Size(LayoutMetrics.baseWidth, LayoutMetrics.baseHeight);
    tester.view.devicePixelRatio = 1;
    if (textoAl200) {
      tester.platformDispatcher.textScaleFactorTestValue = LayoutMetrics.maxTextScale;
    }
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
  }

  Future<void> abrirApp(
    WidgetTester tester, {
    ConsentRepository? consentimiento,
    LocationProvider? ubicacion,
  }) async {
    await tester.pumpWidget(
      PontiMapsApp(
        cartography: cartografia,
        consentRepository: consentimiento,
        locationProvider: ubicacion,
        tileProvider: SinRedTileProvider(),
      ),
    );
    await tester.pumpAndSettle();
  }

  MemoryConsentRepository consentimientoAceptado() => MemoryConsentRepository(
        const ConsentState(decision: DecisionGps.aceptado),
      );

  Finder barraDeBusqueda() => find.byType(TextField);

  Future<void> buscarYElegir(WidgetTester tester, String consulta, String textoResultado) async {
    await tester.enterText(barraDeBusqueda(), consulta);
    await tester.pumpAndSettle();
    await tester.tap(find.text(textoResultado));
    await tester.pumpAndSettle();
  }

  group('Fase 2 · consentimiento (Ley 1581)', () {
    testWidgets('Geolocator.requestPermission() no se invoca antes de aceptar', (tester) async {
      configurarPantalla(tester);
      final gateway = GeolocatorFalso();
      await abrirApp(tester, ubicacion: GpsLocationProvider(gateway));

      // Sin consentimiento previo el arranque termina en la pantalla de consentimiento.
      expect(find.text('Usar tu ubicación'), findsOneWidget);
      expect(find.text('Acepto activar ubicación'), findsOneWidget);
      expect(gateway.llamadasRequestPermission, 0);
      expect(gateway.llamadasStream, 0);

      await tester.tap(find.text('Acepto activar ubicación'));
      await tester.pumpAndSettle();

      expect(gateway.llamadasRequestPermission, 1);
      expect(find.text('Buscar edificio, salón o servicio'), findsOneWidget);
    });

    testWidgets('«No acepto» nunca pide el permiso y deja usar el mapa', (tester) async {
      configurarPantalla(tester);
      final gateway = GeolocatorFalso();
      await abrirApp(tester, ubicacion: GpsLocationProvider(gateway));

      await tester.tap(find.text('No acepto · Elegir origen manual'));
      await tester.pumpAndSettle();

      expect(gateway.llamadasRequestPermission, 0);
      expect(gateway.llamadasStream, 0);
      expect(find.text('Buscar edificio, salón o servicio'), findsOneWidget);
      expect(find.textContaining('Elegir punto de partida'), findsWidgets);
    });

    testWidgets('el mapa no se abre sin consentimiento respondido', (tester) async {
      configurarPantalla(tester);
      await tester.pumpWidget(
        PontiMapsApp(
          cartography: cartografia,
          tileProvider: SinRedTileProvider(),
          initialLocation: Rutas.mapa,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Usar tu ubicación'), findsOneWidget);
      expect(find.text('Buscar edificio, salón o servicio'), findsNothing);
    });

    testWidgets('con el consentimiento vigente el arranque va directo al mapa', (tester) async {
      configurarPantalla(tester);
      await abrirApp(tester, consentimiento: consentimientoAceptado());

      expect(find.text('Usar tu ubicación'), findsNothing);
      expect(find.text('Buscar edificio, salón o servicio'), findsOneWidget);
      expect(find.text('Modo visitante'), findsOneWidget);
    });
  });

  group('Fase 3 · mapa, buscador y ruta', () {
    testWidgets('la atribución de OpenStreetMap está visible en el mapa', (tester) async {
      configurarPantalla(tester);
      await abrirApp(tester, consentimiento: consentimientoAceptado());

      expect(find.text('© colaboradores de OpenStreetMap'), findsOneWidget);
    });

    testWidgets('Abrir → Buscar salón 67-205 → Ir muestra la ruta sin errores', (tester) async {
      configurarPantalla(tester);
      await abrirApp(tester, consentimiento: consentimientoAceptado());

      // Toque 1 y 2: la barra fija superior y el resultado.
      await tester.enterText(barraDeBusqueda(), '67-205');
      await tester.pumpAndSettle();
      expect(find.text('Edificio 67 · Piso 2'), findsOneWidget);
      await tester.tap(find.text('Edificio 67 · Piso 2'));
      await tester.pumpAndSettle();

      // Hoja de detalle: Edificio + Piso, ascensor, distancia y tiempo.
      expect(find.text('Salón 67-205'), findsOneWidget);
      expect(find.text('Edificio 67 · Piso 2'), findsOneWidget);
      expect(
        find.text('Acceso por ascensor disponible (múltiples ascensores)'),
        findsOneWidget,
      );
      expect(find.textContaining(' m · '), findsOneWidget);
      expect(find.text('Evitar escaleras'), findsOneWidget);

      // Toque 3: el único botón «Ir».
      expect(find.text('Ir'), findsOneWidget);
      await tester.tap(find.text('Ir'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Distancia'), findsOneWidget);
      expect(find.text('Tiempo estimado'), findsOneWidget);
      expect(find.text('Siguiente tramo'), findsOneWidget);
      expect(find.text('Detener ruta'), findsOneWidget);
    });

    testWidgets('un salón en sótano muestra Edificio y Piso con el nombre del sótano', (tester) async {
      configurarPantalla(tester);
      await abrirApp(tester, consentimiento: consentimientoAceptado());

      await tester.enterText(barraDeBusqueda(), '12-S101');
      await tester.pumpAndSettle();

      expect(find.text('Edificio 12 · Piso -1 (sótano 1)'), findsOneWidget);
    });

    testWidgets('sin resultados no inventa un edificio ni un piso', (tester) async {
      configurarPantalla(tester);
      await abrirApp(tester, consentimiento: consentimientoAceptado());

      await tester.enterText(barraDeBusqueda(), 'zzzz-999');
      await tester.pumpAndSettle();

      expect(find.text('No encontramos ese edificio o salón'), findsOneWidget);
    });

    testWidgets('la llegada a ≤ 15 m confirma Edificio y Piso', (tester) async {
      configurarPantalla(tester);
      final simulada = SimulatedLocationProvider();
      await abrirApp(tester, consentimiento: consentimientoAceptado(), ubicacion: simulada);

      await buscarYElegir(tester, '67-205', 'Edificio 67 · Piso 2');
      await tester.tap(find.text('Ir'));
      await tester.pumpAndSettle();
      expect(find.text('Detener ruta'), findsOneWidget);

      final edificio = cartografia.edificioPorNumero(67)!;
      final entrada = cartografia.entradasDe(edificio.id).first;
      simulada.moverA(entrada.ubicacion);
      await tester.pumpAndSettle();

      expect(find.text('Llegaste'), findsOneWidget);
      expect(find.text('Edificio 67 · Piso 2'), findsOneWidget);

      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      expect(find.text('Llegaste'), findsNothing);
    });
  });

  group('Revocar el GPS (RF-PER-04 y RF-PER-05)', () {
    testWidgets('pausar el GPS cancela el flujo y permite elegir un origen manual', (tester) async {
      configurarPantalla(tester);
      final espia = UbicacionEspia(
        PosicionUsuario(SimulatedLocationProvider.plazoletaCentral, precisionMetros: 3),
      );
      await abrirApp(tester, consentimiento: consentimientoAceptado(), ubicacion: espia);

      expect(espia.suscripciones, 1);
      expect(espia.cancelaciones, 0);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(espia.cancelaciones, 1, reason: 'revocar cancela el flujo de posiciones');
      expect(find.textContaining('Ubicación apagada'), findsOneWidget);

      // Sin GPS la app sigue: se busca, se elige el origen a mano y se traza la ruta.
      await buscarYElegir(tester, '67-205', 'Edificio 67 · Piso 2');
      expect(find.textContaining('Elige tu punto de partida'), findsWidgets);

      await tester.tap(find.text('Ir'));
      await tester.pumpAndSettle();
      expect(find.text('Elige tu punto de partida'), findsOneWidget);

      await tester.tap(find.textContaining('Edificio 2').first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Detener ruta'), findsOneWidget);
      expect(espia.solicitudesPermiso, 0);
    });
  });

  group('WCAG 2.2 · 360 × 800 dp y texto al 200 %', () {
    testWidgets('PermissionScreen: sin desbordes y botones ≥ 48 dp', (tester) async {
      configurarPantalla(tester, textoAl200: true);
      await abrirApp(tester);

      expect(tester.takeException(), isNull);
      for (final boton in <Finder>[
        find.widgetWithText(FilledButton, 'Acepto activar ubicación'),
        find.widgetWithText(OutlinedButton, 'No acepto · Elegir origen manual'),
      ]) {
        final tamano = tester.getSize(boton);
        expect(tamano.height, greaterThanOrEqualTo(LayoutMetrics.minTouchTarget));
        expect(tamano.width, greaterThanOrEqualTo(LayoutMetrics.minTouchTarget));
      }
    });

    testWidgets('mapa, detalle y ruta: sin desbordes y controles ≥ 48 dp', (tester) async {
      configurarPantalla(tester, textoAl200: true);
      await abrirApp(tester, consentimiento: consentimientoAceptado());

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TextField)).height,
          greaterThanOrEqualTo(LayoutMetrics.minTouchTarget));
      expect(tester.getSize(find.byType(Switch)).height,
          greaterThanOrEqualTo(LayoutMetrics.minTouchTarget));

      await buscarYElegir(tester, '67-205', 'Edificio 67 · Piso 2');
      expect(tester.takeException(), isNull);
      // «Ir» y el interruptor de escaleras quedan visibles sin desplazarse.
      final ir = find.widgetWithText(FilledButton, 'Ir');
      expect(ir, findsOneWidget);
      expect(tester.getSize(ir).height, greaterThanOrEqualTo(LayoutMetrics.minTouchTarget));
      expect(tester.getRect(ir).bottom, lessThanOrEqualTo(LayoutMetrics.baseHeight));
      final interruptor = find.byType(SwitchListTile);
      expect(tester.getSize(interruptor).height,
          greaterThanOrEqualTo(LayoutMetrics.minTouchTarget));

      await tester.tap(ir);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final detener = find.widgetWithText(OutlinedButton, 'Detener ruta');
      expect(detener, findsOneWidget);
      expect(tester.getSize(detener).height, greaterThanOrEqualTo(LayoutMetrics.minTouchTarget));
      expect(tester.getRect(detener).bottom, lessThanOrEqualTo(LayoutMetrics.baseHeight));
    });
  });
}
