import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pontimaps_app/core/utils/author_hash.dart';
import 'package:pontimaps_app/models/edificio.dart';
import 'package:pontimaps_app/models/horario_usuario.dart';
import 'package:pontimaps_app/models/negocio_servicio.dart';
import 'package:pontimaps_app/models/reporte_comunidad.dart';
import 'package:pontimaps_app/models/salon.dart';

// Datos ILUSTRATIVOS (coordenadas y salones de ejemplo, no verificados).
Edificio _ed51() => Edificio(
      id: 'ed51',
      numero: 51,
      nombre: 'Ciencia y Tecnología (Gerardo Arango)',
      ubicacion: LatLng(4.6280, -74.0640),
      perimetro: <LatLng>[LatLng(4.6279, -74.0641), LatLng(4.6279, -74.0639), LatLng(4.6281, -74.0639)],
      salones: const <Salon>[
        Salon(codigo: '301', piso: 3, idEdificio: 'ed51', nombreEdificio: 'Ciencia y Tecnología', numeroEdificio: 51),
        Salon(codigo: 'LAB-2', piso: 1, idEdificio: 'ed51', nombreEdificio: 'Ciencia y Tecnología', numeroEdificio: 51, tipo: TipoSalon.laboratorio),
      ],
      tieneAccesoMovilidadReducida: true,
      accesibilidadConfirmada: true,
    );

final DateTime _t0 = DateTime(2026, 11, 17, 9, 0);

