import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pontimaps_app/core/utils/author_hash.dart';
import 'package:pontimaps_app/core/utils/password_policy.dart';
import 'package:pontimaps_app/data/auth_repository.dart';
import 'package:pontimaps_app/data/campus_cartography.dart';
import 'package:pontimaps_app/data/location_service.dart';
import 'package:pontimaps_app/data/official_alerts_repository.dart';
import 'package:pontimaps_app/data/places_repository.dart';
import 'package:pontimaps_app/domain/services/congestion_service.dart';
import 'package:pontimaps_app/domain/services/departure_planner.dart';
import 'package:pontimaps_app/domain/services/next_class.dart';
import 'package:pontimaps_app/domain/services/opening_hours.dart';
import 'package:pontimaps_app/models/horario_usuario.dart';
import 'package:pontimaps_app/models/negocio_servicio.dart';
import 'package:pontimaps_app/models/reporte_comunidad.dart';

void main() {
  late CampusCartography cartografia;

  setUp(() => cartografia = CampusCartography.seed());

  // Miércoles 18 de noviembre de 2026, 07:50 en Bogotá (12:50Z).
  final miercoles0750 = DateTime.utc(2026, 11, 18, 12, 50);
  final autor = calcularAuthorHash('uid-autor');

  group('Atención al Estudiante y Bienestar (anclados a edificios reales)', () {
    test('quedan en el catálogo con piso 1 y el horario Mo-Fr acordado', () {
      final atencion = cartografia.negocioPorId('atencion-estudiante')!;
      final bienestar = cartografia.negocioPorId('centro-bienestar')!;

      expect(atencion.idEdificioCercano, 'ed21');
      expect(cartografia.edificioPorNumero(21)!.nombre, contains('Emilio Arango'));
      expect(atencion.piso, 1);
      expect(atencion.horaApertura, '08:00');
      expect(atencion.horaCierre, '17:00');
      expect(atencion.diasAbierto, NegocioServicio.lunesAViernes);
      expect(atencion.ubicacion, cartografia.edificioPorNumero(21)!.ubicacion);
      expect(cartografia.etiquetaUbicacion(atencion), 'Edificio 21 · Piso 1');

      expect(bienestar.idEdificioCercano, 'ed41');
      expect(cartografia.edificioPorNumero(41)!.nombre, 'Pablo VI');
      expect(bienestar.horaApertura, '07:00');
      expect(bienestar.horaCierre, '19:00');
      expect(bienestar.diasAbierto, NegocioServicio.lunesAViernes);
      expect(cartografia.etiquetaUbicacion(bienestar), 'Edificio 41 · Piso 1');
    });

    test('el catálogo sigue siendo íntegro y se pueden trazar rutas reales hasta ellos', () {
      expect(cartografia.validar(), isEmpty);
      final origen = SimulatedLocationProvider.plazoletaCentral;
      for (final id in <String>['atencion-estudiante', 'centro-bienestar']) {
        final negocio = cartografia.negocioPorId(id)!;
        final ruta = cartografia.calcularRuta(
          origen,
          cartografia.idDestinoRuta(negocio),
          piso: negocio.piso,
        );
        expect(ruta.distanciaMetros, greaterThan(0), reason: id);
        expect(ruta.puntos.length, greaterThanOrEqualTo(2), reason: id);
        expect(ruta.accesoVertical, isNotNull, reason: id);
      }
    });

    test('los chips «Atención» y «Bienestar» del directorio devuelven resultados', () {
      final repo = SeedPlacesRepository(cartografia);
      final atencion = repo.lugares(filtro: FiltroDirectorio.atencion, ahora: miercoles0750);
      final bienestar = repo.lugares(filtro: FiltroDirectorio.bienestar, ahora: miercoles0750);
      expect(atencion.map((l) => l.negocio.id), <String>['atencion-estudiante']);
      expect(bienestar.map((l) => l.negocio.id), <String>['centro-bienestar']);
    });

    test('«Mo-Fr 08:00-17:00»: abierto entre semana, cerrado de noche y el fin de semana', () {
      EstadoHorario estado(DateTime ahora) => estadoDeNegocio(cartografia.negocioPorId('atencion-estudiante')!, ahora);

      // Miércoles 10:00 en Bogotá.
      expect(estado(DateTime.utc(2026, 11, 18, 15)).estado, EstadoApertura.abierto);
      // Miércoles 16:45: cierra pronto.
      expect(estado(DateTime.utc(2026, 11, 18, 21, 45)).estado, EstadoApertura.cierraPronto);
      // Miércoles 17:00: cerrado, abre mañana.
      final noche = estado(DateTime.utc(2026, 11, 18, 22));
      expect(noche.estado, EstadoApertura.cerrado);
      expect(noche.detalle, 'Abre mañana a las 08:00');
      // Viernes 17:30 → cerrado hasta el lunes.
      final viernes = estado(DateTime.utc(2026, 11, 20, 22, 30));
      expect(viernes.estado, EstadoApertura.cerrado);
      expect(viernes.detalle, 'Abre el lunes a las 08:00');
      // Sábado a media mañana: cerrado, aunque la hora esté dentro del horario.
      final sabado = estado(DateTime.utc(2026, 11, 21, 16));
      expect(sabado.estado, EstadoApertura.cerrado);
      expect(sabado.detalle, 'Abre el lunes a las 08:00');
      // Lunes 07:00: cerrado, abre hoy a las 08:00.
      expect(estado(DateTime.utc(2026, 11, 23, 12)).detalle, 'Abre a las 08:00');
    });

    test('el cruce de medianoche con días respeta el día del horario', () {
      // Abre de lunes a viernes de 22:00 a 02:00: la madrugada del sábado
      // pertenece al viernes (abierto), la del lunes al domingo (cerrado).
      EstadoHorario estado(DateTime ahora) => calcularEstadoHorario(
            apertura: '22:00',
            cierre: '02:00',
            ahora: ahora,
            dias: NegocioServicio.lunesAViernes,
          );
      expect(estado(DateTime.utc(2026, 11, 21, 6, 30)).estado, EstadoApertura.abierto); // sáb 01:30
      expect(estado(DateTime.utc(2026, 11, 23, 6, 30)).estado, EstadoApertura.cerrado); // lun 01:30
    });
  });

  group('Congestión por zonas (Baja / Media / Alta)', () {
    ReporteComunidad reporte(
      TipoReporte tipo,
      LatLng donde, {
      int confirmaciones = 0,
      int negativos = 0,
      DateTime? creado,
    }) {
      var r = ReporteComunidad.nuevo(
        id: 'r-${donde.latitude}-${tipo.name}-$confirmaciones-$negativos',
        tipo: tipo,
        ubicacion: donde,
        ahora: creado ?? miercoles0750,
        authorHash: autor,
      ).sinAutor();
      for (var i = 0; i < confirmaciones; i++) {
        r = r.confirmar(creado ?? miercoles0750);
      }
      for (var i = 0; i < negativos; i++) {
        r = r.negar();
      }
      return r;
    }

    CongestionZona de(List<CongestionZona> lista, String id) => lista.firstWhere((z) => z.zona.id == id);

    const plazoleta = LatLng(4.6285, -74.0645);

    test('define las cinco zonas del campus con puntos reales del catálogo', () {
      final zonas = CongestionService.zonasDelCampus(cartografia);
      expect(zonas.map((z) => z.id), <String>[
        'plazoleta-central',
        'ingenieria',
        'ciencias-biblioteca',
        'artes-pablo-vi',
        'cafeteria-central',
      ]);
      expect(zonas.every((z) => z.anclas.isNotEmpty && z.radioMetros > 0), isTrue);
      expect(de(<CongestionZona>[
        for (final z in zonas) CongestionZona(zona: z, nivel: null, puntaje: 0, reportes: 0),
      ], 'cafeteria-central').zona.anclas.single, cartografia.negocioPorId('cafeteria-la-central')!.ubicacion);
    });

    test('sin reportes no hay datos: «Sin datos recientes», nunca «Baja»', () {
      final zonas = CongestionService.zonasDelCampus(cartografia);
      final r = CongestionService.calcular(zonas: zonas, reportes: const <ReporteComunidad>[], ahora: miercoles0750);
      for (final z in r) {
        expect(z.nivel, isNull);
        expect(z.etiqueta, 'Sin datos recientes');
        expect(z.reportes, 0);
      }
    });

    test('clasifica por puntaje: Baja < 2 ≤ Media < 4 ≤ Alta', () {
      final zonas = CongestionService.zonasDelCampus(cartografia);
      CongestionZona plaza(List<ReporteComunidad> rs) =>
          de(CongestionService.calcular(zonas: zonas, reportes: rs, ahora: miercoles0750), 'plazoleta-central');

      // Un cierre (1,0) → Baja.
      expect(plaza(<ReporteComunidad>[reporte(TipoReporte.cierre, plazoleta)]).nivel, NivelCongestion.baja);
      // Una fila (1,5) → Baja; una alta afluencia (2,0) → Media.
      expect(plaza(<ReporteComunidad>[reporte(TipoReporte.fila, plazoleta)]).nivel, NivelCongestion.baja);
      final media = plaza(<ReporteComunidad>[reporte(TipoReporte.altaAfluencia, plazoleta)]);
      expect(media.nivel, NivelCongestion.media);
      expect(media.etiqueta, 'Media');
      // Alta afluencia + fila (3,5) → Media; con una confirmación (4,0) → Alta.
      expect(
        plaza(<ReporteComunidad>[
          reporte(TipoReporte.altaAfluencia, plazoleta),
          reporte(TipoReporte.fila, plazoleta),
        ]).nivel,
        NivelCongestion.media,
      );
      final alta = plaza(<ReporteComunidad>[
        reporte(TipoReporte.altaAfluencia, plazoleta, confirmaciones: 1),
        reporte(TipoReporte.fila, plazoleta),
      ]);
      expect(alta.nivel, NivelCongestion.alta);
      expect(alta.puntaje, 4.0);
      expect(alta.reportes, 2);
    });

    test('los reportes vencidos u ocultos no cuentan', () {
      final zonas = CongestionService.zonasDelCampus(cartografia);
      final vencido = reporte(TipoReporte.altaAfluencia, plazoleta);
      final oculto = reporte(TipoReporte.altaAfluencia, plazoleta, negativos: 3);

      final dentro = CongestionService.calcular(zonas: zonas, reportes: <ReporteComunidad>[vencido], ahora: miercoles0750);
      expect(de(dentro, 'plazoleta-central').nivel, NivelCongestion.media);

      final tarde = miercoles0750.add(const Duration(minutes: 61));
      final despues = CongestionService.calcular(zonas: zonas, reportes: <ReporteComunidad>[vencido], ahora: tarde);
      expect(de(despues, 'plazoleta-central').nivel, isNull);

      final ocultos = CongestionService.calcular(zonas: zonas, reportes: <ReporteComunidad>[oculto], ahora: miercoles0750);
      expect(de(ocultos, 'plazoleta-central').nivel, isNull);
    });

    test('un reporte cuenta una sola vez y solo dentro del radio de una zona', () {
      final zonas = CongestionService.zonasDelCampus(cartografia);
      final cafeteria = cartografia.negocioPorId('cafeteria-la-central')!.ubicacion;
      final lejos = reporte(TipoReporte.altaAfluencia, const LatLng(4.64, -74.08));
      final r = CongestionService.calcular(
        zonas: zonas,
        reportes: <ReporteComunidad>[reporte(TipoReporte.altaAfluencia, cafeteria), lejos],
        ahora: miercoles0750,
      );
      expect(r.fold<int>(0, (suma, z) => suma + z.reportes), 1, reason: 'el lejano no cuenta y el otro, una vez');
      expect(de(r, 'cafeteria-central').reportes, 1);
    });

    test('las confirmaciones suman y los votos negativos restan (sin bajar de 0)', () {
      expect(CongestionService.puntajeDe(reporte(TipoReporte.fila, plazoleta, confirmaciones: 2)), 2.5);
      expect(CongestionService.puntajeDe(reporte(TipoReporte.cierre, plazoleta, negativos: 2)), 0.0);
    });
  });

  group('Hora de salida a clase (inicio − ruta − 5 min)', () {
    final perfil = UsuarioPerfil.institucional(
      uid: 'u1',
      correoInstitucional: 'a@javeriana.edu.co',
      rol: RolUsuario.estudiante,
      emailVerified: true,
    );

    BloqueHorario clase(String id, int h, int m, {int fin = 60, String edificio = 'ed67', String salon = '67-205'}) =>
        BloqueHorario(
          id: id,
          materia: 'Materia $id',
          diaSemana: DateTime.wednesday,
          horaInicio: h * 60 + m,
          horaFin: h * 60 + m + fin,
          idEdificio: edificio,
          codigoSalon: salon,
        );

    test('la fórmula resta la duración de la ruta y 5 minutos de margen', () {
      final inicio = DateTime.utc(2026, 11, 18, 8);
      expect(
        DeparturePlanner.calcularHoraSalida(inicioClase: inicio, duracionRuta: const Duration(minutes: 7)),
        DateTime.utc(2026, 11, 18, 7, 48),
      );
      expect(
        DeparturePlanner.calcularHoraSalida(
          inicioClase: inicio,
          duracionRuta: const Duration(minutes: 7),
          margen: Duration.zero,
        ),
        DateTime.utc(2026, 11, 18, 7, 53),
      );
      expect(DeparturePlanner.margenPorDefecto, const Duration(minutes: 5));
    });

    test('usa la duración real de la ruta A* desde la posición del estudiante', () {
      final origen = SimulatedLocationProvider.plazoletaCentral;
      final alerta = DeparturePlanner.planificar(
        perfil: perfil,
        horario: <BloqueHorario>[clase('a', 8, 30)],
        ahora: miercoles0750,
        cartografia: cartografia,
        posicion: origen,
      )!;

      final ruta = cartografia.calcularRutaHaciaSalon(origen, alerta.salon);
      expect(alerta.duracionRuta, Duration(minutes: ruta.tiempoEstimadoMinutos));
      expect(
        alerta.horaSalida,
        DateTime.utc(2026, 11, 18, 8, 30).subtract(alerta.duracionRuta).subtract(const Duration(minutes: 5)),
      );
      expect(alerta.salon.codigo, '67-205');
      expect(alerta.margen, const Duration(minutes: 5));
    });

    test('el texto avisa cuánto falta o «Sal ya» con Edificio y Piso', () {
      final alerta = DeparturePlanner.planificar(
        perfil: perfil,
        horario: <BloqueHorario>[clase('a', 8, 30)],
        ahora: miercoles0750,
        cartografia: cartografia,
        posicion: SimulatedLocationProvider.plazoletaCentral,
      )!;
      final antes = alerta.horaSalida.subtract(const Duration(minutes: 4));
      expect(alerta.texto(antes), 'Sal en 4 min hacia Edificio 67 · Piso 2');
      expect(alerta.texto(alerta.horaSalida), 'Sal ya hacia Edificio 67 · Piso 2');
      expect(alerta.texto(alerta.horaSalida.add(const Duration(minutes: 3))), 'Sal ya hacia Edificio 67 · Piso 2');
      expect(alerta.minutosParaSalir(antes), 4);
    });

    test('sin posición usa el edificio de la clase anterior del mismo día', () {
      final horario = <BloqueHorario>[
        clase('anterior', 6, 0, fin: 120, edificio: 'ed51', salon: '51-101'),
        clase('proxima', 8, 30),
      ];
      final proxima = calcularProximaClase(perfil, horario, miercoles0750)!;
      expect(proxima.bloque.id, 'proxima');
      expect(
        DeparturePlanner.origenParaClase(proxima: proxima, horario: horario, cartografia: cartografia),
        cartografia.edificioPorId('ed51')!.ubicacion,
      );

      final alerta = DeparturePlanner.planificar(
        perfil: perfil,
        horario: horario,
        ahora: miercoles0750,
        cartografia: cartografia,
      );
      expect(alerta, isNotNull);
      expect(alerta!.proxima.bloque.id, 'proxima');
    });

    test('sin origen conocido, sin clase o con un salón inexistente no hay alerta', () {
      // Sin posición ni clase anterior.
      expect(
        DeparturePlanner.planificar(
          perfil: perfil,
          horario: <BloqueHorario>[clase('a', 8, 30)],
          ahora: miercoles0750,
          cartografia: cartografia,
        ),
        isNull,
      );
      // Sin clases.
      expect(
        DeparturePlanner.planificar(
          perfil: perfil,
          horario: const <BloqueHorario>[],
          ahora: miercoles0750,
          cartografia: cartografia,
          posicion: SimulatedLocationProvider.plazoletaCentral,
        ),
        isNull,
      );
      // Salón que no existe en el catálogo.
      expect(
        DeparturePlanner.planificar(
          perfil: perfil,
          horario: <BloqueHorario>[clase('a', 8, 30, salon: '99-999')],
          ahora: miercoles0750,
          cartografia: cartografia,
          posicion: SimulatedLocationProvider.plazoletaCentral,
        ),
        isNull,
      );
    });
  });

  group('Política de contraseña', () {
    test('acepta una contraseña que cumple los siete requisitos', () {
      expect(contrasenaValida('Segura#2026', correo: 'juan.perez@javeriana.edu.co'), isTrue);
      expect(requisitosFaltantes('Segura#2026', correo: 'juan.perez@javeriana.edu.co'), isEmpty);
    });

    test('rechaza cada incumplimiento por separado', () {
      const correo = 'juan.perez@javeriana.edu.co';
      expect(requisitosFaltantes('Ab1#', correo: correo), contains(RequisitoContrasena.longitudMinima));
      expect(requisitosFaltantes('segura#2026', correo: correo), contains(RequisitoContrasena.mayuscula));
      expect(requisitosFaltantes('SEGURA#2026', correo: correo), contains(RequisitoContrasena.minuscula));
      expect(requisitosFaltantes('Segura##aaa', correo: correo), contains(RequisitoContrasena.numero));
      expect(requisitosFaltantes('Segura12345', correo: correo), contains(RequisitoContrasena.simbolo));
      expect(requisitosFaltantes('Segura #2026', correo: correo), contains(RequisitoContrasena.sinEspacios));
      expect(
        requisitosFaltantes('Juan.Perez#2026', correo: correo),
        contains(RequisitoContrasena.sinUsuarioDelCorreo),
      );
      expect(contrasenaValida('', correo: correo), isFalse);
    });

    test('el usuario del correo se compara sin importar mayúsculas', () {
      expect(usuarioDelCorreo(' Juan.Perez@Javeriana.edu.co '), 'juan.perez');
      expect(contrasenaValida('JUAN.PEREZ#a1b', correo: 'juan.perez@javeriana.edu.co'), isFalse);
    });
  });

  group('InMemoryAuthRepository (cuentas de prueba, enlace simulado)', () {
    const correo = 'maria.gomez@javeriana.edu.co';
    const clave = 'Segura#2026';

    test('registra con el dominio institucional y deja la cuenta sin verificar', () async {
      final auth = InMemoryAuthRepository();
      await auth.registrar(correo: correo, contrasena: clave, tipo: RolUsuario.estudiante);

      final cuenta = auth.actual!;
      expect(cuenta.correo, correo);
      expect(cuenta.emailVerified, isFalse);
      expect(cuenta.estado, EstadoCuenta.activo);
      expect(cuenta.rol, RolUsuario.estudiante);
      expect(cuenta.toPerfil().authState, AuthState.institucionalNoVerificado);
      expect(cuenta.toPerfil().puedeEscribir, isFalse);
      expect(auth.enlacesEnviados, 1);
      expect(cuenta.correoEnmascarado, 'ma***@javeriana.edu.co');
    });

    test('rechaza correo de otro dominio, contraseña débil, duplicado y rol admin', () async {
      final auth = InMemoryAuthRepository();
      Future<ErrorAuth> error(Future<void> Function() accion) async {
        try {
          await accion();
        } on AuthException catch (e) {
          return e.codigo;
        }
        fail('Debía lanzar AuthException');
      }

      expect(
        await error(() => auth.registrar(correo: 'a@gmail.com', contrasena: clave, tipo: RolUsuario.estudiante)),
        ErrorAuth.correoNoInstitucional,
      );
      expect(
        await error(() => auth.registrar(correo: correo, contrasena: 'debil', tipo: RolUsuario.estudiante)),
        ErrorAuth.contrasenaDebil,
      );
      expect(
        await error(() => auth.registrar(correo: correo, contrasena: clave, tipo: RolUsuario.admin)),
        ErrorAuth.rolInvalido,
      );
      await auth.registrar(correo: correo, contrasena: clave, tipo: RolUsuario.profesor);
      expect(
        await error(() => auth.registrar(correo: correo, contrasena: clave, tipo: RolUsuario.estudiante)),
        ErrorAuth.correoYaRegistrado,
      );
    });

    test('el inicio de sesión no distingue «no existe» de «contraseña incorrecta»', () async {
      final auth = InMemoryAuthRepository();
      await auth.registrar(correo: correo, contrasena: clave, tipo: RolUsuario.estudiante);
      await auth.cerrarSesion();
      expect(auth.actual, isNull);

      Future<ErrorAuth> codigo(String c, String p) async {
        try {
          await auth.iniciarSesion(correo: c, contrasena: p);
        } on AuthException catch (e) {
          return e.codigo;
        }
        fail('Debía fallar');
      }

      expect(await codigo(correo, 'Incorrecta#1'), ErrorAuth.credencialesInvalidas);
      expect(await codigo('nadie@javeriana.edu.co', clave), ErrorAuth.credencialesInvalidas);

      await auth.iniciarSesion(correo: correo.toUpperCase(), contrasena: clave);
      expect(auth.actual!.correo, correo);
    });

    test('la verificación simulada habilita la escritura y se emite el cambio', () async {
      final auth = InMemoryAuthRepository();
      final emisiones = <bool?>[];
      final suscripcion = auth.cambios().listen((c) => emisiones.add(c?.emailVerified));
      await auth.registrar(correo: correo, contrasena: clave, tipo: RolUsuario.estudiante);
      expect((await auth.recargar())!.emailVerified, isFalse);

      auth.simularEnlaceDeVerificacion();
      await Future<void>.delayed(Duration.zero);
      expect((await auth.recargar())!.toPerfil().puedeEscribir, isTrue);
      await suscripcion.cancel();
      expect(emisiones, contains(true), reason: 'verificar el correo se emite a quien escucha');
      expect(emisiones.first, isFalse);
    });

    test('un administrador que bloquea la cuenta la degrada a Visitante', () async {
      final auth = InMemoryAuthRepository();
      await auth.registrar(correo: correo, contrasena: clave, tipo: RolUsuario.estudiante);
      auth.simularEnlaceDeVerificacion();
      final uid = auth.actual!.uid;
      expect(auth.actual!.toPerfil().authState, AuthState.institucionalVerificado);

      auth.cambiarEstado(uid, EstadoCuenta.bloqueado);
      expect(auth.actual!.toPerfil().authState, AuthState.bloqueado);
      expect(auth.actual!.toPerfil().puedeEscribir, isFalse);
    });

    test('un administrador solo existe si la cuenta ya trae rol admin (consola)', () {
      const cuenta = CuentaAuth(
        uid: 'u',
        correo: 'admin@javeriana.edu.co',
        rol: RolUsuario.admin,
        emailVerified: true,
      );
      expect(cuenta.toPerfil().esAdministrador, isTrue);
      expect(cuenta.copyWith(estado: EstadoCuenta.bloqueado).toPerfil().esAdministrador, isFalse);
      expect(cuenta.copyWith(emailVerified: false).toPerfil().esAdministrador, isFalse);
    });
  });

  group('Alertas oficiales', () {
    test('publicar, ver y cerrar; sin «hasta» no expiran solas', () async {
      var ahora = miercoles0750;
      final repo = InMemoryOfficialAlertsRepository(reloj: () => ahora);
      final alerta = await repo.publicar(mensaje: '  Cierre por evento  ', ubicacion: const LatLng(4.6285, -74.0645));

      expect(alerta.mensaje, 'Cierre por evento');
      expect(repo.vigentes(), hasLength(1));

      ahora = ahora.add(const Duration(days: 30));
      expect(repo.vigentes(), hasLength(1), reason: 'fija hasta que el administrador la cierra');

      await repo.cerrar(alerta.id);
      expect(repo.vigentes(), isEmpty);
    });

    test('con «hasta» termina en esa hora y el mensaje se valida', () async {
      var ahora = miercoles0750;
      final repo = InMemoryOfficialAlertsRepository(reloj: () => ahora);
      await repo.publicar(
        mensaje: 'Obra',
        ubicacion: const LatLng(4.6285, -74.0645),
        hasta: ahora.add(const Duration(hours: 2)),
      );
      expect(repo.vigentes(), hasLength(1));
      ahora = ahora.add(const Duration(hours: 2));
      expect(repo.vigentes(), isEmpty);

      expect(
        () => repo.publicar(mensaje: '   ', ubicacion: const LatLng(0, 0)),
        throwsArgumentError,
      );
      expect(
        () => repo.publicar(mensaje: 'x' * 141, ubicacion: const LatLng(0, 0)),
        throwsArgumentError,
      );
    });

    test('toMap / deMapa conservan la alerta y descartan las dañadas', () {
      final alerta = AlertaOficial(
        id: 'a1',
        mensaje: 'Hola',
        ubicacion: const LatLng(4.6, -74.06),
        desde: miercoles0750,
        hasta: miercoles0750.add(const Duration(hours: 1)),
      );
      final copia = AlertaOficial.deMapa('a1', alerta.toMap())!;
      expect(copia.mensaje, 'Hola');
      expect(copia.ubicacion, alerta.ubicacion);
      expect(copia.hasta, alerta.hasta);
      expect(alerta.toMap()['tipo'], 'oficial');
      expect(AlertaOficial.deMapa('a2', <String, Object?>{'mensaje': 'x'}), isNull);
    });
  });
}
