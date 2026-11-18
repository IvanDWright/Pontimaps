import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:pontimaps_app/data/admin_repository.dart';
import 'package:pontimaps_app/data/official_alerts_repository.dart';
import 'package:pontimaps_app/data/reports_repository.dart';
import 'package:pontimaps_app/domain/services/moderation_service.dart';
import 'package:pontimaps_app/models/reporte_comunidad.dart';

/// `uid` de la cuenta que está operando, o `null` si no hay sesión.
typedef UidActual = String? Function();

int? _ms(Object? valor) {
  if (valor is Timestamp) return valor.millisecondsSinceEpoch;
  if (valor is int) return valor;
  return null;
}

/// Reconstruye un reporte público desde su documento de `reports/{id}`. Un
/// documento dañado se descarta (devuelve `null`): los datos vienen de la red.
/// El documento público **no** trae autor (ni `uid` ni `authorHash`).
ReporteComunidad? reporteDeDocumento(String id, Map<String, dynamic>? datos) {
  if (datos == null) return null;
  final creadoEn = _ms(datos['creadoEn']);
  final expiraEn = _ms(datos['expiraEn']);
  if (creadoEn == null || expiraEn == null) return null;
  try {
    return ReporteComunidad.fromMap(<String, Object?>{
      ...datos,
      'id': id,
      'creadoEn': creadoEn,
      'expiraEn': expiraEn,
    });
  } on FormatException {
    return null;
  }
}

/// Reportes colaborativos en tiempo real sobre Cloud Firestore (plan Spark, sin
/// Cloud Functions).
///
/// * `reports/{id}` es **público** y no contiene autor. El `authorHash` (SHA-256
///   del `uid`) va aparte, en `reportAuthors/{id}`, que solo leen el
///   administrador y el propio autor.
/// * Cada voto es `reports/{id}/votes/{authorHashVotante}`: el id impide un
///   segundo voto de la misma cuenta. Se escribe en el mismo *batch* que el
///   contador, y las reglas lo validan.
/// * El **cliente** filtra por `expiraEn` y por votos negativos; el TTL de
///   Firestore solo recoge los documentos vencidos.
/// * La propagación a los demás clientes depende del *listener*
///   (`snapshots()`); el objetivo es `< 30 s`.
class FirestoreReportsRepository implements ReportsRepository {
  FirestoreReportsRepository({
    required FirebaseFirestore firestore,
    required this.uidActual,
    Reloj? reloj,
  })  : _db = firestore,
        _reloj = reloj ?? DateTime.now {
    _suscripcion = _db.collection('reports').snapshots().listen(
      (instantanea) {
        _cache
          ..clear()
          ..addEntries(<MapEntry<String, ReporteComunidad>>[
            for (final doc in instantanea.docs)
              if (reporteDeDocumento(doc.id, doc.data()) case final ReporteComunidad r) MapEntry(r.id, r),
          ]);
        _notificar();
      },
      // Sin red o sin permiso: se conserva lo último que se vio.
      onError: (Object _) {},
    );
  }

  final FirebaseFirestore _db;

  /// `uid` de la cuenta que opera (solo para la escritura; nunca sale en una vista).
  final UidActual uidActual;
  final Reloj _reloj;
  final Map<String, ReporteComunidad> _cache = <String, ReporteComunidad>{};
  final StreamController<List<ReporteComunidad>> _cambios =
      StreamController<List<ReporteComunidad>>.broadcast();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _suscripcion;

  /// Margen tras el vencimiento para que el TTL borre `reportAuthors`.
  static const Duration _margenBorrado = Duration(hours: 24);

  List<ReporteComunidad> _publicos() {
    final ahora = _reloj();
    return List<ReporteComunidad>.unmodifiable(<ReporteComunidad>[
      for (final r in _cache.values)
        if (r.estaVigente(ahora)) r.sinAutor(),
    ]);
  }

  void _notificar() {
    if (!_cambios.isClosed) _cambios.add(_publicos());
  }

