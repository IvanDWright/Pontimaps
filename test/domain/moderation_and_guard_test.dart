import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pontimaps_app/core/utils/author_hash.dart';
import 'package:pontimaps_app/data/reports_repository.dart';
import 'package:pontimaps_app/domain/services/auth_guard.dart';
import 'package:pontimaps_app/domain/services/moderation_service.dart';
import 'package:pontimaps_app/models/horario_usuario.dart';
import 'package:pontimaps_app/models/reporte_comunidad.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 18, 15);
  final autor = calcularAuthorHash('uid-autor');
  final ana = calcularAuthorHash('uid-ana');
  const punto = LatLng(4.6285, -74.0645);

  ReporteComunidad nuevo({String? hash, TipoReporte tipo = TipoReporte.cierre}) =>
      ReporteComunidad.nuevo(
        id: 'r1',
        tipo: tipo,
        ubicacion: punto,
        ahora: t0,
        authorHash: hash ?? autor,
      );

  group('Expiración exacta a 60 min con reloj inyectable (RF-REP-03)', () {
    test('a 59:59 sigue vigente y a 60:00 ya no', () {
      final r = nuevo();
      expect(r.estaVigente(t0.add(const Duration(minutes: 59, seconds: 59))), isTrue);
      expect(r.estaVigente(t0.add(const Duration(minutes: 60))), isFalse);
    });

    test('el repositorio filtra por expiraEn con el reloj inyectado', () async {
      var ahora = t0;
      final repo = InMemoryReportsRepository(reloj: () => ahora);
      await repo.publicar(tipo: TipoReporte.fila, ubicacion: punto, autorHash: autor, idArista: 'a1');
      expect(repo.vigentes(), hasLength(1));

      ahora = t0.add(const Duration(minutes: 59, seconds: 59));
      expect(repo.vigentes(), hasLength(1));

      ahora = t0.add(const Duration(minutes: 60));
      expect(repo.vigentes(), isEmpty);
    });

    test('refrescar() avisa al flujo cuando un reporte vence', () async {
      var ahora = t0;
      final repo = InMemoryReportsRepository(reloj: () => ahora);
      await repo.publicar(tipo: TipoReporte.fila, ubicacion: punto, autorHash: autor, idArista: 'a1');

      final emisiones = <int>[];
      final suscripcion = repo.observar().listen((l) => emisiones.add(l.length));
      await Future<void>.delayed(Duration.zero);
      ahora = t0.add(const Duration(minutes: 61));
      repo.refrescar();
      await Future<void>.delayed(Duration.zero);
      await suscripcion.cancel();

      expect(emisiones, <int>[1, 0]);
    });
  });

  group('Calificación comunitaria (RF-REP-04 y RF-REP-05)', () {
    test('«Sigue ahí» suma una confirmación y extiende +30 min', () {
      final r = ModerationService.calificar(
        reporte: nuevo(),
        votanteHash: ana,
        voto: VotoReporte.sigueAhi,
        votantesPrevios: <String>{},
        ahora: t0.add(const Duration(minutes: 10)),
      );
      expect(r.resultado, ResultadoVoto.registrado);
      expect(r.reporte.confirmaciones, 1);
      expect(r.reporte.expiraEn, t0.add(const Duration(minutes: 90)));
    });

    test('las extensiones tienen tope de 180 min desde creadoEn', () {
      var reporte = nuevo();
      for (var i = 0; i < 8; i++) {
        reporte = reporte.confirmar(t0.add(Duration(minutes: i)));
      }
      expect(reporte.confirmaciones, 8);
      expect(reporte.expiraEn, t0.add(const Duration(minutes: 180)));
      expect(reporte.estaVigente(t0.add(const Duration(minutes: 179, seconds: 59))), isTrue);
      expect(reporte.estaVigente(t0.add(const Duration(minutes: 180))), isFalse);
    });

    test('«Falso / Ya no está» suma un voto negativo', () {
      final r = ModerationService.calificar(
        reporte: nuevo(),
        votanteHash: ana,
        voto: VotoReporte.falso,
        votantesPrevios: <String>{},
        ahora: t0,
      );
      expect(r.reporte.reportesNegativos, 1);
      expect(r.reporte.estaVigente(t0), isTrue);
    });

    test('el autor no vota su propio reporte', () {
      final r = ModerationService.calificar(
        reporte: nuevo(),
        votanteHash: autor,
        voto: VotoReporte.sigueAhi,
        votantesPrevios: <String>{},
        ahora: t0,
      );
      expect(r.resultado, ResultadoVoto.esAutor);
      expect(r.reporte.confirmaciones, 0);
    });

    test('un voto por cuenta y reporte, sea cual sea el voto', () {
      final r = ModerationService.calificar(
        reporte: nuevo(),
        votanteHash: ana,
        voto: VotoReporte.falso,
        votantesPrevios: <String>{ana},
        ahora: t0,
      );
      expect(r.resultado, ResultadoVoto.yaVoto);
      expect(r.reporte.reportesNegativos, 0);
    });

    test('con 3 votos negativos se oculta al instante, aunque tenga confirmaciones', () async {
      final repo = InMemoryReportsRepository(reloj: () => t0);
      await repo.publicar(tipo: TipoReporte.cierre, ubicacion: punto, autorHash: autor, idArista: 'a1');
      final id = repo.vigentes().single.id;

      await repo.calificar(idReporte: id, votanteHash: calcularAuthorHash('c1'), voto: VotoReporte.sigueAhi);
      await repo.calificar(idReporte: id, votanteHash: calcularAuthorHash('c2'), voto: VotoReporte.sigueAhi);
      expect(repo.vigentes().single.confirmaciones, 2);

      await repo.calificar(idReporte: id, votanteHash: calcularAuthorHash('n1'), voto: VotoReporte.falso);
      await repo.calificar(idReporte: id, votanteHash: calcularAuthorHash('n2'), voto: VotoReporte.falso);
      expect(repo.vigentes(), hasLength(1), reason: '2 negativos y 2 confirmaciones siguen vigente');

      await repo.calificar(idReporte: id, votanteHash: calcularAuthorHash('n3'), voto: VotoReporte.falso);
      expect(repo.vigentes(), isEmpty);
    });

    test('un reporte oculto o vencido no se califica ni se revive', () async {
      var ahora = t0;
      final repo = InMemoryReportsRepository(reloj: () => ahora);
      await repo.publicar(tipo: TipoReporte.cierre, ubicacion: punto, autorHash: autor, idArista: 'a1');
      final id = repo.vigentes().single.id;

      ahora = t0.add(const Duration(minutes: 61));
      final r = await repo.calificar(idReporte: id, votanteHash: ana, voto: VotoReporte.sigueAhi);
      expect(r, ResultadoVoto.noVigente);
      expect(repo.vigentes(), isEmpty);

      // Ni el modelo permite revivirlo: confirmar un reporte vencido u oculto no
      // cambia nada (misma instancia, mismo expiraEn).
      final vencido = nuevo();
      final tarde = t0.add(const Duration(minutes: 61));
      expect(identical(vencido.confirmar(tarde), vencido), isTrue);
      final oculto = nuevo().negar().negar().negar();
      expect(oculto.estaVigente(t0), isFalse);
      expect(identical(oculto.confirmar(t0), oculto), isTrue);
      expect(oculto.expiraEn, nuevo().expiraEn);
    });
  });

  group('Publicar (RF-REP-06)', () {
    test('intervalo mínimo entre reportes de la misma cuenta', () async {
      var ahora = t0;
      final repo = InMemoryReportsRepository(reloj: () => ahora);
      final primero = await repo.publicar(
        tipo: TipoReporte.fila,
        ubicacion: punto,
        autorHash: autor,
        idArista: 'a1',
      );
      expect(primero.publicado, isTrue);

      ahora = t0.add(const Duration(seconds: 30));
      final segundo = await repo.publicar(
        tipo: TipoReporte.cierre,
        ubicacion: punto,
        autorHash: autor,
        idArista: 'a2',
      );
      expect(segundo.resultado, ResultadoPublicacion.demasiadoPronto);

      ahora = t0.add(const Duration(minutes: 1));
      final tercero = await repo.publicar(
        tipo: TipoReporte.cierre,
        ubicacion: punto,
        autorHash: autor,
        idArista: 'a2',
      );
      expect(tercero.publicado, isTrue);
    });

    test('un reporte igual en el mismo tramo se ofrece confirmar', () async {
      final repo = InMemoryReportsRepository(reloj: () => t0);
      await repo.publicar(tipo: TipoReporte.cierre, ubicacion: punto, autorHash: autor, idArista: 'a1');
      final repetido = await repo.publicar(
        tipo: TipoReporte.cierre,
        ubicacion: punto,
        autorHash: ana,
        idArista: 'a1',
      );
      expect(repetido.resultado, ResultadoPublicacion.duplicado);
      expect(repetido.duplicado, isNotNull);
      expect(repo.vigentes(), hasLength(1));
    });

    test('el reporte de una fila se ancla a su lugar (idLugar) y sobrevive a toMap/fromMap', () async {
      final repo = InMemoryReportsRepository(reloj: () => t0);
      final r = await repo.publicar(
        tipo: TipoReporte.fila,
        ubicacion: punto,
        autorHash: autor,
        idLugar: 'cafeteria-la-central',
      );
      expect(r.reporte!.idLugar, 'cafeteria-la-central');
      final copia = ReporteComunidad.fromMap(r.reporte!.toMap());
      expect(copia.idLugar, 'cafeteria-la-central');
    });
  });

  group('Anonimato (RF-REP-07)', () {
    test('ninguna vista pública contiene el authorHash', () async {
      final repo = InMemoryReportsRepository(reloj: () => t0);
      final emisiones = <List<ReporteComunidad>>[];
      final suscripcion = repo.observar().listen(emisiones.add);

      final publicado = await repo.publicar(
        tipo: TipoReporte.cierre,
        ubicacion: punto,
        autorHash: autor,
        idArista: 'a1',
      );
      await repo.calificar(
        idReporte: publicado.reporte!.id,
        votanteHash: ana,
        voto: VotoReporte.sigueAhi,
      );
      await Future<void>.delayed(Duration.zero);
      await suscripcion.cancel();

      final vistas = <ReporteComunidad>[
        publicado.reporte!,
        ...repo.vigentes(),
        for (final lista in emisiones) ...lista,
      ];
      expect(vistas, isNotEmpty);
      for (final v in vistas) {
        expect(v.authorHash, isNull);
        expect(v.toString(), isNot(contains(autor)));
        expect(v.toMap().values.whereType<String>(), isNot(contains(autor)));
        expect(v.toMap().keys, isNot(contains('authorHash')));
        expect(v.toMap().keys, isNot(contains('uid')));
      }
    });

    test('el hash viene de calcularAuthorHash y solo existe en la vista de autoría', () {
      final r = nuevo();
      expect(r.authorHash, autor);
      expect(r.toMapAutoria(), <String, Object?>{'idReporte': 'r1', 'authorHash': autor});
      expect(r.sinAutor().toMapAutoria(), isNull);
      expect(r.toMap().toString(), isNot(contains(autor)));
    });
  });

  group('Auth Guard (función pura)', () {
    test('solo la cuenta institucional verificada puede escribir', () {
      for (final accion in AccionProtegida.values) {
        expect(evaluarAccion(AuthState.institucionalVerificado, accion), ResultadoGuard.permitido);
      }
    });

    test('visitante, sin sesión y bloqueado reciben el modal de cuenta (S10)', () {
      for (final estado in <AuthState>[AuthState.visitante, AuthState.sinSesion, AuthState.bloqueado]) {
        for (final accion in AccionProtegida.values) {
          expect(evaluarAccion(estado, accion), ResultadoGuard.requiereCuenta, reason: '$estado $accion');
        }
      }
    });

    test('la cuenta sin verificar recibe el modal de verificación (S07)', () {
      for (final accion in AccionProtegida.values) {
        expect(
          evaluarAccion(AuthState.institucionalNoVerificado, accion),
          ResultadoGuard.requiereVerificacion,
        );
      }
    });

    test('se evalúa desde el UsuarioPerfil', () {
      expect(
        evaluarAccionDePerfil(UsuarioPerfil.invitado(), AccionProtegida.crearReporte),
        ResultadoGuard.requiereCuenta,
      );
      expect(
        evaluarAccionDePerfil(
          UsuarioPerfil.institucional(
            uid: 'u1',
            correoInstitucional: 'a@javeriana.edu.co',
            rol: RolUsuario.estudiante,
            emailVerified: true,
          ),
          AccionProtegida.crearReporte,
        ),
        ResultadoGuard.permitido,
      );
    });
  });
}