void main() {
  group('Salon', () {
    test('etiquetaUbicacion usa el formato "Edificio X · Piso Y"', () {
      const s = Salon(codigo: '301', piso: 3, idEdificio: 'ed51', nombreEdificio: 'Gerardo Arango', numeroEdificio: 51);
      expect(s.etiquetaUbicacion(), 'Edificio 51 · Piso 3');
      expect(s.copyWith(piso: 4).etiquetaUbicacion(), 'Edificio 51 · Piso 4');
      expect(s.tipo, TipoSalon.aula);
    });
  });

  group('Edificio', () {
    test('buscarSalon ignora mayúsculas y espacios; devuelve null si no existe', () {
      final e = _ed51();
      expect(e.buscarSalon('lab-2')?.piso, 1);
      expect(e.buscarSalon(' 301 ')?.codigo, '301');
      expect(e.buscarSalon('999'), isNull);
    });

    test('coincideConBusqueda tolera número, nombre, tildes y prefijos', () {
      final e = _ed51();
      for (final q in <String>['51', 'ed 51', 'Edificio 51', 'gerardo arango', 'CIENCIA', 'ciencia y tecnologia', 'ed. 51 gerardo']) {
        expect(e.coincideConBusqueda(q), isTrue, reason: q);
      }
      for (final q in <String>['', '   ', 'ed', 'edificio', '5', '52', 'biblioteca']) {
        expect(e.coincideConBusqueda(q), isFalse, reason: q);
      }
    });

    test('es inmutable y valida pertenencia y unicidad de salones', () {
      final e = _ed51();
      expect(() => e.salones.add(e.salones.first), throwsUnsupportedError);
      expect(e.copyWith(nombre: 'Otro').numero, 51);
      expect(
        () => Edificio(
          id: 'ed51',
          numero: 51,
          nombre: 'X',
          ubicacion: LatLng(0, 0),
          salones: const <Salon>[
            Salon(codigo: '1', piso: 1, idEdificio: 'ed51', nombreEdificio: 'X', numeroEdificio: 51),
            Salon(codigo: ' 1', piso: 2, idEdificio: 'ed51', nombreEdificio: 'X', numeroEdificio: 51),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => Edificio(
          id: 'ed51',
          numero: 51,
          nombre: 'X',
          ubicacion: LatLng(0, 0),
          salones: const <Salon>[
            Salon(codigo: '1', piso: 1, idEdificio: 'ed99', nombreEdificio: 'Y', numeroEdificio: 99),
          ],
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('ReporteComunidad', () {
    final hashAutor = calcularAuthorHash('uid-autor');
    ReporteComunidad nuevo() => ReporteComunidad.nuevo(id: 'r1', tipo: TipoReporte.fila, ubicacion: LatLng(4.6, -74.06), ahora: _t0, authorHash: hashAutor);

    test('expira exactamente a los 60 minutos', () {
      final r = nuevo();
      expect(r.expiraEn, _t0.add(const Duration(minutes: 60)));
      expect(r.estaVigente(_t0), isTrue);
      expect(r.estaVigente(_t0.add(const Duration(minutes: 59, seconds: 59))), isTrue);
      expect(r.estaVigente(_t0.add(const Duration(minutes: 60))), isFalse);
      expect(r.estaVigente(_t0.add(const Duration(minutes: 61))), isFalse);
    });

    test('confirmar extiende 30 min con tope de 180 min desde la creación', () {
      var r = nuevo();
      r = r.confirmar(_t0.add(const Duration(minutes: 10)));
      expect(r.confirmaciones, 1);
      expect(r.expiraEn, _t0.add(const Duration(minutes: 90)));
      for (var i = 0; i < 10; i++) {
        r = r.confirmar(_t0.add(const Duration(minutes: 20)));
      }
      expect(r.expiraEn, _t0.add(const Duration(minutes: 180)));
      expect(r.confirmaciones, 11);
    });

    test('un reporte vencido no se revive al confirmar', () {
      final r = nuevo();
      final tarde = _t0.add(const Duration(minutes: 90));
      expect(r.confirmar(tarde), same(r));
    });

    test('con >= 3 votos negativos se oculta, aunque tenga confirmaciones', () {
      var r = nuevo();
      r = r.negar().negar();
      expect(r.estaVigente(_t0), isTrue);
      expect(r.negar().estaVigente(_t0), isFalse);
      var confirmado = nuevo();
      for (var i = 0; i < 5; i++) {
        confirmado = confirmado.confirmar(_t0);
      }
      confirmado = confirmado.negar().negar();
      expect(confirmado.estaVigente(_t0), isTrue);
      expect(confirmado.negar().estaVigente(_t0), isFalse);
      // Oculto: ya no se puede revivir confirmándolo.
      final oculto = confirmado.negar();
      expect(oculto.confirmar(_t0), same(oculto));
    });

    test('factorPenalizacion según el tipo y la credibilidad', () {
      ReporteComunidad de(TipoReporte t) => ReporteComunidad.nuevo(id: 'x', tipo: t, ubicacion: LatLng(0, 0), ahora: _t0, authorHash: hashAutor);
      expect(de(TipoReporte.cierre).factorPenalizacion(), double.infinity);
      expect(de(TipoReporte.fila).factorPenalizacion(), 1.5);
      expect(de(TipoReporte.altaAfluencia).factorPenalizacion(), 1.3);
      expect(de(TipoReporte.cierre).negar().factorPenalizacion(), 1.0);
    });

    test('anonimato: la vista pública y toString no revelan al autor', () {
      final r = nuevo();
      expect(r.authorHash, hashAutor);
      final publico = r.toMap();
      expect(publico.keys, isNot(contains('authorHash')));
      expect(publico.values.whereType<String>(), isNot(contains(hashAutor)));
      expect(r.toString(), isNot(contains(hashAutor)));
      expect(r.sinAutor().authorHash, isNull);
      // La autoría viaja aparte, solo para moderación.
      expect(r.toMapAutoria(), <String, Object?>{'idReporte': 'r1', 'authorHash': hashAutor});
      expect(r.sinAutor().toMapAutoria(), isNull);
    });

    test('authorHash: determinista, irreversible en forma y validado', () {
      expect(calcularAuthorHash('abc'), calcularAuthorHash('abc'));
      expect(calcularAuthorHash('abc'), isNot(calcularAuthorHash('abd')));
      expect(calcularAuthorHash('abc'), matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(calcularAuthorHash('abc'), isNot(contains('abc')));
      expect(() => calcularAuthorHash(''), throwsArgumentError);
      expect(esAuthorHashValido('xyz'), isFalse);
      expect(
        () => ReporteComunidad.nuevo(id: 'r', tipo: TipoReporte.cierre, ubicacion: LatLng(0, 0), ahora: _t0, authorHash: 'no-es-un-hash'),
        throwsArgumentError,
      );
    });

    test('toMap/fromMap hacen ida y vuelta y no incluyen datos de usuario', () {
      final r = nuevo().confirmar(_t0).copyWith(idAristaAfectada: 'e1', descripcionCorta: 'Fila en cafetería');
      final mapa = r.toMap();
      expect(mapa.keys, isNot(contains('uid')));
      expect(mapa.keys.where((k) => k.toLowerCase().contains('user')), isEmpty);
      final copia = ReporteComunidad.fromMap(mapa);
      expect(copia.authorHash, isNull, reason: 'la vista pública no trae autor');
      expect(ReporteComunidad.fromMap(mapa, authorHash: hashAutor).authorHash, hashAutor);
      expect(() => ReporteComunidad.fromMap(mapa, authorHash: 'malo'), throwsFormatException);
      expect(copia.id, r.id);
      expect(copia.tipo, r.tipo);
      expect(copia.ubicacion, r.ubicacion);
      expect(copia.idAristaAfectada, 'e1');
      expect(copia.expiraEn.isAtSameMomentAs(r.expiraEn), isTrue);
      expect(copia.confirmaciones, 1);
    });

    test('fromMap rechaza datos que rompen los invariantes', () {
      final base = nuevo().toMap();
      expect(() => ReporteComunidad.fromMap(<String, Object?>{...base, 'tipo': 'explosion'}), throwsFormatException);
      expect(() => ReporteComunidad.fromMap(<String, Object?>{...base}..remove('lat')), throwsFormatException);
      expect(
        () => ReporteComunidad.fromMap(<String, Object?>{...base, 'expiraEn': (base['creadoEn']! as int) + 1000}),
        throwsFormatException,
        reason: 'expira antes de 60 min',
      );
      expect(
        () => ReporteComunidad.fromMap(<String, Object?>{...base, 'expiraEn': (base['creadoEn']! as int) + 61 * 60000}),
        throwsFormatException,
        reason: 'sin confirmaciones debe ser exactamente 60 min',
      );
    });
  });

  group('NegocioServicio', () {
    NegocioServicio con(String apertura, String cierre) => NegocioServicio(
          id: 'n1',
          nombre: 'Cafetería Central',
          categoria: CategoriaServicio.cafeteria,
          ubicacion: LatLng(4.6, -74.06),
          idEdificioCercano: 'ed02',
          horaApertura: apertura,
          horaCierre: cierre,
        );

    test('apertura incluida, cierre excluido', () {
      final n = con('07:00', '18:00');
      expect(n.estaAbierto(DateTime(2026, 11, 17, 6, 59)), isFalse);
      expect(n.estaAbierto(DateTime(2026, 11, 17, 7, 0)), isTrue);
      expect(n.estaAbierto(DateTime(2026, 11, 17, 17, 59)), isTrue);
      expect(n.estaAbierto(DateTime(2026, 11, 17, 18, 0)), isFalse);
    });

    test('horarios que cruzan la medianoche y 24 horas', () {
      final noche = con('22:00', '02:00');
      expect(noche.estaAbierto(DateTime(2026, 11, 17, 23, 30)), isTrue);
      expect(noche.estaAbierto(DateTime(2026, 11, 17, 1, 30)), isTrue);
      expect(noche.estaAbierto(DateTime(2026, 11, 17, 12, 0)), isFalse);
      expect(con('00:00', '00:00').estaAbierto(DateTime(2026, 11, 17, 3, 0)), isTrue);
    });

    test('convierte UTC a hora de Colombia (UTC-5)', () {
      final n = con('07:00', '18:00');
      expect(n.estaAbierto(DateTime.utc(2026, 11, 17, 12, 0)), isTrue); // 07:00 Bogotá
      expect(n.estaAbierto(DateTime.utc(2026, 11, 17, 11, 59)), isFalse); // 06:59
    });

    test('nivelFilaActual es null sin datos y las horas inválidas se rechazan', () {
      expect(con('07:00', '18:00').nivelFilaActual, isNull);
      expect(con('07:00', '18:00').copyWith(nivelFilaActual: NivelCongestion.alta).nivelFilaActual, NivelCongestion.alta);
      expect(NegocioServicio.esHoraValida('24:00'), isFalse);
      expect(NegocioServicio.esHoraValida('7:00'), isFalse);
      expect(() => NegocioServicio.minutosDesdeMedianoche('abc'), throwsFormatException);
    });
  });

  group('BloqueHorario y UsuarioPerfil', () {
    BloqueHorario clase(String id, int dia, int hora, [int min = 0]) => BloqueHorario(
          id: id,
          materia: 'Materia $id',
          diaSemana: dia,
          horaInicio: BloqueHorario.minutos(hora, min),
          horaFin: BloqueHorario.minutos(hora + 2, min),
          idEdificio: 'ed51',
          codigoSalon: '301',
        );

    final perfil = UsuarioPerfil.institucional(uid: 'u1', correoInstitucional: 'Ana.Perez@Javeriana.edu.co', rol: RolUsuario.estudiante);
    // 2026-11-17 es martes (weekday == 2).
    final martes9 = DateTime(2026, 11, 17, 9, 0);

    test('la fecha de prueba es martes', () => expect(martes9.weekday, DateTime.tuesday));

    test('obtenerProximaClase elige la de inicio más cercano del mismo día', () {
      final horario = <BloqueHorario>[clase('a', 2, 14), clase('b', 2, 10), clase('c', 3, 8)];
      expect(perfil.obtenerProximaClase(horario, martes9)?.id, 'b');
    });

    test('pasa al siguiente día o a la próxima semana cuando ya no hay más hoy', () {
      expect(perfil.obtenerProximaClase(<BloqueHorario>[clase('a', 2, 7), clase('c', 3, 8)], martes9)?.id, 'c');
      expect(perfil.obtenerProximaClase(<BloqueHorario>[clase('a', 2, 7)], martes9)?.id, 'a'); // martes siguiente
      expect(perfil.obtenerProximaClase(const <BloqueHorario>[], martes9), isNull);
    });

    test('la tolerancia de 10 min mantiene la clase recién empezada', () {
      final horario = <BloqueHorario>[clase('a', 2, 9), clase('b', 2, 11)];
      expect(perfil.obtenerProximaClase(horario, DateTime(2026, 11, 17, 9, 8))?.id, 'a');
      expect(perfil.obtenerProximaClase(horario, DateTime(2026, 11, 17, 9, 11))?.id, 'b');
    });

    test('cubre una clase que empezó justo antes de medianoche', () {
      final lunesNoche = BloqueHorario(
        id: 'n',
        materia: 'Materia n',
        diaSemana: 1,
        horaInicio: BloqueHorario.minutos(23, 55),
        horaFin: 1440, // medianoche
        idEdificio: 'ed51',
        codigoSalon: '301',
      );
      final martesMadrugada = DateTime(2026, 11, 17, 0, 3);
      expect(perfil.obtenerProximaClase(<BloqueHorario>[lunesNoche], martesMadrugada)?.id, 'n');
    });

    test('BloqueHorario valida rangos y formatea horas', () {
      expect(BloqueHorario.formatoHora(510), '08:30');
      expect(() => BloqueHorario(id: 'x', materia: 'm', diaSemana: 8, horaInicio: 0, horaFin: 60, idEdificio: 'e', codigoSalon: 's'), throwsA(isA<AssertionError>()));
      expect(() => BloqueHorario(id: 'x', materia: 'm', diaSemana: 1, horaInicio: 600, horaFin: 600, idEdificio: 'e', codigoSalon: 's'), throwsA(isA<AssertionError>()));
    });

    test('institucional normaliza el correo y arranca sin verificar ni opt-in', () {
      expect(perfil.correoInstitucional, 'ana.perez@javeriana.edu.co');
      expect(perfil.emailVerified, isFalse);
      expect(perfil.estado, EstadoCuenta.activo);
      expect(perfil.compartirUbicacionOptIn, isFalse);
      expect(perfil.consentimientoLey1581Aceptado, isFalse);
      expect(perfil.esInvitado, isFalse);
    });

    test('rechaza correos no institucionales', () {
      for (final correo in <String>['ana@gmail.com', 'ana@javeriana.edu', '@javeriana.edu.co', 'a b@javeriana.edu.co', 'ana@javeriana.edu.co.evil.com']) {
        expect(UsuarioPerfil.esCorreoInstitucional(correo), isFalse, reason: correo);
        expect(() => UsuarioPerfil.institucional(uid: 'u', correoInstitucional: correo, rol: RolUsuario.profesor), throwsArgumentError);
        expect(() => UsuarioPerfil.registro(uid: 'u', correoInstitucional: correo, tipo: RolUsuario.estudiante), throwsArgumentError);
      }
      expect(() => UsuarioPerfil.institucional(uid: '', correoInstitucional: 'a@javeriana.edu.co', rol: RolUsuario.estudiante), throwsArgumentError);
      expect(() => UsuarioPerfil.institucional(uid: 'u', correoInstitucional: 'a@javeriana.edu.co', rol: RolUsuario.invitado), throwsArgumentError);
    });

    test('el registro desde la app nunca puede crear un administrador', () {
      for (final tipo in <RolUsuario>[RolUsuario.admin, RolUsuario.invitado]) {
        expect(() => UsuarioPerfil.registro(uid: 'u', correoInstitucional: 'a@javeriana.edu.co', tipo: tipo), throwsArgumentError, reason: tipo.name);
      }
      for (final tipo in <RolUsuario>[RolUsuario.estudiante, RolUsuario.profesor, RolUsuario.administrativo]) {
        final p = UsuarioPerfil.registro(uid: 'u', correoInstitucional: 'a@javeriana.edu.co', tipo: tipo);
        expect(p.rol, tipo);
        expect(p.emailVerified, isFalse);
        expect(p.esAdministrador, isFalse);
      }
      // El rol admin solo existe al reconstruir una cuenta que el servidor ya marcó.
      final admin = UsuarioPerfil.institucional(uid: 'adm', correoInstitucional: 'adm@javeriana.edu.co', rol: RolUsuario.admin, emailVerified: true);
      expect(admin.esAdministrador, isTrue);
    });

    test('AuthState: visitante, no verificado, verificado, bloqueado y sin sesión', () {
      final verificado = perfil.copyWith(emailVerified: true);
      expect(authStateDe(null), AuthState.sinSesion);
      expect(authStateDe(UsuarioPerfil.invitado()), AuthState.visitante);
      expect(authStateDe(perfil), AuthState.institucionalNoVerificado);
      expect(authStateDe(verificado), AuthState.institucionalVerificado);
      expect(authStateDe(verificado.copyWith(estado: EstadoCuenta.bloqueado)), AuthState.bloqueado);
      // Bloqueado tiene prioridad aunque el correo esté sin verificar.
      expect(authStateDe(perfil.copyWith(estado: EstadoCuenta.bloqueado)), AuthState.bloqueado);
    });

    test('solo escribe quien tiene cuenta, correo verificado y estado activo', () {
      final verificado = perfil.copyWith(emailVerified: true);
      expect(UsuarioPerfil.invitado().puedeEscribir, isFalse);
      expect(perfil.puedeEscribir, isFalse, reason: 'emailVerified == false');
      expect(verificado.puedeEscribir, isTrue);
      expect(verificado.copyWith(estado: EstadoCuenta.bloqueado).puedeEscribir, isFalse);
    });

    test('un administrador sin verificar o bloqueado no administra', () {
      final admin = UsuarioPerfil.institucional(uid: 'adm', correoInstitucional: 'adm@javeriana.edu.co', rol: RolUsuario.admin);
      expect(admin.esAdministrador, isFalse);
      expect(admin.copyWith(emailVerified: true).esAdministrador, isTrue);
      expect(admin.copyWith(emailVerified: true, estado: EstadoCuenta.bloqueado).esAdministrador, isFalse);
    });

    test('el visitante no tiene uid, correo ni authorHash y no comparte ubicación', () {
      final invitado = UsuarioPerfil.invitado(consentimientoLey1581Aceptado: true);
      expect(invitado.uid, isNull);
      expect(invitado.correoInstitucional, isNull);
      expect(invitado.authorHash, isNull);
      expect(invitado.esInvitado, isTrue);
      expect(() => invitado.copyWith(uid: 'g1'), throwsA(isA<AssertionError>()));
      expect(invitado.copyWith(compartirUbicacionOptIn: true).compartirUbicacionOptIn, isFalse);
    });

    test('authorHash de la cuenta coincide con calcularAuthorHash(uid)', () {
      expect(perfil.authorHash, calcularAuthorHash('u1'));
      expect(perfil.authorHash, isNot(contains('u1')));
    });

    test('el opt-in exige correo verificado, cuenta activa y consentimiento', () {
      final base = perfil.copyWith(emailVerified: true, consentimientoLey1581Aceptado: true);
      final compartiendo = base.copyWith(compartirUbicacionOptIn: true);
      expect(compartiendo.compartirUbicacionOptIn, isTrue);
      // Se apaga solo al revocar el consentimiento, perder la verificación o ser bloqueado.
      expect(compartiendo.copyWith(consentimientoLey1581Aceptado: false).compartirUbicacionOptIn, isFalse);
      expect(compartiendo.copyWith(emailVerified: false).compartirUbicacionOptIn, isFalse);
      expect(compartiendo.copyWith(estado: EstadoCuenta.bloqueado).compartirUbicacionOptIn, isFalse);
      // No se puede activar si falta alguno.
      expect(perfil.copyWith(compartirUbicacionOptIn: true).compartirUbicacionOptIn, isFalse);
      expect(perfil.copyWith(consentimientoLey1581Aceptado: true).copyWith(compartirUbicacionOptIn: true).compartirUbicacionOptIn, isFalse, reason: 'sin verificar');
      expect(
        () => UsuarioPerfil.institucional(uid: 'u', correoInstitucional: 'a@javeriana.edu.co', rol: RolUsuario.estudiante, compartirUbicacionOptIn: true),
        throwsArgumentError,
      );
    });

    test('toString no filtra correo ni uid', () {
      expect(perfil.toString(), isNot(contains('javeriana')));
      expect(perfil.toString(), isNot(contains('u1')));
    });
  });

  group('Edificios sin número y pisos (campus real)', () {
    Edificio biblioteca() => Edificio(
          id: 'biblioteca',
          numero: null,
          nombre: 'Biblioteca General Alfonso Borrero Cabal',
          ubicacion: LatLng(4.62874, -74.06455),
          niveles: 6,
          salones: const <Salon>[
            Salon(codigo: 'BIB-SALA1', piso: 2, idEdificio: 'biblioteca', nombreEdificio: 'Biblioteca General Alfonso Borrero Cabal', numeroEdificio: null),
          ],
        );

    test('un edificio sin número se etiqueta con su nombre', () {
      final e = biblioteca();
      expect(e.numero, isNull);
      expect(e.etiqueta, 'Biblioteca General Alfonso Borrero Cabal');
      expect(e.salones.single.etiquetaUbicacion(), 'Biblioteca General Alfonso Borrero Cabal · Piso 2');
      expect(e.coincideConBusqueda('borrero cabal'), isTrue);
      expect(e.coincideConBusqueda('2'), isFalse, reason: 'no tiene número que coincida');
      expect(e.copyWith(numero: 5, salones: const <Salon>[]).etiqueta, 'Edificio 5');
      expect(e.copyWith(niveles: null).niveles, isNull);
    });

    test('niveles define los pisos y ningún salón puede estar por encima', () {
      expect(biblioteca().pisos, <int>[1, 2, 3, 4, 5, 6]);
      expect(Edificio(id: 'x', numero: 1, nombre: 'X', ubicacion: LatLng(0, 0)).pisos, isEmpty);
      expect(
        () => Edificio(
          id: 'x',
          numero: 1,
          nombre: 'X',
          ubicacion: LatLng(0, 0),
          niveles: 2,
          salones: const <Salon>[Salon(codigo: '1-301', piso: 3, idEdificio: 'x', nombreEdificio: 'X', numeroEdificio: 1)],
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(() => Edificio(id: 'x', numero: 1, nombre: 'X', ubicacion: LatLng(0, 0), niveles: 0), throwsA(isA<AssertionError>()));
      expect(() => Edificio(id: 'x', numero: 0, nombre: 'X', ubicacion: LatLng(0, 0)), throwsA(isA<AssertionError>()));
    });

    test('NegocioServicio distingue "dentro de" un edificio y "horario por confirmar"', () {
      final n = NegocioServicio(
        id: 'k',
        nombre: 'Kiosko',
        categoria: CategoriaServicio.biblioteca,
        ubicacion: LatLng(4.6, -74.06),
        idEdificioCercano: 'ed21',
        horaApertura: '07:00',
        horaCierre: '19:00',
      );
      expect(n.dentroDeEdificio, isTrue);
      expect(n.horarioConfirmado, isTrue);
      expect(n.piso, 1);
      final propio = n.copyWith(dentroDeEdificio: false, horarioConfirmado: false, piso: 2);
      expect(propio.dentroDeEdificio, isFalse);
      expect(propio.horarioConfirmado, isFalse);
      expect(propio.piso, 2);
      expect(propio, isNot(n));
      expect(CategoriaServicio.values, containsAll(<CategoriaServicio>[CategoriaServicio.biblioteca, CategoriaServicio.salud]));
    });
  });

  group('Acceso vertical del edificio', () {
    Edificio edificio({
      int? niveles = 5,
      bool ascensor = false,
      bool multiples = false,
      bool movilidad = false,
      bool confirmada = true,
    }) =>
        Edificio(
          id: 'x',
          numero: 7,
          nombre: 'Siete',
          ubicacion: LatLng(4.6, -74.06),
          niveles: niveles,
          tieneAscensor: ascensor,
          tieneMultiplesAscensores: multiples,
          tieneAccesoMovilidadReducida: movilidad,
          accesibilidadConfirmada: confirmada,
        );

    test('con varios ascensores se llega a los pisos altos y lo dice', () {
      final e = edificio(ascensor: true, multiples: true, movilidad: true);
      expect(e.puedeLlegarEnAscensor(2), isTrue);
      expect(e.puedeLlegarEnAscensor(5), isTrue);
      expect(e.etiquetaAccesibilidadVertical(3), 'Acceso por ascensor disponible (múltiples ascensores)');
      final acceso = e.accesoVertical(3, evitarEscaleras: true);
      expect(acceso.llegaEnAscensor, isTrue);
      expect(acceso.multiplesAscensores, isTrue);
      expect(acceso.advertencia, isNull);
    });

    test('con un solo ascensor lo dice sin "múltiples"', () {
      final e = edificio(ascensor: true, movilidad: true);
      expect(e.puedeLlegarEnAscensor(4), isTrue);
      expect(e.etiquetaAccesibilidadVertical(4), 'Acceso por ascensor disponible');
      expect(e.accesoVertical(4).multiplesAscensores, isFalse);
    });

    test('sin ascensor, los pisos altos solo se alcanzan por escaleras internas', () {
      final e = edificio(niveles: 2);
      expect(e.puedeLlegarEnAscensor(2), isFalse);
      expect(e.etiquetaAccesibilidadVertical(2), 'Sin ascensor (solo escaleras internas para piso 2)');
      expect(e.accesoVertical(2).advertencia, isNull, reason: 'sin pedir evitar escaleras no hay aviso');
      final aviso = e.accesoVertical(2, evitarEscaleras: true);
      expect(aviso.llegaEnAscensor, isFalse);
      expect(aviso.advertencia, allOf(contains('Edificio 7'), contains('no tiene ascensor'), contains('piso 2')));
    });

    test('piso 1 depende de la entrada (nivel o rampa); los sótanos exigen ascensor', () {
      final conRampa = edificio(niveles: 1, movilidad: true);
      expect(conRampa.puedeLlegarEnAscensor(1), isTrue);
      expect(conRampa.etiquetaAccesibilidadVertical(1), 'Acceso a nivel o por rampa');
      final conEscalones = edificio(niveles: 2);
      expect(conEscalones.puedeLlegarEnAscensor(1), isFalse);
      expect(conEscalones.etiquetaAccesibilidadVertical(1), 'Acceso al piso 1 con escalones (sin rampa)');
      expect(conEscalones.accesoVertical(1, evitarEscaleras: true).advertencia, contains('escalones'));
      // El piso 0 no existe y sin sótanos no se puede bajar a -1.
      expect(conRampa.puedeLlegarEnAscensor(0), isFalse);
      expect(conRampa.etiquetaAccesibilidadVertical(0), contains('piso 0 no existe'));
      expect(conRampa.puedeLlegarEnAscensor(-1), isFalse);
      expect(conRampa.etiquetaAccesibilidadVertical(-1), contains('no tiene sótanos'));
    });

    test('sótanos: requieren ascensor y validan el límite inferior', () {
      final conSotanosYAscensor = Edificio(
        id: 'ed12',
        numero: 12,
        nombre: 'Laboratorios',
        ubicacion: LatLng(4.6, -74.06),
        niveles: 15,
        sotanos: 2,
        tieneAscensor: true,
        tieneMultiplesAscensores: true,
        tieneAccesoMovilidadReducida: true,
        accesibilidadConfirmada: true,
      );
      expect(conSotanosYAscensor.pisosSotano, <int>[-1, -2]);
      expect(conSotanosYAscensor.puedeLlegarEnAscensor(-1), isTrue);
      expect(conSotanosYAscensor.puedeLlegarEnAscensor(-2), isTrue);
      expect(conSotanosYAscensor.puedeLlegarEnAscensor(-3), isFalse);
      expect(conSotanosYAscensor.etiquetaAccesibilidadVertical(-1), 'Acceso por ascensor disponible (múltiples ascensores)');
      expect(conSotanosYAscensor.etiquetaAccesibilidadVertical(-3), contains('tiene 2 sótanos'));

      final conSotanoSinAscensor = Edificio(
        id: 'x',
        numero: 9,
        nombre: 'Nueve',
        ubicacion: LatLng(4.6, -74.06),
        niveles: 2,
        sotanos: 1,
        tieneAccesoMovilidadReducida: true,
        accesibilidadConfirmada: true,
      );
      expect(conSotanoSinAscensor.puedeLlegarEnAscensor(1), isTrue);
      expect(conSotanoSinAscensor.puedeLlegarEnAscensor(-1), isFalse, reason: 'bajar al sótano requiere ascensor');
      expect(conSotanoSinAscensor.etiquetaAccesibilidadVertical(-1), 'Sin ascensor (solo escaleras internas para sótano 1)');
      expect(conSotanoSinAscensor.accesoVertical(-1, evitarEscaleras: true).advertencia, contains('sótano 1 solo se alcanza por escaleras internas'));
    });

    test('sin confirmar nunca promete acceso: dice "sin confirmar", no "sin ascensor"', () {
      final e = edificio(confirmada: false);
      expect(e.puedeLlegarEnAscensor(1), isFalse);
      expect(e.puedeLlegarEnAscensor(3), isFalse);
      expect(e.etiquetaAccesibilidadVertical(3), 'Acceso por ascensor sin confirmar para el piso 3');
      expect(e.etiquetaAccesibilidadVertical(3), isNot(contains('Sin ascensor')));
      expect(e.accesoVertical(3, evitarEscaleras: true).advertencia, contains('no se sabe'));
    });

    test('un piso que no existe no es alcanzable', () {
      final e = edificio(niveles: 2, ascensor: true, movilidad: true);
      expect(e.puedeLlegarEnAscensor(3), isFalse);
      expect(e.etiquetaAccesibilidadVertical(3), contains('no existe'));
      expect(e.accesoVertical(3, evitarEscaleras: true).advertencia, contains('no existe'));
    });

    test('los invariantes de accesibilidad se validan', () {
      expect(() => edificio(multiples: true), throwsA(isA<AssertionError>()), reason: 'varios ascensores sin ascensor');
      expect(() => edificio(niveles: 1, ascensor: true), throwsA(isA<AssertionError>()), reason: 'ascensor en un solo nivel');
      expect(() => edificio(confirmada: false, ascensor: true), throwsA(isA<AssertionError>()), reason: 'sin confirmar no puede decir "sí"');
      expect(() => edificio(confirmada: false, movilidad: true), throwsA(isA<AssertionError>()));
      final e = edificio(ascensor: true, multiples: true, movilidad: true);
      expect(() => e.copyWith(tieneAscensor: false), throwsA(isA<AssertionError>()), reason: 'quedarían varios ascensores sin ascensor');
    });

    test('copyWith e igualdad incluyen los campos de accesibilidad', () {
      final e = edificio(ascensor: true, movilidad: true);
      expect(e.copyWith(tieneMultiplesAscensores: true).tieneMultiplesAscensores, isTrue);
      expect(e.copyWith(tieneMultiplesAscensores: true), isNot(e));
      expect(e.copyWith(), e);
      expect(e.accesoVertical(2), e.accesoVertical(2));
    });
  });
}
