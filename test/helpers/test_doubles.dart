import 'dart:async';
import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pontimaps_app/data/location_service.dart';

/// Teselas sin red: un píxel transparente. Así las pruebas de widget no abren
/// conexiones a OpenStreetMap.
class SinRedTileProvider extends TileProvider {
  SinRedTileProvider() : super();

  static final MemoryImage _pixel = MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
    ),
  );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) => _pixel;
}

/// Pasarela de `geolocator` falsa que cuenta las llamadas al permiso.
class GeolocatorFalso extends GeolocatorGateway {
  GeolocatorFalso({this.permisoInicial = LocationPermission.denied});

  final LocationPermission permisoInicial;
  int llamadasRequestPermission = 0;
  int llamadasStream = 0;

  @override
  Future<LocationPermission> checkPermission() async => permisoInicial;

  @override
  Future<LocationPermission> requestPermission() async {
    llamadasRequestPermission++;
    return LocationPermission.whileInUse;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Stream<Position> getPositionStream(LocationSettings settings) {
    llamadasStream++;
    return const Stream<Position>.empty();
  }
}

/// Proveedor de ubicación que registra si su flujo fue cancelado.
class UbicacionEspia implements LocationProvider {
  UbicacionEspia(this.inicio);

  final PosicionUsuario inicio;
  int suscripciones = 0;
  int cancelaciones = 0;
  int solicitudesPermiso = 0;

  @override
  Future<EstadoPermisoUbicacion> estadoPermiso() async => EstadoPermisoUbicacion.concedido;

  @override
  Future<EstadoPermisoUbicacion> solicitarPermiso() async {
    solicitudesPermiso++;
    return EstadoPermisoUbicacion.concedido;
  }

  @override
  Stream<PosicionUsuario> posiciones() {
    late final StreamController<PosicionUsuario> controlador;
    controlador = StreamController<PosicionUsuario>(
      onListen: () {
        suscripciones++;
        controlador.add(inicio);
      },
      onCancel: () => cancelaciones++,
    );
    return controlador.stream;
  }
}