  @override
  List<ReporteComunidad> vigentes() => _publicos();

  @override
  Stream<List<ReporteComunidad>> observar() async* {
    yield _publicos();
    yield* _cambios.stream;
  }

  @override
  void refrescar() => _notificar();

  @override
  Future<ResultadoPublicar> publicar({
    required TipoReporte tipo,
    required LatLng ubicacion,
    required String autorHash,
    String? idArista,
    String? idLugar,
  }) async {
    final uid = uidActual();
    if (uid == null) throw StateError('Publicar un reporte exige una sesión verificada');
    final ahora = _reloj().toUtc();

    final usuario = _db.collection('users').doc(uid);
    final ultimo = _ms((await usuario.get()).data()?['ultimoReporteEn']);
    if (!ModerationService.puedePublicar(
      ultimoReporteEn: ultimo == null ? null : DateTime.fromMillisecondsSinceEpoch(ultimo, isUtc: true),
      ahora: ahora,
    )) {
      return const ResultadoPublicar(ResultadoPublicacion.demasiadoPronto);
    }
    final duplicado = ModerationService.buscarDuplicado(
      existentes: _cache.values,
      tipo: tipo,
      idArista: idArista,
      idLugar: idLugar,
      ahora: ahora,
    );
    if (duplicado != null) {
      return ResultadoPublicar(ResultadoPublicacion.duplicado, duplicado: duplicado.sinAutor());
    }

    final ref = _db.collection('reports').doc();
    final reporte = ReporteComunidad.nuevo(
      id: ref.id,
      tipo: tipo,
      ubicacion: ubicacion,
      ahora: ahora,
      authorHash: autorHash,
      idAristaAfectada: idArista,
      idLugar: idLugar,
    );
    final lote = _db.batch()
      ..set(ref, <String, Object?>{
        'tipo': tipo.name,
        'idAristaAfectada': idArista,
        'idLugar': ?idLugar,
        'lat': ubicacion.latitude,
        'lng': ubicacion.longitude,
        'creadoEn': Timestamp.fromDate(reporte.creadoEn),
        'expiraEn': Timestamp.fromDate(reporte.expiraEn),
        'confirmaciones': 0,
        'reportesNegativos': 0,
      })
      ..set(_db.collection('reportAuthors').doc(ref.id), <String, Object?>{
        'authorHash': autorHash,
        'borrarEn': Timestamp.fromDate(reporte.expiraEn.add(_margenBorrado)),
      })
      ..update(usuario, <String, Object?>{'ultimoReporteEn': Timestamp.fromDate(ahora)});
    await lote.commit();

    _cache[reporte.id] = reporte.sinAutor();
    _notificar();
    return ResultadoPublicar(ResultadoPublicacion.publicado, reporte: reporte.sinAutor());
  }

