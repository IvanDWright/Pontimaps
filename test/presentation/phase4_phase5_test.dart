import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/app.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/utils/author_hash.dart';
import 'package:pontimaps_app/data/campus_cartography.dart';
import 'package:pontimaps_app/data/consent_repository.dart';
import 'package:pontimaps_app/data/app_session.dart';
import 'package:pontimaps_app/data/location_service.dart';
import 'package:pontimaps_app/data/map_sdk_adapter.dart';
import 'package:pontimaps_app/data/reports_repository.dart';
import 'package:pontimaps_app/data/schedule_repository.dart';
import 'package:pontimaps_app/core/theme/pontimaps_theme.dart';
import 'package:pontimaps_app/models/horario_usuario.dart';
import 'package:pontimaps_app/models/reporte_comunidad.dart';
import 'package:pontimaps_app/presentation/widgets/report_detail_sheet.dart';
import 'package:pontimaps_app/presentation/widgets/report_modal_sheet.dart';

import '../helpers/test_doubles.dart';

void main() {
  late CampusCartography cartografia;

  setUp(() => cartografia = CampusCartography.seed());

  // Miércoles 18 de noviembre de 2026, 07:55 en Bogotá.
  final miercoles0755 = DateTime.utc(2026, 11, 18, 12, 55);
  final otroAutor = calcularAuthorHash('otro-usuario');
  final hashDemo = calcularAuthorHash(AppSession.uidDemo);

  /// Prueba de widget a 360 × 800 dp (texto al 200 % si [textoAl200]) que, al
  /// terminar, desmonta la app para cancelar sus temporizadores.
  void pruebaApp(
    String descripcion,
    Future<void> Function(WidgetTester tester) cuerpo, {
    bool textoAl200 = false,
  }) {
    testWidgets(descripcion, (tester) async {
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
      await cuerpo(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  Future<void> abrir(
    WidgetTester tester, {
    PerfilDemo perfil = PerfilDemo.visitante,
    DateTime? ahora,
    ReportsRepository? reportes,
    ScheduleRepository? horario,
    LocationProvider? ubicacion,
  }) async {
    await tester.pumpWidget(
      PontiMapsApp(
        cartography: cartografia,
        consentRepository: MemoryConsentRepository(const ConsentState(decision: DecisionGps.aceptado)),
        locationProvider: ubicacion,
        tileProvider: SinRedTileProvider(),
        initialProfile: perfil,
        clock: ahora == null ? null : () => ahora,
        reportsRepository: reportes,
        scheduleRepository: horario,
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder pestana(String texto) =>
      find.descendant(of: find.byType(NavigationBar), matching: find.text(texto));

  Future<void> irA(WidgetTester tester, String texto) async {
    await tester.tap(pestana(texto));
    await tester.pumpAndSettle();
  }

  /// Punto de la arista más cercana al centro inicial del mapa (siempre visible).
  LatLng puntoVisible() {
    final grafo = cartografia.grafo;
    final arista = grafo.aristaMasCercana(CampusMapView.centroCampus(cartografia), maxMetros: 500)!;
    final a = grafo.nodoPorId(arista.origenId)!.ubicacion;
    final b = grafo.nodoPorId(arista.destinoId)!.ubicacion;
    return LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2);
  }

  Future<ReporteComunidad> sembrar(
    InMemoryReportsRepository repo, {
    TipoReporte tipo = TipoReporte.fila,
    String? autor,
  }) async {
    final punto = puntoVisible();
    final arista = cartografia.grafo.aristaMasCercana(punto, maxMetros: 5)!;
    final r = await repo.publicar(
      tipo: tipo,
      ubicacion: punto,
      autorHash: autor ?? otroAutor,
      idArista: arista.id,
    );
    return r.reporte!;
  }

  group('Auth Guard en modo Visitante (candados)', () {
    pruebaApp('el FAB, «Mi próxima clase» y «Mi horario» abren el modal bloqueante', (tester) async {
      final reportes = InMemoryReportsRepository();
      await abrir(tester, reportes: reportes);

      expect(find.text('Reportar'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsWidgets);

      // FAB de reportar.
      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();
      expect(find.text('Necesitas una cuenta institucional verificada'), findsOneWidget);
      expect(find.text('Cierre de paso'), findsNothing, reason: 'no se llega al modal de reporte');
      expect(reportes.vigentes(), isEmpty);
      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();

      // Chip «Mi próxima clase».
      await tester.tap(find.text('Mi próxima clase'));
      await tester.pumpAndSettle();
      expect(find.text('Necesitas una cuenta institucional verificada'), findsOneWidget);
      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();

      // Horario desde «Más».
      await irA(tester, 'Más');
      await tester.tap(find.text('Mi horario'));
      await tester.pumpAndSettle();
      expect(find.text('Necesitas una cuenta institucional verificada'), findsOneWidget);
      expect(find.text('Aún no tienes clases. Agrega la primera y la verás en «Mi próxima clase».'),
          findsNothing);
    });

    pruebaApp('calificar un reporte con candado abre el modal y no registra el voto', (tester) async {
      final reportes = InMemoryReportsRepository();
      await sembrar(reportes);
      await abrir(tester, reportes: reportes);

      await tester.tap(find.byIcon(TipoReporte.fila.icono));
      await tester.pumpAndSettle();
      expect(find.text('Sigue ahí'), findsOneWidget);

      await tester.tap(find.text('Sigue ahí'));
      await tester.pumpAndSettle();
      expect(find.text('Necesitas una cuenta institucional verificada'), findsOneWidget);
      expect(reportes.vigentes().single.confirmaciones, 0);
    });

    pruebaApp('el selector de perfil de demostración vive en Más', (tester) async {
      await abrir(tester);
      expect(find.text('Modo visitante'), findsOneWidget);

      await irA(tester, 'Más');
      expect(find.text('Perfil de demostración'), findsOneWidget);
      expect(find.text('Visitante'), findsOneWidget);
      expect(find.text('Institucional Verificado'), findsOneWidget);

      await tester.tap(find.text('Institucional Verificado'));
      await tester.pumpAndSettle();
      await irA(tester, 'Mapa');
      expect(find.text('Modo visitante'), findsNothing);
      expect(find.byIcon(Icons.campaign_outlined), findsOneWidget, reason: 'el FAB ya no tiene candado');
    });
  });

  group('Reportes colaborativos (Path 3)', () {
    pruebaApp('el modal ofrece 3 opciones con icono y etiqueta y publica un pin anónimo', (tester) async {
      final reportes = InMemoryReportsRepository();
      await abrir(tester, perfil: PerfilDemo.verificado, reportes: reportes);

      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();

      for (final tipo in TipoReporte.values) {
        expect(find.text(tipo.etiqueta), findsOneWidget);
        expect(find.byIcon(tipo.icono), findsOneWidget);
        final zona = find.ancestor(of: find.text(tipo.etiqueta), matching: find.byType(InkWell)).first;
        expect(tester.getSize(zona).height, greaterThanOrEqualTo(LayoutMetrics.minTouchTarget));
        expect(tester.getSize(zona).width, greaterThanOrEqualTo(LayoutMetrics.minTouchTarget));
      }
      expect(
        find.descendant(of: find.byType(ReportModalSheet), matching: find.byType(TextField)),
        findsNothing,
        reason: 'sin texto libre (RF-REP-12)',
      );

      await tester.tap(find.text('Cierre de paso'));
      await tester.pumpAndSettle();

      final vigentes = reportes.vigentes();
      expect(vigentes, hasLength(1));
      expect(vigentes.single.tipo, TipoReporte.cierre);
      expect(vigentes.single.authorHash, isNull);
      expect(vigentes.single.idAristaAfectada, isNotNull, reason: 'se ajusta a la arista más cercana');
      expect(find.text('Reporte publicado: Cierre de paso.'), findsOneWidget);
      expect(find.byIcon(TipoReporte.cierre.icono), findsOneWidget, reason: 'el pin aparece en el mapa');
    });

    pruebaApp('el detalle del pin es anónimo y permite «Sigue ahí» una sola vez', (tester) async {
      final reportes = InMemoryReportsRepository();
      await sembrar(reportes);
      await abrir(tester, perfil: PerfilDemo.verificado, reportes: reportes);

      await tester.tap(find.byIcon(TipoReporte.fila.icono));
      await tester.pumpAndSettle();

      expect(find.text('Fila larga'), findsOneWidget);
      expect(find.textContaining('Reportado hace'), findsOneWidget);
      expect(find.textContaining('Vence en'), findsOneWidget);
      expect(find.text('Sigue ahí'), findsOneWidget);
      expect(find.text('Falso / Ya no está'), findsOneWidget);
      expect(find.text('Reporte anónimo de la comunidad.'), findsOneWidget);
      expect(find.textContaining(otroAutor), findsNothing);
      expect(find.textContaining(hashDemo), findsNothing);

      await tester.tap(find.text('Sigue ahí'));
      await tester.pumpAndSettle();
      expect(reportes.vigentes().single.confirmaciones, 1);
      expect(find.text('Gracias. El reporte seguirá visible más tiempo.'), findsOneWidget);

      // El aviso anterior tapa los botones hasta que se oculta solo.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sigue ahí'));
      await tester.pumpAndSettle();
      expect(reportes.vigentes().single.confirmaciones, 1);
      expect(find.text('Ya calificaste este reporte.'), findsOneWidget);
    });

    pruebaApp('el autor no califica su propio reporte', (tester) async {
      final reportes = InMemoryReportsRepository();
      await sembrar(reportes, autor: hashDemo);
      await abrir(tester, perfil: PerfilDemo.verificado, reportes: reportes);

      await tester.tap(find.byIcon(TipoReporte.fila.icono));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Falso / Ya no está'));
      await tester.pumpAndSettle();

      expect(find.text('No puedes calificar tu propio reporte.'), findsOneWidget);
      expect(reportes.vigentes().single.reportesNegativos, 0);
    });

    pruebaApp('un reporte que ya venció desaparece del mapa', (tester) async {
      var ahora = miercoles0755;
      final reportes = InMemoryReportsRepository(reloj: () => ahora);
      await sembrar(reportes);
      await abrir(tester, perfil: PerfilDemo.verificado, reportes: reportes);
      expect(find.byIcon(TipoReporte.fila.icono), findsOneWidget);

      ahora = ahora.add(const Duration(minutes: 60));
      reportes.refrescar();
      await tester.pumpAndSettle();
      expect(find.byIcon(TipoReporte.fila.icono), findsNothing);
    });

    pruebaApp('un cierre sobre la ruta activa la recalcula automáticamente', (tester) async {
      // Se busca, con un catálogo aparte, un tramo de la ruta que tenga alternativa.
      final plan = CampusCartography.seed();
      final salon = plan.buscarSalon('67-205')!;
      final origen = SimulatedLocationProvider.plazoletaCentral;
      final base = plan.calcularRutaHaciaSalon(origen, salon);
      String? idAristaCerrada;
      LatLng? puntoCierre;
      for (var i = 0; i < base.puntos.length - 1 && idAristaCerrada == null; i++) {
        final a = base.puntos[i];
        final b = base.puntos[i + 1];
        final medio = LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2);
        final arista = plan.grafo.aristaMasCercana(medio, maxMetros: 5);
        if (arista == null) continue;
        plan.grafo.aplicarReportesVigentes(<ReporteComunidad>[
          ReporteComunidad.nuevo(
            id: 'plan',
            tipo: TipoReporte.cierre,
            ubicacion: medio,
            ahora: miercoles0755,
            authorHash: otroAutor,
            idAristaAfectada: arista.id,
          ),
        ], ahora: miercoles0755);
        try {
          final alternativa = plan.calcularRutaHaciaSalon(origen, salon);
          if (!listEquals(alternativa.puntos, base.puntos)) {
            idAristaCerrada = arista.id;
            puntoCierre = medio;
          }
        } on Object catch (_) {
          // sin alternativa por este tramo: se prueba con el siguiente
        }
        plan.grafo.limpiarReportes();
      }
      expect(idAristaCerrada, isNotNull, reason: 'el catálogo real debe tener un tramo con alternativa');

      final reportes = InMemoryReportsRepository(reloj: () => miercoles0755);
      await abrir(tester, reportes: reportes, ahora: miercoles0755);

      await tester.enterText(find.byType(TextField), '67-205');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edificio 67 · Piso 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Ir'));
      await tester.pumpAndSettle();
      expect(find.text('Detener ruta'), findsOneWidget);

      final r = await reportes.publicar(
        tipo: TipoReporte.cierre,
        ubicacion: puntoCierre!,
        autorHash: otroAutor,
        idArista: idAristaCerrada,
      );
      expect(r.publicado, isTrue);
      await tester.pumpAndSettle();

      expect(find.text('Ruta actualizada por un reporte.'), findsOneWidget);
      expect(find.text('Detener ruta'), findsOneWidget, reason: 'sigue navegando por la alternativa');
      expect(tester.takeException(), isNull);
    });
  });

  group('Directorio de servicios (Path 4)', () {
    pruebaApp('lista los lugares con estado de apertura en texto y filtra por categoría', (tester) async {
      // 20:45 en Bogotá: la Cafetería La Central (hasta las 21:00) cierra pronto.
      await abrir(tester, ahora: DateTime.utc(2026, 11, 19, 1, 45));
      await irA(tester, 'Directorio');

      for (final filtro in <String>['Todos', 'Cafeterías', 'Papelerías', 'Atención', 'Bienestar']) {
        final chip = find.widgetWithText(ChoiceChip, filtro);
        expect(chip, findsOneWidget);
        expect(tester.getSize(chip).height, greaterThanOrEqualTo(LayoutMetrics.minTouchTarget));
      }
      expect(find.text('Sin datos recientes'), findsWidgets);
      expect(find.textContaining('Abierto · Abierto las 24 horas'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Cafeterías'));
      await tester.pumpAndSettle();
      expect(find.text('Cafetería La Central'), findsOneWidget);
      expect(find.textContaining('Cierra pronto · Cierra en 15 min'), findsOneWidget);
      expect(find.text('Papelería El Círculo'), findsNothing);

      // Atención al Estudiante (Edificio 21, Mo-Fr 08:00-17:00): a las 20:45 está cerrada.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Atención'));
      await tester.pumpAndSettle();
      expect(find.text('Atención al Estudiante'), findsOneWidget);
      expect(find.textContaining('Edificio 21 · Piso 1'), findsOneWidget);
      expect(find.textContaining('Cerrado · Abre mañana a las 08:00'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Bienestar'));
      await tester.pumpAndSettle();
      expect(find.text('Centro de Bienestar (Medio Universitario)'), findsOneWidget);
      expect(find.textContaining('Edificio 41 · Piso 1'), findsOneWidget);
    });

    pruebaApp('un lugar cerrado dice cuándo abre', (tester) async {
      // 03:00 en Bogotá: la Biblioteca (10:00–00:00) está cerrada.
      await abrir(tester, ahora: DateTime.utc(2026, 11, 18, 8));
      await irA(tester, 'Directorio');
      expect(find.textContaining('Cerrado · Abre a las 10:00'), findsWidgets);
    });

    pruebaApp('«Ir» lleva al mapa con el lugar elegido y el botón «Ir»', (tester) async {
      await abrir(tester, ahora: miercoles0755);
      await irA(tester, 'Directorio');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Cafeterías'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Ir').first);
      await tester.pumpAndSettle();

      expect(find.text('Cafetería La Central'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Ir'), findsOneWidget);
      expect(find.text('Evitar escaleras'), findsOneWidget);
    });

    pruebaApp('«Reportar fila» exige cuenta verificada y publica «Fila larga» anclada al lugar', (tester) async {
      final reportes = InMemoryReportsRepository(reloj: () => miercoles0755);
      await abrir(tester, reportes: reportes, ahora: miercoles0755);
      await irA(tester, 'Directorio');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Cafeterías'));
      await tester.pumpAndSettle();

      // Visitante: candado y modal bloqueante.
      expect(find.byIcon(Icons.lock_outline), findsWidgets);
      await tester.tap(find.text('Reportar fila').first);
      await tester.pumpAndSettle();
      expect(find.text('Necesitas una cuenta institucional verificada'), findsOneWidget);
      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();
      expect(reportes.vigentes(), isEmpty);

      // Verificado: el modal llega con «Fila larga» preseleccionada.
      await irA(tester, 'Más');
      await tester.tap(find.text('Institucional Verificado'));
      await tester.pumpAndSettle();
      await irA(tester, 'Directorio');
      await tester.tap(find.text('Reportar fila').first);
      await tester.pumpAndSettle();
      expect(find.text('Publicar reporte'), findsOneWidget);
      await tester.tap(find.text('Publicar reporte'));
      await tester.pumpAndSettle();

      final r = reportes.vigentes().single;
      expect(r.tipo, TipoReporte.fila);
      expect(r.idLugar, 'cafeteria-la-central');
      expect(find.text('Fila moderada'), findsOneWidget);
    });
  });

  group('Horario local y «Mi próxima clase» (Path 2)', () {
    pruebaApp('agregar una clase desde el catálogo y verla como próxima clase', (tester) async {
      final almacen = MemoryScheduleRepository();
      await abrir(
        tester,
        perfil: PerfilDemo.verificado,
        horario: almacen,
        ahora: miercoles0755,
      );

      // Sin horario: estado vacío con acción.
      await tester.tap(find.text('Mi próxima clase'));
      await tester.pumpAndSettle();
      expect(find.text('Aún no tienes clases'), findsOneWidget);
      await tester.tap(find.text('Agregar mi primera clase'));
      await tester.pumpAndSettle();
      expect(find.text('Mi horario'), findsOneWidget);
      await tester.tap(find.text('Agregar mi primera clase'));
      await tester.pumpAndSettle();

      // S24: «Guardar» está deshabilitado hasta completar el formulario.
      expect(find.text('Agregar clase'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar')).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Cálculo Diferencial');
      await tester.tap(find.widgetWithText(FilterChip, 'Mié'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Edificio 67 ·').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('67-205 ·').last);
      await tester.pumpAndSettle();

      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar')).onPressed, isNotNull);
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      // S23: la clase aparece con Edificio · Piso · Salón y queda guardada en el dispositivo.
      expect(find.text('Cálculo Diferencial'), findsOneWidget);
      expect(find.textContaining('Edificio 67 · Piso 2 · Salón 67-205'), findsOneWidget);
      expect((await almacen.cargar(AppSession.uidDemo)).single.materia, 'Cálculo Diferencial');

      // Vuelve al mapa: un toque en el chip muestra la clase y lanza la ruta.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mi próxima clase'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cálculo Diferencial · 08:00 · Empieza en 5 min'), findsOneWidget);
      expect(find.text('Edificio 67 · Piso 2'), findsOneWidget);
      expect(find.text('Salón 67-205'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Ir'));
      await tester.pumpAndSettle();
      expect(find.text('Detener ruta'), findsOneWidget);
    });

    pruebaApp('el horario de una cuenta no se muestra al cambiar a Visitante', (tester) async {
      final almacen = MemoryScheduleRepository();
      await almacen.guardar(AppSession.uidDemo, <BloqueHorario>[
        const BloqueHorario(
          id: 'b1',
          materia: 'Física',
          diaSemana: 3,
          horaInicio: 480,
          horaFin: 600,
          idEdificio: IdEdificio.ed67,
          codigoSalon: '67-205',
        ),
      ]);
      await abrir(tester, perfil: PerfilDemo.verificado, horario: almacen, ahora: miercoles0755);
      await irA(tester, 'Más');
      await tester.tap(find.text('Visitante'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mi horario'));
      await tester.pumpAndSettle();
      expect(find.text('Necesitas una cuenta institucional verificada'), findsOneWidget);
      expect(find.text('Física'), findsNothing);
      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();
      await irA(tester, 'Mapa');
      await tester.tap(find.text('Mi próxima clase'));
      await tester.pumpAndSettle();
      expect(find.text('Física'), findsNothing);
    });
  });

  group('WCAG 2.2 · 360 × 800 dp y texto al 200 %', () {
    pruebaApp('mapa con reportes, FAB y hojas: sin desbordes y áreas ≥ 48 dp', (tester) async {
      final reportes = InMemoryReportsRepository();
      await sembrar(reportes);
      await abrir(tester, perfil: PerfilDemo.verificado, reportes: reportes);

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(FloatingActionButton)).height,
          greaterThanOrEqualTo(LayoutMetrics.minTouchTarget));
      // A 200 % el chip se compacta: solo icono, «Próx. clase» y la hora.
      expect(find.text('Mi próxima clase'), findsNothing);
      expect(tester.getSize(find.widgetWithText(ActionChip, 'Próx. clase')).height,
          greaterThanOrEqualTo(LayoutMetrics.minTouchTarget));

      // Modal de reporte.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final tipo in TipoReporte.values) {
        final zona = find.ancestor(of: find.text(tipo.etiqueta), matching: find.byType(InkWell)).first;
        expect(tester.getSize(zona).height, greaterThanOrEqualTo(LayoutMetrics.minTouchTarget));
      }
      Navigator.of(tester.element(find.byType(ReportModalSheet))).pop();
      await tester.pumpAndSettle();

      // El detalle del reporte se prueba aparte: a 200 % el panel superior tapa el pin.
    }, textoAl200: true);

    pruebaApp('detalle de reporte: sin desbordes y botones ≥ 48 dp', (tester) async {
      final reporte = ReporteComunidad.nuevo(
        id: 'r1',
        tipo: TipoReporte.altaAfluencia,
        ubicacion: const LatLng(4.6285, -74.0645),
        ahora: miercoles0755,
        authorHash: otroAutor,
      ).sinAutor();
      await tester.pumpWidget(
        MaterialApp(
          theme: PontiMapsTheme.light,
          home: Scaffold(
            body: Column(
              children: <Widget>[
                const Expanded(child: SizedBox.expand()),
                ReportDetailSheet(
                  reporte: reporte,
                  ahora: miercoles0755.add(const Duration(minutes: 5)),
                  bloqueado: true,
                  onSigueAhi: () {},
                  onFalso: () {},
                  onCerrar: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Alta afluencia'), findsOneWidget);
      expect(find.text('Reportado hace 5 min'), findsOneWidget);
      expect(find.text('Vence en 55 min'), findsOneWidget);
      for (final texto in <String>['Sigue ahí', 'Falso / Ya no está']) {
        final boton = find.ancestor(of: find.text(texto), matching: find.bySubtype<ButtonStyleButton>()).first;
        expect(tester.getSize(boton).height, greaterThanOrEqualTo(LayoutMetrics.minTouchTarget));
        expect(tester.getRect(boton).bottom, lessThanOrEqualTo(LayoutMetrics.baseHeight));
      }
      expect(find.byIcon(Icons.lock_outline), findsNWidgets(2), reason: 'el visitante ve ambos con candado');
    }, textoAl200: true);


    pruebaApp('directorio y Más: sin desbordes', (tester) async {
      await abrir(tester, perfil: PerfilDemo.verificado, ahora: miercoles0755);
      await irA(tester, 'Directorio');
      expect(tester.takeException(), isNull);
      for (final boton in <Finder>[
        find.ancestor(of: find.text('Ir').first, matching: find.bySubtype<ButtonStyleButton>()).first,
        find.ancestor(of: find.text('Reportar fila').first, matching: find.bySubtype<ButtonStyleButton>()).first,
      ]) {
        expect(tester.getSize(boton).height, greaterThanOrEqualTo(LayoutMetrics.minTouchTarget));
      }
      await irA(tester, 'Más');
      expect(tester.takeException(), isNull);
      // La zona táctil del interruptor es todo el SwitchListTile (≥ 48 dp).
      await tester.scrollUntilVisible(find.byType(SwitchListTile), 100);
      expect(tester.getSize(find.byType(SwitchListTile)).height,
          greaterThanOrEqualTo(LayoutMetrics.minTouchTarget));
    }, textoAl200: true);

    pruebaApp('horario: lista y edición sin desbordes', (tester) async {
      final almacen = MemoryScheduleRepository();
      await abrir(tester, perfil: PerfilDemo.verificado, horario: almacen, ahora: miercoles0755);
      await irA(tester, 'Más');
      await tester.scrollUntilVisible(find.text('Mi horario'), 100);
      await tester.ensureVisible(find.text('Mi horario'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mi horario'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Agregar mi primera clase'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(FilterChip, 'Lun'), findsOneWidget);
      expect(tester.getSize(find.widgetWithText(FilterChip, 'Lun')).height,
          greaterThanOrEqualTo(LayoutMetrics.minTouchTarget));
    }, textoAl200: true);
  });
}
