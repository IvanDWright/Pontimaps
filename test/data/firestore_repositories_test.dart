import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:pontimaps_app/core/utils/author_hash.dart';
import 'package:pontimaps_app/data/admin_repository.dart';
import 'package:pontimaps_app/data/auth_repository.dart';
import 'package:pontimaps_app/data/firebase_auth_repository.dart';
import 'package:pontimaps_app/data/firestore_repositories.dart';
import 'package:pontimaps_app/domain/services/moderation_service.dart';
import 'package:pontimaps_app/models/horario_usuario.dart';
import 'package:pontimaps_app/models/reporte_comunidad.dart';

/// Estas pruebas usan Firestore y Firebase Auth *simulados*: verifican la lógica
/// de los repositorios (qué documentos se escriben y qué ve cada cliente). **No**
/// evalúan `firestore.rules`; eso exige el Firebase Emulator Suite.
void main() {
  const punto = LatLng(4.6285, -74.0645);
  final t0 = DateTime.utc(2026, 11, 18, 15);
  final hashAutor = calcularAuthorHash('u-autor');
  final hashAna = calcularAuthorHash('u-ana');

  late FakeFirebaseFirestore db;
  late DateTime ahora;
  late FirestoreReportsRepository reportes;

  Future<void> cuenta(String uid, String hash, {String rol = 'estudiante', String estado = 'activo'}) =>
      db.collection('users').doc(uid).set(<String, Object?>{
        'rol': rol,
        'estado': estado,
        'authorHash': hash,
      });

  setUp(() async {
    db = FakeFirebaseFirestore();
    ahora = t0;
    await cuenta('u-autor', hashAutor);
    await cuenta('u-ana', hashAna);
    reportes = FirestoreReportsRepository(
      firestore: db,
      uidActual: () => 'u-autor',
      reloj: () => ahora,
    );
    await pumpEventQueue();
  });

  tearDown(() => reportes.cerrar());

  Future<ReporteComunidad> publicar({TipoReporte tipo = TipoReporte.cierre, String arista = 'a1'}) async {
    final r = await reportes.publicar(tipo: tipo, ubicacion: punto, autorHash: hashAutor, idArista: arista);
    expect(r.publicado, isTrue);
    await pumpEventQueue();
    return r.reporte!;
  }

  group('FirestoreReportsRepository · publicar', () {
    test('el documento público no tiene autor y la autoría va aparte', () async {
      final r = await publicar();

      final publico = (await db.collection('reports').doc(r.id).get()).data()!;
      expect(publico.keys, isNot(contains('authorHash')));
      expect(publico.keys, isNot(contains('uid')));
      expect(publico.values.whereType<String>(), isNot(contains(hashAutor)));
      expect(publico['tipo'], 'cierre');
      expect(publico['confirmaciones'], 0);
      expect(publico['reportesNegativos'], 0);
      expect(publico['idAristaAfectada'], 'a1');

      final creado = (publico['creadoEn'] as Timestamp).toDate();
      final expira = (publico['expiraEn'] as Timestamp).toDate();
      expect(expira.difference(creado), const Duration(minutes: 60));

      final autoria = (await db.collection('reportAuthors').doc(r.id).get()).data()!;
      expect(autoria['authorHash'], hashAutor);
      expect(autoria.keys.toSet(), <String>{'authorHash', 'borrarEn'});

      final perfil = (await db.collection('users').doc('u-autor').get()).data()!;
      expect(perfil['ultimoReporteEn'], isA<Timestamp>());
    });

    test('toda vista pública sale sin authorHash', () async {
      final r = await publicar();
      expect(r.authorHash, isNull);
      expect(reportes.vigentes().single.authorHash, isNull);
      expect(reportes.vigentes().single.toString(), isNot(contains(hashAutor)));
      expect(await reportes.observar().first, everyElement(predicate<ReporteComunidad>((x) => x.authorHash == null)));
    });

    test('expira exactamente a los 60 minutos con el reloj inyectado', () async {
      await publicar();
      ahora = t0.add(const Duration(minutes: 59, seconds: 59));
      expect(reportes.vigentes(), hasLength(1));
      ahora = t0.add(const Duration(minutes: 60));
      expect(reportes.vigentes(), isEmpty);
    });

    test('exige el intervalo mínimo y ofrece confirmar un duplicado', () async {
      await publicar(arista: 'a1');

      ahora = t0.add(const Duration(seconds: 30));
      final pronto = await reportes.publicar(
        tipo: TipoReporte.fila,
        ubicacion: punto,
        autorHash: hashAutor,
        idArista: 'a2',
      );
      expect(pronto.resultado, ResultadoPublicacion.demasiadoPronto);

      ahora = t0.add(const Duration(minutes: 2));
      final duplicado = await reportes.publicar(
        tipo: TipoReporte.cierre,
        ubicacion: punto,
        autorHash: hashAutor,
        idArista: 'a1',
      );
      expect(duplicado.resultado, ResultadoPublicacion.duplicado);
      expect(duplicado.duplicado!.authorHash, isNull);
      expect((await db.collection('reports').get()).docs, hasLength(1));
    });

    test('una fila se ancla a su lugar (idLugar)', () async {
      final r = await reportes.publicar(
        tipo: TipoReporte.fila,
        ubicacion: punto,
        autorHash: hashAutor,
        idLugar: 'cafeteria-la-central',
      );
      await pumpEventQueue();
      expect((await db.collection('reports').doc(r.reporte!.id).get()).data()!['idLugar'], 'cafeteria-la-central');
      expect(reportes.vigentes().single.idLugar, 'cafeteria-la-central');
    });

    test('sin sesión no se publica', () async {
      final sinSesion = FirestoreReportsRepository(firestore: db, uidActual: () => null, reloj: () => ahora);
      expect(
        () => sinSesion.publicar(tipo: TipoReporte.cierre, ubicacion: punto, autorHash: hashAutor),
        throwsStateError,
      );
      await sinSesion.cerrar();
    });
  });

  group('FirestoreReportsRepository · votos', () {
    test('«Sigue ahí» escribe el voto con id = authorHash y extiende +30 min', () async {
      final r = await publicar();
      final res = await reportes.calificar(idReporte: r.id, votanteHash: hashAna, voto: VotoReporte.sigueAhi);
      await pumpEventQueue();

      expect(res, ResultadoVoto.registrado);
      final voto = (await db.collection('reports').doc(r.id).collection('votes').doc(hashAna).get()).data()!;
      expect(voto['valor'], 1);
      final doc = (await db.collection('reports').doc(r.id).get()).data()!;
      expect(doc['confirmaciones'], 1);
      expect((doc['expiraEn'] as Timestamp).toDate().toUtc(), t0.add(const Duration(minutes: 90)));
      expect(reportes.vigentes().single.confirmaciones, 1);
    });

    test('un voto por cuenta: el segundo se rechaza', () async {
      final r = await publicar();
      await reportes.calificar(idReporte: r.id, votanteHash: hashAna, voto: VotoReporte.sigueAhi);
      await pumpEventQueue();
      final segundo = await reportes.calificar(idReporte: r.id, votanteHash: hashAna, voto: VotoReporte.falso);

      expect(segundo, ResultadoVoto.yaVoto);
      expect((await db.collection('reports').doc(r.id).get()).data()!['reportesNegativos'], 0);
    });

    test('el autor no vota su propio reporte', () async {
      final r = await publicar();
      final res = await reportes.calificar(idReporte: r.id, votanteHash: hashAutor, voto: VotoReporte.sigueAhi);
      expect(res, ResultadoVoto.esAutor);
      expect((await db.collection('reports').doc(r.id).collection('votes').get()).docs, isEmpty);
    });

    test('con 3 votos negativos el reporte se oculta y no se revive', () async {
      final r = await publicar();
      for (final h in <String>['n1', 'n2', 'n3']) {
        await reportes.calificar(idReporte: r.id, votanteHash: calcularAuthorHash(h), voto: VotoReporte.falso);
        await pumpEventQueue();
      }
      expect(reportes.vigentes(), isEmpty);
      final tardio = await reportes.calificar(
        idReporte: r.id,
        votanteHash: calcularAuthorHash('c1'),
        voto: VotoReporte.sigueAhi,
      );
      expect(tardio, ResultadoVoto.noVigente);
    });

    test('el tope de 180 minutos se respeta', () async {
      final r = await publicar();
      for (var i = 0; i < 8; i++) {
        await reportes.calificar(idReporte: r.id, votanteHash: calcularAuthorHash('c$i'), voto: VotoReporte.sigueAhi);
        await pumpEventQueue();
      }
      final expira = (await db.collection('reports').doc(r.id).get()).data()!['expiraEn'] as Timestamp;
      expect(expira.toDate().toUtc(), t0.add(const Duration(minutes: 180)));
    });
  });

  group('reporteDeDocumento', () {
    test('lee un documento válido y descarta los dañados', () {
      final valido = <String, dynamic>{
        'tipo': 'fila',
        'lat': 4.6,
        'lng': -74.06,
        'creadoEn': Timestamp.fromDate(t0),
        'expiraEn': Timestamp.fromDate(t0.add(const Duration(minutes: 60))),
        'confirmaciones': 0,
        'reportesNegativos': 0,
      };
      expect(reporteDeDocumento('x', valido)!.tipo, TipoReporte.fila);
      expect(reporteDeDocumento('x', <String, dynamic>{...valido, 'tipo': 'otro'}), isNull);
      expect(reporteDeDocumento('x', <String, dynamic>{...valido, 'expiraEn': Timestamp.fromDate(t0)}), isNull);
      expect(reporteDeDocumento('x', <String, dynamic>{'tipo': 'fila'}), isNull);
      expect(reporteDeDocumento('x', null), isNull);
    });
  });

  group('FirestoreAdminRepository', () {
    late FirestoreAdminRepository admin;
    var esAdmin = true;

    setUp(() async {
      esAdmin = true;
      await cuenta('u-admin', calcularAuthorHash('u-admin'), rol: 'admin');
      admin = FirestoreAdminRepository(
        firestore: db,
        uidActual: () => 'u-admin',
        esAdmin: () => esAdmin,
        reloj: () => ahora,
      );
    });

    test('lista los reportes activos en tiempo real, sin autor', () async {
      await publicar();
      final lista = await admin.reportesActivos().first;
      expect(lista, hasLength(1));
      expect(lista.single.authorHash, isNull);
    });

    test('«Eliminar reporte» lo borra de todos y deja constancia en la bitácora', () async {
      final r = await publicar();
      expect(await admin.eliminarReporte(r.id), ResultadoModeracion.hecho);
      await pumpEventQueue();

      expect((await db.collection('reports').doc(r.id).get()).exists, isFalse);
      expect((await db.collection('reportAuthors').doc(r.id).get()).exists, isFalse);
      expect(reportes.vigentes(), isEmpty);
      final acciones = (await db.collection('adminActions').get()).docs;
      expect(acciones, hasLength(1));
      expect(acciones.single.data()['que'], 'eliminarReporte');
      expect(acciones.single.data()['quien'], 'u-admin');
    });

    test('«Bloquear autor» pone estado = bloqueado a la cuenta con ese authorHash', () async {
      final r = await publicar();
      expect(await admin.bloquearAutor(r.id), ResultadoModeracion.hecho);

      expect((await db.collection('users').doc('u-autor').get()).data()!['estado'], 'bloqueado');
      expect((await db.collection('users').doc('u-ana').get()).data()!['estado'], 'activo');
      final accion = (await db.collection('adminActions').get()).docs.single.data();
      expect(accion['que'], 'bloquearAutor');
      expect(accion['aQuien'], 'u-autor');
    });

    test('sin rol de administrador no hace nada', () async {
      final r = await publicar();
      esAdmin = false;
      expect(await admin.eliminarReporte(r.id), ResultadoModeracion.sinPermiso);
      expect(await admin.bloquearAutor(r.id), ResultadoModeracion.sinPermiso);
      expect((await db.collection('reports').doc(r.id).get()).exists, isTrue);
      expect((await db.collection('users').doc('u-autor').get()).data()!['estado'], 'activo');
    });

    test('reporta cuando el reporte o el autor no existen', () async {
      expect(await admin.eliminarReporte('no-existe'), ResultadoModeracion.noEncontrado);
      expect(await admin.bloquearAutor('no-existe'), ResultadoModeracion.autorNoEncontrado);

      final r = await publicar();
      await db.collection('users').doc('u-autor').delete();
      expect(await admin.bloquearAutor(r.id), ResultadoModeracion.autorNoEncontrado);
    });
  });

  group('FirestoreOfficialAlertsRepository', () {
    test('publica una alerta oficial fija y la cierra', () async {
      final alertas = FirestoreOfficialAlertsRepository(firestore: db, reloj: () => ahora);
      await pumpEventQueue();

      final a = await alertas.publicar(mensaje: 'Evento en la plazoleta', ubicacion: punto);
      await pumpEventQueue();
      final doc = (await db.collection('officialAlerts').doc(a.id).get()).data()!;
      expect(doc['tipo'], 'oficial');
      expect(doc.keys, isNot(contains('hasta')), reason: 'sin expiración automática');
      expect(alertas.vigentes().single.mensaje, 'Evento en la plazoleta');

      ahora = t0.add(const Duration(days: 20));
      expect(alertas.vigentes(), hasLength(1));

      await alertas.cerrar(a.id);
      await pumpEventQueue();
      expect(alertas.vigentes(), isEmpty);
      expect((await db.collection('officialAlerts').get()).docs, isEmpty);
      await alertas.cerrarFlujo();
    });
  });

  group('FirebaseAuthRepository (Firebase Auth simulado)', () {
    const correo = 'maria.gomez@javeriana.edu.co';
    const clave = 'Segura#2026';

    test('registra y crea el perfil users/{uid} sin rol de administrador', () async {
      final auth = MockFirebaseAuth();
      final repo = FirebaseAuthRepository(auth: auth, firestore: db);

      await repo.registrar(correo: correo, contrasena: clave, tipo: RolUsuario.profesor);
      await pumpEventQueue();

      final uid = auth.currentUser!.uid;
      final perfil = (await db.collection('users').doc(uid).get()).data()!;
      expect(perfil['rol'], 'profesor');
      expect(perfil['estado'], 'activo');
      expect(perfil['authorHash'], calcularAuthorHash(uid));
      expect((perfil['authorHash'] as String).length, 64);
      expect(perfil.keys.toSet(), <String>{'rol', 'estado', 'authorHash', 'createdAt', 'consent'});

      final cuenta = repo.actual!;
      expect(cuenta.correo, correo);
      expect(cuenta.rol, RolUsuario.profesor);
      // (El simulador de Firebase Auth da el correo por verificado; la espera de
      // verificación se prueba con InMemoryAuthRepository y en los widgets.)
      await repo.cerrar();
    });

    test('valida antes de llamar al servidor (dominio, contraseña y rol)', () async {
      final repo = FirebaseAuthRepository(auth: MockFirebaseAuth(), firestore: db);
      Future<ErrorAuth> error(String c, String p, RolUsuario t) async {
        try {
          await repo.registrar(correo: c, contrasena: p, tipo: t);
        } on AuthException catch (e) {
          return e.codigo;
        }
        fail('Debía fallar');
      }

      expect(await error('a@gmail.com', clave, RolUsuario.estudiante), ErrorAuth.correoNoInstitucional);
      expect(await error(correo, 'debil', RolUsuario.estudiante), ErrorAuth.contrasenaDebil);
      expect(await error(correo, clave, RolUsuario.admin), ErrorAuth.rolInvalido);
      await repo.cerrar();
    });

    test('traduce los errores de Firebase sin revelar si el correo existe', () async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'email-already-in-use'));
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'user-not-found'));
      final duplicado = FirebaseAuthRepository(auth: auth, firestore: db);
      Future<ErrorAuth> error(Future<void> Function() accion) async {
        try {
          await accion();
        } on AuthException catch (e) {
          return e.codigo;
        }
        fail('Debía fallar');
      }

      expect(
        await error(() => duplicado.registrar(correo: correo, contrasena: clave, tipo: RolUsuario.estudiante)),
        ErrorAuth.correoYaRegistrado,
      );
      expect(
        await error(() => duplicado.iniciarSesion(correo: correo, contrasena: clave)),
        ErrorAuth.credencialesInvalidas,
      );
      await duplicado.cerrar();
    });

    test('el rol y el estado salen de users/{uid}: admin lo asigna la consola y el bloqueo degrada', () async {
      final usuario = MockUser(uid: 'u-admin', email: 'admin@javeriana.edu.co', isEmailVerified: true);
      final auth = MockFirebaseAuth(mockUser: usuario, signedIn: true);
      await db.collection('users').doc('u-admin').set(<String, Object?>{'rol': 'estudiante', 'estado': 'activo'});
      final repo = FirebaseAuthRepository(auth: auth, firestore: db);
      await pumpEventQueue();

      expect(repo.actual!.rol, RolUsuario.estudiante);
      expect(repo.actual!.toPerfil().esAdministrador, isFalse);

      // La consola de Firebase asigna el rol admin.
      await db.collection('users').doc('u-admin').update(<String, Object?>{'rol': 'admin'});
      await pumpEventQueue();
      expect(repo.actual!.rol, RolUsuario.admin);
      expect(repo.actual!.toPerfil().esAdministrador, isTrue);

      // Otro administrador la bloquea: la app la degrada a Visitante (solo lectura).
      await db.collection('users').doc('u-admin').update(<String, Object?>{'estado': 'bloqueado'});
      await pumpEventQueue();
      expect(repo.actual!.estado, EstadoCuenta.bloqueado);
      expect(repo.actual!.toPerfil().authState, AuthState.bloqueado);
      expect(repo.actual!.toPerfil().esAdministrador, isFalse);
      await repo.cerrar();
    });

    test('un valor de rol desconocido nunca otorga administrador', () async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'a@javeriana.edu.co', isEmailVerified: true),
        signedIn: true,
      );
      await db.collection('users').doc('u1').set(<String, Object?>{'rol': 'superusuario', 'estado': 'activo'});
      final repo = FirebaseAuthRepository(auth: auth, firestore: db);
      await pumpEventQueue();
      expect(repo.actual!.rol, RolUsuario.estudiante);
      await repo.cerrar();
    });

    test('cerrar sesión emite null', () async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'a@javeriana.edu.co', isEmailVerified: true),
        signedIn: true,
      );
      final repo = FirebaseAuthRepository(auth: auth, firestore: db);
      await pumpEventQueue();
      expect(repo.actual, isNotNull);

      await repo.cerrarSesion();
      await pumpEventQueue();
      expect(repo.actual, isNull);
      await repo.cerrar();
    });
  });
}