  @override
  Future<ResultadoVoto> calificar({
    required String idReporte,
    required String votanteHash,
    required VotoReporte voto,
  }) async {
    final ahora = _reloj().toUtc();
    final actual = _cache[idReporte];
    if (actual == null || !actual.estaVigente(ahora)) return ResultadoVoto.noVigente;

    // El autor no vota el suyo: `reportAuthors` solo lo lee el propio autor (y el
    // administrador); para los demás la lectura se niega y no hay nada que comparar.
    final referenciaAutor = _db.collection('reportAuthors').doc(idReporte);
    try {
      final autoria = await referenciaAutor.get();
      if (autoria.exists && autoria.data()?['authorHash'] == votanteHash) {
        return ResultadoVoto.esAutor;
      }
    } on FirebaseException {
      // Permiso denegado: no es el autor.
    }

    final referenciaVoto = _db.collection('reports').doc(idReporte).collection('votes').doc(votanteHash);
    try {
      if ((await referenciaVoto.get()).exists) return ResultadoVoto.yaVoto;
    } on FirebaseException {
      // Sin lectura del voto propio: las reglas rechazarán un segundo voto igualmente.
    }

    final calificacion = ModerationService.calificar(
      reporte: actual,
      votanteHash: votanteHash,
      voto: voto,
      votantesPrevios: const <String>{},
      ahora: ahora,
    );
    if (!calificacion.registro) return calificacion.resultado;

    final referenciaReporte = _db.collection('reports').doc(idReporte);
    final lote = _db.batch()
      ..set(referenciaVoto, <String, Object?>{
        'valor': voto == VotoReporte.sigueAhi ? 1 : -1,
        'en': Timestamp.fromDate(ahora),
      })
      ..update(referenciaReporte, <String, Object?>{
        if (voto == VotoReporte.sigueAhi) ...<String, Object?>{
          'confirmaciones': FieldValue.increment(1),
          'expiraEn': Timestamp.fromDate(calificacion.reporte.expiraEn),
        } else
          'reportesNegativos': FieldValue.increment(1),
      });
    try {
      await lote.commit();
    } on FirebaseException catch (e) {
      // Con el voto ya hecho (id = authorHash) o sin permiso, las reglas lo niegan.
      if (e.code == 'permission-denied') return ResultadoVoto.yaVoto;
      rethrow;
    }

    _cache[idReporte] = calificacion.reporte;
    _notificar();
    return ResultadoVoto.registrado;
  }

  Future<void> cerrar() async {
    await _suscripcion?.cancel();
    await _cambios.close();
  }
}

/// Alertas oficiales sobre Firestore (`officialAlerts/{id}`): lectura pública,
/// escritura solo de administradores (lo exigen las reglas).
class FirestoreOfficialAlertsRepository implements OfficialAlertsRepository {
  FirestoreOfficialAlertsRepository({required FirebaseFirestore firestore, Reloj? reloj})
      : _db = firestore,
        _reloj = reloj ?? DateTime.now {
    _suscripcion = _db.collection('officialAlerts').snapshots().listen(
      (instantanea) {
        _cache
          ..clear()
          ..addEntries(<MapEntry<String, AlertaOficial>>[
            for (final doc in instantanea.docs)
              if (_deDocumento(doc.id, doc.data()) case final AlertaOficial a) MapEntry(a.id, a),
          ]);
        _notificar();
      },
      onError: (Object _) {},
    );
  }

  final FirebaseFirestore _db;
  final Reloj _reloj;
  final Map<String, AlertaOficial> _cache = <String, AlertaOficial>{};
  final StreamController<List<AlertaOficial>> _cambios =
      StreamController<List<AlertaOficial>>.broadcast();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _suscripcion;

  static AlertaOficial? _deDocumento(String id, Map<String, dynamic> datos) {
    final desde = _ms(datos['desde']);
    final hasta = datos['hasta'] == null ? null : _ms(datos['hasta']);
    if (desde == null) return null;
    return AlertaOficial.deMapa(id, <String, Object?>{...datos, 'desde': desde, 'hasta': hasta});
  }

  @override
  List<AlertaOficial> vigentes() {
    final ahora = _reloj();
    return List<AlertaOficial>.unmodifiable(<AlertaOficial>[
      for (final a in _cache.values)
        if (a.estaVigente(ahora)) a,
    ]);
  }

  void _notificar() {
    if (!_cambios.isClosed) _cambios.add(vigentes());
  }

  @override
  Stream<List<AlertaOficial>> observar() async* {
    yield vigentes();
    yield* _cambios.stream;
  }

