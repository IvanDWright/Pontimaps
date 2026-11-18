import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:pontimaps_app/data/reports_repository.dart';

/// Alerta oficial publicada por un administrador: fija en el mapa, **sin
/// expiración automática** hasta que el administrador la cierra (o llega su
/// `hasta`, si lo tiene).
class AlertaOficial {
  const AlertaOficial({
    required this.id,
    required this.mensaje,
    required this.ubicacion,
    required this.desde,
    this.hasta,
  })  : assert(id != ''),
        assert(mensaje != '');

  static const int maxLongitudMensaje = 140;

  final String id;
  final String mensaje;
  final LatLng ubicacion;
  final DateTime desde;

  /// Fin opcional; `null` = fija hasta que se cierre.
  final DateTime? hasta;

  bool estaVigente(DateTime ahora) =>
      !ahora.isBefore(desde) && (hasta == null || ahora.isBefore(hasta!));

  Map<String, Object?> toMap() => <String, Object?>{
        'tipo': 'oficial',
        'mensaje': mensaje,
        'lat': ubicacion.latitude,
        'lng': ubicacion.longitude,
        'desde': desde.toUtc().millisecondsSinceEpoch,
        if (hasta != null) 'hasta': hasta!.toUtc().millisecondsSinceEpoch,
      };

  /// Reconstruye una alerta; `null` si faltan campos o son inválidos.
  static AlertaOficial? deMapa(String id, Map<String, Object?> mapa) {
    final mensaje = mapa['mensaje'];
    final lat = mapa['lat'];
    final lng = mapa['lng'];
    final desde = mapa['desde'];
    final hasta = mapa['hasta'];
    if (id.isEmpty ||
        mensaje is! String ||
        mensaje.isEmpty ||
        lat is! num ||
        lng is! num ||
        desde is! int ||
        (hasta != null && hasta is! int)) {
      return null;
    }
    return AlertaOficial(
      id: id,
      mensaje: mensaje,
      ubicacion: LatLng(lat.toDouble(), lng.toDouble()),
      desde: DateTime.fromMillisecondsSinceEpoch(desde, isUtc: true),
      hasta: hasta == null ? null : DateTime.fromMillisecondsSinceEpoch(hasta as int, isUtc: true),
    );
  }
}

/// Alertas oficiales: **lectura pública** (visitantes incluidos) y escritura solo
/// de administradores (las reglas de Firestore son la autoridad).
abstract class OfficialAlertsRepository {
  List<AlertaOficial> vigentes();

  Stream<List<AlertaOficial>> observar();

  Future<AlertaOficial> publicar({
    required String mensaje,
    required LatLng ubicacion,
    DateTime? hasta,
  });

  Future<void> cerrar(String id);
}

/// Implementación en memoria (modo demostración sin Firebase).
class InMemoryOfficialAlertsRepository implements OfficialAlertsRepository {
  InMemoryOfficialAlertsRepository({Reloj? reloj}) : _reloj = reloj ?? DateTime.now;

  final Reloj _reloj;
  final Map<String, AlertaOficial> _alertas = <String, AlertaOficial>{};
  final StreamController<List<AlertaOficial>> _cambios =
      StreamController<List<AlertaOficial>>.broadcast();
  int _contador = 0;

  @override
  List<AlertaOficial> vigentes() {
    final ahora = _reloj();
    return List<AlertaOficial>.unmodifiable(<AlertaOficial>[
      for (final a in _alertas.values)
        if (a.estaVigente(ahora)) a,
    ]);
  }

  @override
  Stream<List<AlertaOficial>> observar() async* {
    yield vigentes();
    yield* _cambios.stream;
  }

  void _notificar() {
    if (!_cambios.isClosed) _cambios.add(vigentes());
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
    _contador++;
    final alerta = AlertaOficial(
      id: 'alerta-$_contador',
      mensaje: texto,
      ubicacion: ubicacion,
      desde: _reloj(),
      hasta: hasta,
    );
    _alertas[alerta.id] = alerta;
    _notificar();
    return alerta;
  }

  @override
  Future<void> cerrar(String id) async {
    if (_alertas.remove(id) != null) _notificar();
  }

  Future<void> cerrarFlujo() => _cambios.close();
}
