import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Posición del usuario en un instante. Vive solo en memoria volátil: nunca se
/// guarda ni se envía (Ley 1581).
class PosicionUsuario {
  const PosicionUsuario(this.punto, {this.precisionMetros});

  final LatLng punto;

  /// Precisión horizontal estimada en metros (`null` si no se conoce).
  final double? precisionMetros;

  /// `true` si la precisión es peor que el objetivo de 5 m (señal débil).
  bool get senalDebil => precisionMetros != null && precisionMetros! > 5;
}

/// Estado del permiso de ubicación del sistema operativo.
enum EstadoPermisoUbicacion {
  /// Aún no se ha pedido (o no se puede saber sin pedirlo).
  noSolicitado,
  concedido,
  denegado,
  denegadoPermanente,
  /// El GPS del dispositivo está apagado.
  servicioApagado,
}

/// Fuente de posiciones. La UI depende de esta interfaz, nunca de `geolocator`
/// (RF-NAV-08).
abstract class LocationProvider {
  /// Consulta el permiso **sin** mostrar el diálogo del sistema.
  Future<EstadoPermisoUbicacion> estadoPermiso();

  /// Pide el permiso al sistema. Solo `PermissionScreen` puede llamarlo, y solo
  /// después de que el usuario aceptó el consentimiento (Regla 4).
  Future<EstadoPermisoUbicacion> solicitarPermiso();

  /// Flujo de posiciones (objetivo: cada 1 s con precisión ≤ 5 m). Quien lo
  /// escucha lo cancela para pausar o revocar: la lectura se detiene al cancelar
  /// la suscripción, en menos de 1 s.
  Stream<PosicionUsuario> posiciones();
}

/// Envoltorio fino de los métodos estáticos de `geolocator`, para poder
/// sustituirlos en pruebas sin tocar la plataforma.
class GeolocatorGateway {
  const GeolocatorGateway();

  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();
  Future<LocationPermission> requestPermission() => Geolocator.requestPermission();
  Future<bool> isLocationServiceEnabled() => Geolocator.isLocationServiceEnabled();
  Stream<Position> getPositionStream(LocationSettings settings) =>
      Geolocator.getPositionStream(locationSettings: settings);
}

/// GPS real con `geolocator`: actualización cada 1 s y precisión objetivo ≤ 5 m.
class GpsLocationProvider implements LocationProvider {
  GpsLocationProvider([this._gateway = const GeolocatorGateway()]);

  final GeolocatorGateway _gateway;

  /// Intervalo de refresco objetivo (RF-NAV-05).
  static const Duration intervalo = Duration(seconds: 1);

  static EstadoPermisoUbicacion _traducir(LocationPermission permiso) {
    switch (permiso) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return EstadoPermisoUbicacion.concedido;
      case LocationPermission.denied:
        return EstadoPermisoUbicacion.denegado;
      case LocationPermission.deniedForever:
        return EstadoPermisoUbicacion.denegadoPermanente;
      case LocationPermission.unableToDetermine:
        return EstadoPermisoUbicacion.noSolicitado;
    }
  }

  @override
  Future<EstadoPermisoUbicacion> estadoPermiso() async {
    final permiso = _traducir(await _gateway.checkPermission());
    if (permiso == EstadoPermisoUbicacion.concedido &&
        !await _gateway.isLocationServiceEnabled()) {
      return EstadoPermisoUbicacion.servicioApagado;
    }
    return permiso;
  }

  @override
  Future<EstadoPermisoUbicacion> solicitarPermiso() async {
    var permiso = await _gateway.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await _gateway.requestPermission();
    }
    final estado = _traducir(permiso);
    if (estado == EstadoPermisoUbicacion.concedido &&
        !await _gateway.isLocationServiceEnabled()) {
      return EstadoPermisoUbicacion.servicioApagado;
    }
    return estado;
  }

  @override
  Stream<PosicionUsuario> posiciones() {
    final ajustes = AndroidSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
      intervalDuration: intervalo,
    );
    return _gateway.getPositionStream(ajustes).map(
          (p) => PosicionUsuario(
            LatLng(p.latitude, p.longitude),
            precisionMetros: p.accuracy,
          ),
        );
  }
}

/// Ubicación simulada (demos sin red, emuladores y pruebas): un punto fijo del
/// campus que se puede mover a mano con [moverA]. No usa el GPS ni pide permisos.
class SimulatedLocationProvider implements LocationProvider {
  SimulatedLocationProvider({LatLng? inicio}) : _actual = inicio ?? plazoletaCentral;

  /// Plazoleta Central de la Pontificia Universidad Javeriana (Bogotá).
  static const LatLng plazoletaCentral = LatLng(4.6285, -74.0645);

  LatLng _actual;
  final StreamController<PosicionUsuario> _cambios =
      StreamController<PosicionUsuario>.broadcast();

  /// Posición simulada actual.
  LatLng get actual => _actual;

  /// Cambia la posición simulada y avisa a quienes escuchan (caminar en una demo).
  void moverA(LatLng punto) {
    _actual = punto;
    _cambios.add(PosicionUsuario(punto, precisionMetros: 3));
  }

  @override
  Future<EstadoPermisoUbicacion> estadoPermiso() async => EstadoPermisoUbicacion.concedido;

  @override
  Future<EstadoPermisoUbicacion> solicitarPermiso() async => EstadoPermisoUbicacion.concedido;

  @override
  Stream<PosicionUsuario> posiciones() async* {
    yield PosicionUsuario(_actual, precisionMetros: 3);
    yield* _cambios.stream;
  }
}

/// *Stub* de lectura de balizas Bluetooth Low Energy para interiores
/// (RF-NAV-08). Aún no hay balizas instaladas: no entrega posiciones y la
/// interfaz queda lista para conectarlas sin tocar la UI.
class BleIndoorProvider implements LocationProvider {
  const BleIndoorProvider();

  /// `false` hasta que existan balizas y una implementación real.
  bool get disponible => false;

  @override
  Future<EstadoPermisoUbicacion> estadoPermiso() async => EstadoPermisoUbicacion.noSolicitado;

  @override
  Future<EstadoPermisoUbicacion> solicitarPermiso() async => EstadoPermisoUbicacion.noSolicitado;

  @override
  Stream<PosicionUsuario> posiciones() => const Stream<PosicionUsuario>.empty();
}