  @override
  Future<AlertaOficial> publicar({
    required String mensaje,
    required LatLng ubicacion,
    DateTime? hasta,
  }) async {
    final texto = mensaje.trim();
    if (texto.isEmpty || texto.length > AlertaOficial.maxLongitudMensaje) {
      throw ArgumentError.value(mensaje, 'mensaje', 'Entre 1 y 140 caracteres');
    }
    final ahora = _reloj().toUtc();
    final ref = _db.collection('officialAlerts').doc();
    await ref.set(<String, Object?>{
      'tipo': 'oficial',
      'mensaje': texto,
      'lat': ubicacion.latitude,
      'lng': ubicacion.longitude,
      'desde': Timestamp.fromDate(ahora),
      if (hasta != null) 'hasta': Timestamp.fromDate(hasta.toUtc()),
    });
    final alerta = AlertaOficial(id: ref.id, mensaje: texto, ubicacion: ubicacion, desde: ahora, hasta: hasta);
    _cache[alerta.id] = alerta;
    _notificar();
    return alerta;
  }

  @override
  Future<void> cerrar(String id) async {
    await _db.collection('officialAlerts').doc(id).delete();
    if (_cache.remove(id) != null) _notificar();
  }

  Future<void> cerrarFlujo() async {
    await _suscripcion?.cancel();
    await _cambios.close();
  }
}

/// Moderación del administrador sobre Firestore, sin Cloud Functions: cada acción
/// es un *batch* del cliente del administrador que **validan las reglas**
/// (`rol == 'admin'`); la comprobación local solo evita llamadas inútiles.
///
/// "Bloquear autor": lee `reportAuthors/{id}.authorHash`, busca en `users` la
/// cuenta con ese hash y le pone `estado = 'bloqueado'`. Esa persona queda como
/// Visitante (solo lectura) en cuanto su app recibe el cambio.
class FirestoreAdminRepository implements AdminRepository {
  FirestoreAdminRepository({
    required FirebaseFirestore firestore,
    required this.uidActual,
    required this.esAdmin,
    Reloj? reloj,
  })  : _db = firestore,
        _reloj = reloj ?? DateTime.now;

  final FirebaseFirestore _db;
  final UidActual uidActual;
  final bool Function() esAdmin;
  final Reloj _reloj;

  @override
  Stream<List<ReporteComunidad>> reportesActivos() {
    return _db.collection('reports').snapshots().map((instantanea) {
      final ahora = _reloj();
      return <ReporteComunidad>[
        for (final doc in instantanea.docs)
          if (reporteDeDocumento(doc.id, doc.data()) case final ReporteComunidad r)
            if (r.estaVigente(ahora)) r,
      ];
    });
  }

  Map<String, Object?> _accion(String que, String? aQuien) => <String, Object?>{
        'quien': uidActual(),
        'aQuien': aQuien,
        'que': que,
        'cuando': Timestamp.fromDate(_reloj().toUtc()),
      };

  @override
  Future<ResultadoModeracion> eliminarReporte(String idReporte) async {
    if (!esAdmin()) return ResultadoModeracion.sinPermiso;
    final referencia = _db.collection('reports').doc(idReporte);
    if (!(await referencia.get()).exists) return ResultadoModeracion.noEncontrado;
    final lote = _db.batch()
      ..delete(referencia)
      ..delete(_db.collection('reportAuthors').doc(idReporte))
      ..set(_db.collection('adminActions').doc(), _accion('eliminarReporte', idReporte));
    await lote.commit();
    return ResultadoModeracion.hecho;
  }

  @override
  Future<ResultadoModeracion> bloquearAutor(String idReporte) async {
    if (!esAdmin()) return ResultadoModeracion.sinPermiso;
    final autoria = await _db.collection('reportAuthors').doc(idReporte).get();
    final hash = autoria.data()?['authorHash'];
    if (hash is! String) return ResultadoModeracion.autorNoEncontrado;

    final cuentas = await _db.collection('users').where('authorHash', isEqualTo: hash).limit(1).get();
    if (cuentas.docs.isEmpty) return ResultadoModeracion.autorNoEncontrado;
    final cuenta = cuentas.docs.first;
    final lote = _db.batch()
      ..update(cuenta.reference, <String, Object?>{'estado': 'bloqueado'})
      ..set(_db.collection('adminActions').doc(), _accion('bloquearAutor', cuenta.id));
    await lote.commit();
    return ResultadoModeracion.hecho;
  }
}
