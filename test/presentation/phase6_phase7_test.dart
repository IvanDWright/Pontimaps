import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/app.dart';
import 'package:pontimaps_app/core/config/app_config.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/utils/author_hash.dart';
import 'package:pontimaps_app/data/app_session.dart';
import 'package:pontimaps_app/data/auth_repository.dart';
import 'package:pontimaps_app/data/campus_cartography.dart';
import 'package:pontimaps_app/data/consent_repository.dart';
import 'package:pontimaps_app/data/map_sdk_adapter.dart';
import 'package:pontimaps_app/data/official_alerts_repository.dart';
import 'package:pontimaps_app/data/reports_repository.dart';
import 'package:pontimaps_app/data/schedule_repository.dart';
import 'package:pontimaps_app/models/horario_usuario.dart';
import 'package:pontimaps_app/models/reporte_comunidad.dart';

import '../helpers/test_doubles.dart';

void main() {
  late CampusCartography cartografia;

  setUp(() => cartografia = CampusCartography.seed());

  // Miércoles 18 de noviembre de 2026, 07:50 en Bogotá.
  final miercoles0750 = DateTime.utc(2026, 11, 18, 12, 50);
  const plazoleta = LatLng(4.6285, -74.0645);
  final hashDemo = calcularAuthorHash(AppSession.uidDemo);
  final otroAutor = calcularAuthorHash('otro-usuario');

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
    AppConfig config = const AppConfig(),
    ConsentRepository? consentimiento,
    InMemoryReportsRepository? reportes,
    InMemoryOfficialAlertsRepository? alertas,
    InMemoryAuthRepository? auth,
    ScheduleRepository? horario,
  }) async {
    await tester.pumpWidget(
      PontiMapsApp(
        cartography: cartografia,
        config: config,
        consentRepository:
            consentimiento ?? MemoryConsentRepository(const ConsentState(decision: DecisionGps.aceptado)),
        tileProvider: SinRedTileProvider(),
        initialProfile: perfil,
        clock: ahora == null ? null : () => ahora,
        reportsRepository: reportes,
        alertsRepository: alertas,
        authRepository: auth,
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

  /// Desplaza el primer `Scrollable` (la lista de la pantalla, no los campos de
  /// texto) hasta que [finder] sea visible.
  Future<void> desplazarHasta(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
    } else {
      await tester.scrollUntilVisible(finder, 100, scrollable: find.byType(Scrollable).first);
    }
    await tester.pumpAndSettle();
  }

  Future<void> tocar(WidgetTester tester, Finder finder) async {
    await desplazarHasta(tester, finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('Fase 6 · puerta de entrada, registro y verificación', () {
    pruebaApp('con Firebase, antes del mapa aparece la puerta y «Visitante» no crea sesión', (tester) async {
      final consentimiento = MemoryConsentRepository(const ConsentState(decision: DecisionGps.aceptado));
      final auth = InMemoryAuthRepository();
      await abrir(
        tester,
        config: const AppConfig(useOfflineFallback: false),
        consentimiento: consentimiento,
        auth: auth,
      );

      expect(find.text('Bienvenido a PontiMaps'), findsOneWidget);
      for (final texto in <String>['Iniciar sesión', 'Registrarme', 'Continuar como Visitante']) {
        final boton = find.ancestor(of: find.text(texto), matching: find.bySubtype<ButtonStyleButton>()).first;
        expect(tester.getSize(boton).height, greaterThanOrEqualTo(LayoutMetrics.minTouchTarget), reason: texto);
      }
      expect(find.text('Buscar edificio, salón o servicio'), findsNothing);

      await tester.tap(find.text('Continuar como Visitante'));
      await tester.pumpAndSettle();

      expect(find.text('Buscar edificio, salón o servicio'), findsOneWidget);
      expect(find.text('Modo visitante'), findsOneWidget);
      expect(auth.actual, isNull, reason: 'el visitante no crea usuario ni sesión (ni anónima)');
      expect((await consentimiento.cargar()).visitanteElegido, isTrue);
    });

    pruebaApp('en modo sin conexión no hay puerta: se entra directo al mapa', (tester) async {
      await abrir(tester);
      expect(find.text('Bienvenido a PontiMaps'), findsNothing);
      expect(find.text('Buscar edificio, salón o servicio'), findsOneWidget);
    });

    pruebaApp('registro: dominio, contraseña fuerte, enlace de verificación y acceso al mapa', (tester) async {
      final auth = InMemoryAuthRepository();
      await abrir(tester, config: const AppConfig(useOfflineFallback: false), auth: auth);

      await tester.tap(find.text('Registrarme'));
      await tester.pumpAndSettle();
      final correo = find.widgetWithText(TextField, 'Correo institucional');
      final clave = find.widgetWithText(TextField, 'Contraseña');
      final confirmacion = find.widgetWithText(TextField, 'Confirmar contraseña');

      // Correo de otro dominio: error visible y no se puede crear la cuenta.
      await tester.enterText(correo, 'maria@gmail.com');
      await tester.pumpAndSettle();
      expect(find.text(ErrorAuth.correoNoInstitucional.mensaje), findsOneWidget);

      // Contraseña débil: la lista de requisitos lo muestra con icono y texto.
      await tester.enterText(correo, 'maria.gomez@javeriana.edu.co');
      await tester.enterText(clave, 'abc');
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsWidgets);
      expect(find.byIcon(Icons.cancel_outlined), findsWidgets);
      expect(find.text('Al menos 8 caracteres'), findsOneWidget);
      FilledButton crear() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await desplazarHasta(tester, find.widgetWithText(FilledButton, 'Crear cuenta'));
      expect(crear().onPressed, isNull);

      // Contraseña que contiene el usuario del correo: sigue sin valer.
      await tester.enterText(clave, 'Maria.Gomez#2026');
      await desplazarHasta(tester, confirmacion);
      await tester.enterText(confirmacion, 'Maria.Gomez#2026');
      await tester.pumpAndSettle();
      expect(crear().onPressed, isNull);

      // Contraseña fuerte, confirmación y autorización.
      await tester.enterText(clave, 'Segura#2026');
      await desplazarHasta(tester, confirmacion);
      await tester.enterText(confirmacion, 'Segura#2026');
      await tester.pumpAndSettle();
      expect(crear().onPressed, isNull, reason: 'falta autorizar el tratamiento de datos');
      await tocar(tester, find.byType(CheckboxListTile));
      expect(crear().onPressed, isNotNull);

      await tocar(tester, find.widgetWithText(FilledButton, 'Crear cuenta'));

      // S04: espera de verificación.
      expect(find.text('Revisa tu correo'), findsOneWidget);
      expect(find.textContaining('ma***@javeriana.edu.co'), findsOneWidget);
      expect(auth.actual!.emailVerified, isFalse);
      expect(auth.enlacesEnviados, 1);

      await tester.tap(find.text('Ya verifiqué mi correo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Aún no está verificado'), findsOneWidget);

      await tester.tap(find.text('Reenviar enlace'));
      await tester.pumpAndSettle();
      expect(auth.enlacesEnviados, 2);
      expect(find.textContaining('Reenviar enlace (en'), findsOneWidget, reason: 'espera de 60 s entre envíos');

      await tester.tap(find.text('Simular enlace de verificación (solo demostración)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ya verifiqué mi correo'));
      await tester.pumpAndSettle();

      // Con la cuenta verificada se entra al mapa y el FAB ya no tiene candado.
      expect(find.text('Buscar edificio, salón o servicio'), findsOneWidget);
      expect(find.text('Modo visitante'), findsNothing);
      expect(find.byIcon(Icons.campaign_outlined), findsOneWidget);
    });

    pruebaApp('iniciar sesión: el error no revela si el correo existe', (tester) async {
      final auth = InMemoryAuthRepository();
      await auth.registrar(
        correo: 'maria.gomez@javeriana.edu.co',
        contrasena: 'Segura#2026',
        tipo: RolUsuario.estudiante,
      );
      auth.simularEnlaceDeVerificacion();
      await auth.cerrarSesion();
      await abrir(tester, config: const AppConfig(useOfflineFallback: false), auth: auth);

      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      final campos = find.byType(TextField);
      await tester.enterText(campos.at(0), 'maria.gomez@javeriana.edu.co');
      await tester.enterText(campos.at(1), 'Equivocada#1');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text(ErrorAuth.credencialesInvalidas.mensaje), findsOneWidget);

      await tester.enterText(campos.at(1), 'Segura#2026');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Buscar edificio, salón o servicio'), findsOneWidget);
      expect(find.byIcon(Icons.campaign_outlined), findsOneWidget);
    });
  });

  group('Fase 6 · moderación del administrador', () {
    pruebaApp('solo el administrador ve el panel de moderación', (tester) async {
      await abrir(tester, perfil: PerfilDemo.verificado);
      await irA(tester, 'Más');
      expect(find.text('Panel de moderación'), findsNothing);

      await tester.tap(find.text('Administrador'));
      await tester.pumpAndSettle();
      expect(find.text('Panel de moderación'), findsOneWidget);
    });

    pruebaApp('eliminar un reporte lo quita de todos y no se muestra ninguna identidad', (tester) async {
      final reportes = InMemoryReportsRepository(reloj: () => miercoles0750);
      await reportes.publicar(
        tipo: TipoReporte.cierre,
        ubicacion: plazoleta,
        autorHash: otroAutor,
        idArista: 'a1',
      );
      await abrir(tester, perfil: PerfilDemo.administrador, reportes: reportes, ahora: miercoles0750);
      await irA(tester, 'Más');
      await tester.tap(find.text('Panel de moderación'));
      await tester.pumpAndSettle();

      expect(find.text('Cierre de paso'), findsOneWidget);
      expect(find.textContaining(otroAutor), findsNothing);
      expect(find.textContaining('authorHash'), findsNothing);

      await tester.tap(find.text('Eliminar reporte'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar reporte'));
      await tester.pumpAndSettle();

      expect(reportes.vigentes(), isEmpty);
      expect(find.text('Reporte eliminado.'), findsOneWidget);
      expect(find.text('No hay reportes activos.'), findsOneWidget);
    });

    pruebaApp('«Bloquear autor» degrada a esa cuenta a Visitante en solo lectura', (tester) async {
      final reportes = InMemoryReportsRepository(reloj: () => miercoles0750);
      // El reporte lo hizo la cuenta de prueba «Institucional Verificado».
      await reportes.publicar(
        tipo: TipoReporte.fila,
        ubicacion: plazoleta,
        autorHash: hashDemo,
        idArista: 'a1',
      );
      await abrir(tester, perfil: PerfilDemo.administrador, reportes: reportes, ahora: miercoles0750);
      await irA(tester, 'Más');
      await tester.tap(find.text('Panel de moderación'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bloquear autor'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No verás quién es'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Bloquear autor'));
      await tester.pumpAndSettle();
      expect(find.text('Autor bloqueado: pasa a modo Visitante.'), findsOneWidget);

      // El administrador no pierde sus permisos; quien fue bloqueado, sí.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Panel de moderación'), findsOneWidget);
      await tester.tap(find.text('Institucional Verificado'));
      await tester.pumpAndSettle();
      await irA(tester, 'Mapa');

      expect(find.text('Cuenta suspendida · solo lectura'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsWidgets);
      // El aviso anterior tapa el botón hasta que se oculta solo.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();
      expect(find.text('Necesitas una cuenta institucional verificada'), findsOneWidget);
      expect(reportes.vigentes(), hasLength(1), reason: 'no se publicó nada');
    });

    pruebaApp('publicar una alerta oficial: queda fija en el mapa hasta que se cierre', (tester) async {
      final alertas = InMemoryOfficialAlertsRepository(reloj: () => miercoles0750);
      await abrir(tester, perfil: PerfilDemo.administrador, alertas: alertas, ahora: miercoles0750);
      await irA(tester, 'Más');
      await tester.tap(find.text('Panel de moderación'));
      await tester.pumpAndSettle();

      await tocar(tester, find.widgetWithText(TextField, 'Mensaje de la alerta'));
      await tester.enterText(find.widgetWithText(TextField, 'Mensaje de la alerta'), 'Evento: paso restringido');
      await tester.pumpAndSettle();
      await tocar(tester, find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.textContaining('Edificio 21 ·').last);
      await tester.pumpAndSettle();
      await tocar(tester, find.widgetWithText(FilledButton, 'Publicar alerta oficial'));

      expect(alertas.vigentes().single.mensaje, 'Evento: paso restringido');
      expect(alertas.vigentes().single.ubicacion, cartografia.edificioPorNumero(21)!.ubicacion);
      await desplazarHasta(tester, find.text('Cerrar alerta'));
      expect(find.text('Cerrar alerta'), findsOneWidget);

      // Cualquiera (incluso un visitante) la ve en el mapa.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Visitante'));
      await tester.pumpAndSettle();
      await irA(tester, 'Mapa');
      await tester.tap(find.byIcon(Icons.campaign));
      await tester.pumpAndSettle();
      expect(find.text('Alerta oficial'), findsOneWidget);
      expect(find.text('Evento: paso restringido'), findsOneWidget);

      // Sin expiración automática: días después sigue vigente hasta cerrarla.
      expect(alertas.vigentes(), hasLength(1));
      await alertas.cerrar(alertas.vigentes().single.id);
      await tester.pumpAndSettle();
      expect(find.text('Evento: paso restringido'), findsNothing);
    });
  });

  group('Fase 7 · congestión por zonas y alertas de salida', () {
    pruebaApp('la capa de congestión se activa con un interruptor y muestra la leyenda', (tester) async {
      final reportes = InMemoryReportsRepository(reloj: () => miercoles0750);
      await abrir(tester, reportes: reportes, ahora: miercoles0750);

      expect(find.text('Congestión por zonas'), findsNothing);
      final chip = find.widgetWithText(FilterChip, 'Congestión');
      expect(tester.getSize(chip).height, greaterThanOrEqualTo(LayoutMetrics.minTouchTarget));

      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text('Congestión por zonas'), findsOneWidget);
      for (final nivel in <String>['Baja', 'Media', 'Alta']) {
        expect(find.text(nivel), findsOneWidget, reason: 'leyenda: $nivel');
      }
      expect(find.text('Plazoleta Central: Sin datos recientes'), findsOneWidget);

      // Una alta afluencia y una fila en la Plazoleta → Media (3,5 puntos).
      await reportes.publicar(
        tipo: TipoReporte.altaAfluencia,
        ubicacion: plazoleta,
        autorHash: otroAutor,
        idArista: 'a1',
      );
      await reportes.publicar(
        tipo: TipoReporte.fila,
        ubicacion: plazoleta,
        autorHash: calcularAuthorHash('otra-persona'),
        idArista: 'a2',
      );
      await tester.pumpAndSettle();
      expect(find.text('Plazoleta Central: Media'), findsOneWidget);
      expect(find.text('Calculada solo con reportes anónimos vigentes.'), findsOneWidget);

      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text('Congestión por zonas'), findsNothing);
    });

    pruebaApp('el aviso «Sal en N min» llega con «Iniciar ruta» hacia la próxima clase', (tester) async {
      final almacen = MemoryScheduleRepository();
      await almacen.guardar(AppSession.uidDemo, <BloqueHorario>[
        const BloqueHorario(
          id: 'c1',
          materia: 'Cálculo Diferencial',
          diaSemana: DateTime.wednesday,
          horaInicio: 8 * 60,
          horaFin: 10 * 60,
          idEdificio: IdEdificio.ed67,
          codigoSalon: '67-205',
        ),
      ]);
      await abrir(tester, perfil: PerfilDemo.verificado, horario: almacen, ahora: miercoles0750);

      final aviso = find.textContaining('hacia Edificio 67 · Piso 2');
      expect(aviso, findsOneWidget);
      expect(find.textContaining('Sal '), findsOneWidget);
      expect(find.textContaining('min de margen'), findsOneWidget);
      expect(find.textContaining('5 min de margen'), findsOneWidget);
      final iniciar = find.ancestor(of: find.text('Iniciar ruta'), matching: find.bySubtype<ButtonStyleButton>()).first;
      expect(tester.getSize(iniciar).height, greaterThanOrEqualTo(LayoutMetrics.minTouchTarget));

      await tester.tap(find.text('Iniciar ruta'));
      await tester.pumpAndSettle();
      expect(find.text('Detener ruta'), findsOneWidget);
      expect(find.textContaining('Cálculo Diferencial'), findsNothing);
    });

    pruebaApp('el aviso no aparece si falta mucho para salir ni para un visitante', (tester) async {
      final almacen = MemoryScheduleRepository();
      await almacen.guardar(AppSession.uidDemo, <BloqueHorario>[
        const BloqueHorario(
          id: 'c1',
          materia: 'Física',
          diaSemana: DateTime.wednesday,
          horaInicio: 12 * 60,
          horaFin: 14 * 60,
          idEdificio: IdEdificio.ed67,
          codigoSalon: '67-205',
        ),
      ]);
      await abrir(tester, perfil: PerfilDemo.verificado, horario: almacen, ahora: miercoles0750);
      expect(find.text('Iniciar ruta'), findsNothing);

      await irA(tester, 'Más');
      await tester.tap(find.text('Visitante'));
      await tester.pumpAndSettle();
      await irA(tester, 'Mapa');
      expect(find.text('Iniciar ruta'), findsNothing);
    });

    pruebaApp('el aviso se puede cerrar y no vuelve a salir para esa clase', (tester) async {
      final almacen = MemoryScheduleRepository();
      await almacen.guardar(AppSession.uidDemo, <BloqueHorario>[
        const BloqueHorario(
          id: 'c1',
          materia: 'Cálculo',
          diaSemana: DateTime.wednesday,
          horaInicio: 8 * 60,
          horaFin: 10 * 60,
          idEdificio: IdEdificio.ed67,
          codigoSalon: '67-205',
        ),
      ]);
      await abrir(tester, perfil: PerfilDemo.verificado, horario: almacen, ahora: miercoles0750);
      expect(find.text('Iniciar ruta'), findsOneWidget);

      await tester.tap(find.byTooltip('Cerrar aviso'));
      await tester.pumpAndSettle();
      expect(find.text('Iniciar ruta'), findsNothing);
    });
  });

  group('Directorio con Atención al Estudiante y Bienestar', () {
    pruebaApp('«Ir» desde Atención al Estudiante abre la ruta real hasta el Edificio 21', (tester) async {
      await abrir(tester, ahora: miercoles0750);
      await irA(tester, 'Directorio');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Atención'));
      await tester.pumpAndSettle();
      expect(find.text('Atención al Estudiante'), findsOneWidget);
      // A las 07:50 todavía no abre (Mo-Fr 08:00-17:00).
      expect(find.textContaining('Cerrado · Abre a las 08:00'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Ir'));
      await tester.pumpAndSettle();

      expect(find.text('Atención al Estudiante'), findsOneWidget);
      expect(find.text('Edificio 21 · Piso 1'), findsOneWidget);
      expect(find.textContaining(' m · '), findsOneWidget, reason: 'distancia y tiempo de la ruta');
      await tester.tap(find.widgetWithText(FilledButton, 'Ir'));
      await tester.pumpAndSettle();
      expect(find.text('Detener ruta'), findsOneWidget);
    });

    pruebaApp('«Ir» desde el Centro de Bienestar abre la ruta hasta el Edificio 41', (tester) async {
      await abrir(tester, ahora: miercoles0750);
      await irA(tester, 'Directorio');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Bienestar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Ir'));
      await tester.pumpAndSettle();

      expect(find.text('Centro de Bienestar (Medio Universitario)'), findsOneWidget);
      expect(find.text('Edificio 41 · Piso 1'), findsOneWidget);
      expect(find.textContaining(' m · '), findsOneWidget);
    });
  });

  group('Panel superior compacto con texto al 200 %', () {
    pruebaApp('deja libre al menos el 50 % del mapa y compacta «Mi próxima clase»', (tester) async {
      final almacen = MemoryScheduleRepository();
      await almacen.guardar(AppSession.uidDemo, <BloqueHorario>[
        const BloqueHorario(
          id: 'c1',
          materia: 'Cálculo',
          diaSemana: DateTime.wednesday,
          horaInicio: 14 * 60,
          horaFin: 16 * 60,
          idEdificio: IdEdificio.ed67,
          codigoSalon: '67-205',
        ),
      ]);
      await abrir(tester, perfil: PerfilDemo.verificado, horario: almacen, ahora: miercoles0750);

      expect(tester.takeException(), isNull);
      expect(find.text('Mi próxima clase'), findsNothing);
      expect(find.widgetWithText(ActionChip, 'Próx. clase 14:00'), findsOneWidget, reason: 'icono + «Próx. clase» + hora');

      final mapa = tester.getRect(find.byType(CampusMapView));
      final chip = tester.getRect(find.widgetWithText(ActionChip, 'Próx. clase 14:00'));
      final alturaDelPanel = chip.bottom - mapa.top;
      expect(
        alturaDelPanel,
        lessThanOrEqualTo(mapa.height / 2),
        reason: 'el panel superior ocupa ${alturaDelPanel.round()} de ${mapa.height.round()} dp',
      );
      expect(tester.getSize(find.widgetWithText(ActionChip, 'Próx. clase 14:00')).height,
          greaterThanOrEqualTo(LayoutMetrics.minTouchTarget));
    }, textoAl200: true);

    pruebaApp('con texto normal el chip conserva su etiqueta completa', (tester) async {
      await abrir(tester, perfil: PerfilDemo.verificado, ahora: miercoles0750);
      expect(find.text('Mi próxima clase'), findsOneWidget);
      expect(find.textContaining('Próx.'), findsNothing);
    });

    pruebaApp('administración, puerta de entrada y registro: sin desbordes a 200 %', (tester) async {
      await abrir(tester, perfil: PerfilDemo.administrador, ahora: miercoles0750);
      await irA(tester, 'Más');
      await tester.scrollUntilVisible(find.text('Panel de moderación'), 100);
      await tester.ensureVisible(find.text('Panel de moderación'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Panel de moderación'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Reportes activos'), findsOneWidget);
    }, textoAl200: true);

    pruebaApp('puerta de entrada y registro a 200 %: sin desbordes', (tester) async {
      await abrir(tester, config: const AppConfig(useOfflineFallback: false), auth: InMemoryAuthRepository());
      expect(tester.takeException(), isNull);
      expect(find.text('Bienvenido a PontiMaps'), findsOneWidget);
      await tester.ensureVisible(find.text('Registrarme'));
      await tester.tap(find.text('Registrarme'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Registrarme'), findsWidgets);
    }, textoAl200: true);
  });
}
