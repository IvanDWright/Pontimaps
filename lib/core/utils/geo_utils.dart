import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Radio medio de la Tierra en metros (IUGG).
const double radioTierraMetros = 6371008.8;

double _aRadianes(double grados) => grados * math.pi / 180.0;
double _aGrados(double radianes) => radianes * 180.0 / math.pi;

/// Distancia de círculo máximo (Haversine) entre [a] y [b], en metros.
///
/// Es la heurística admisible del motor de rutas A*. Complejidad O(1).
double distanciaHaversine(LatLng a, LatLng b) {
  final dLat = _aRadianes(b.latitude - a.latitude);
  final dLon = _aRadianes(b.longitude - a.longitude);
  final senLat = math.sin(dLat / 2);
  final senLon = math.sin(dLon / 2);
  final h = senLat * senLat +
      math.cos(_aRadianes(a.latitude)) *
          math.cos(_aRadianes(b.latitude)) *
          senLon *
          senLon;
  return 2 * radioTierraMetros * math.asin(math.min(1.0, math.sqrt(h)));
}

/// Rumbo inicial de [a] hacia [b] en grados `[0, 360)`; 0 = norte, 90 = este.
double rumboGrados(LatLng a, LatLng b) {
  final lat1 = _aRadianes(a.latitude);
  final lat2 = _aRadianes(b.latitude);
  final dLon = _aRadianes(b.longitude - a.longitude);
  final y = math.sin(dLon) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  return (_aGrados(math.atan2(y, x)) + 360.0) % 360.0;
}

/// Giro firmado en grados `[-180, 180)` para pasar del rumbo [desde] al
/// rumbo [hacia]. Positivo = hacia la derecha (sentido horario).
double diferenciaRumbo(double desde, double hacia) {
  return ((hacia - desde + 540.0) % 360.0) - 180.0;
}

const List<String> _puntosCardinales = <String>[
  'norte',
  'noreste',
  'este',
  'sureste',
  'sur',
  'suroeste',
  'oeste',
  'noroeste',
];

/// Nombre cardinal en español (8 puntos) para un [rumbo] en grados.
String nombreCardinal(double rumbo) {
  final indice = ((rumbo + 22.5) / 45.0).floor() % 8;
  return _puntosCardinales[indice];
}

/// Distancia en metros del punto [p] al segmento [a]-[b].
///
/// Usa una proyección plana local centrada en [a]; el error es despreciable
/// para segmentos de escala de campus (cientos de metros). O(1).
double distanciaPuntoSegmentoMetros(LatLng p, LatLng a, LatLng b) {
  final cosLatRef = math.cos(_aRadianes(a.latitude));
  double x(LatLng q) =>
      _aRadianes(q.longitude - a.longitude) * cosLatRef * radioTierraMetros;
  double y(LatLng q) =>
      _aRadianes(q.latitude - a.latitude) * radioTierraMetros;

  final px = x(p);
  final py = y(p);
  final bx = x(b);
  final by = y(b);
  final largo2 = bx * bx + by * by;
  if (largo2 == 0) {
    return math.sqrt(px * px + py * py);
  }
  final t = ((px * bx + py * by) / largo2).clamp(0.0, 1.0).toDouble();
  final dx = px - t * bx;
  final dy = py - t * by;
  return math.sqrt(dx * dx + dy * dy);
}
