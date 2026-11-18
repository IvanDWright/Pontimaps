import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:pontimaps_app/core/utils/geo_utils.dart';
import 'package:pontimaps_app/data/campus_cartography.dart';
import 'package:pontimaps_app/data/location_service.dart';

import '../helpers/test_doubles.dart';

class _GatewayConAjustes extends GeolocatorFalso {
  LocationSettings? ultimosAjustes;

  @override
  Stream<Position> getPositionStream(LocationSettings settings) {
    ultimosAjustes = settings;
    return Stream<Position>.value(
      Position(
        latitude: 4.6285,
        longitude: -74.0645,
        timestamp: DateTime(2026, 11, 18),
        accuracy: 4,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ),
    );
  }
}

class _GatewayServicioApagado extends GeolocatorFalso {
  _GatewayServicioApagado() : super(permisoInicial: LocationPermission.whileInUse);

  @override
  Future<bool> isLocationServiceEnabled() async => false;
}

void main() {
  group('GpsLocationProvider', () {
    test('estadoPermiso consulta sin mostrar el diálogo del sistema', () async {
      final gateway = GeolocatorFalso();
      final gps = GpsLocationProvider(gateway);

      expect(await gps.estadoPermiso(), EstadoPermisoUbicacion.denegado);
      expect(gateway.llamadasRequestPermission, 0);
    });

    test('solicitarPermiso pide al sistema solo si estaba denegado', () async {
      final gateway = GeolocatorFalso();
      expect(
        await GpsLocationProvider(gateway).solicitarPermiso(),
        EstadoPermisoUbicacion.concedido,
      );
      expect(gateway.llamadasRequestPermission, 1);

      final yaConcedido = GeolocatorFalso(permisoInicial: LocationPermission.whileInUse);
      await GpsLocationProvider(yaConcedido).solicitarPermiso();
      expect(yaConcedido.llamadasRequestPermission, 0);

      final permanente = GeolocatorFalso(permisoInicial: LocationPermission.deniedForever);
      expect(
        await GpsLocationProvider(permanente).solicitarPermiso(),
        EstadoPermisoUbicacion.denegadoPermanente,
      );
      expect(permanente.llamadasRequestPermission, 0);
    });

    test('con el GPS del dispositivo apagado informa servicioApagado', () async {
      final gps = GpsLocationProvider(_GatewayServicioApagado());
      expect(await gps.estadoPermiso(), EstadoPermisoUbicacion.servicioApagado);
    });

    test('el flujo pide una lectura por segundo con la mejor precisión', () async {
      final gateway = _GatewayConAjustes();
      final posiciones = await GpsLocationProvider(gateway).posiciones().toList();

      expect(GpsLocationProvider.intervalo, const Duration(seconds: 1));
      final ajustes = gateway.ultimosAjustes! as AndroidSettings;
      expect(ajustes.intervalDuration, const Duration(seconds: 1));
      expect(ajustes.accuracy, LocationAccuracy.best);
      expect(posiciones.single.punto, const LatLng(4.6285, -74.0645));
      expect(posiciones.single.precisionMetros, 4);
      expect(posiciones.single.senalDebil, isFalse);
    });

    test('una precisión peor que 5 m se marca como señal débil', () {
      expect(const PosicionUsuario(LatLng(0, 0), precisionMetros: 8).senalDebil, isTrue);
      expect(const PosicionUsuario(LatLng(0, 0), precisionMetros: 5).senalDebil, isFalse);
      expect(const PosicionUsuario(LatLng(0, 0)).senalDebil, isFalse);
    });
  });

  group('SimulatedLocationProvider', () {
    test('arranca en la Plazoleta Central, dentro del campus', () async {
      final simulada = SimulatedLocationProvider();
      final primera = await simulada.posiciones().first;

      expect(primera.punto, const LatLng(4.6285, -74.0645));
      final nodos = CampusCartography.seed().grafo.nodos;
      final cercano = nodos
          .map((n) => distanciaHaversine(primera.punto, n.ubicacion))
          .reduce((a, b) => a < b ? a : b);
      expect(cercano, lessThan(400));
    });

    test('no pide permisos y emite al moverla', () async {
      final simulada = SimulatedLocationProvider();
      expect(await simulada.solicitarPermiso(), EstadoPermisoUbicacion.concedido);

      final recibidas = <LatLng>[];
      final suscripcion = simulada.posiciones().listen((p) => recibidas.add(p.punto));
      await Future<void>.delayed(Duration.zero);
      simulada.moverA(const LatLng(4.63, -74.065));
      await Future<void>.delayed(Duration.zero);
      await suscripcion.cancel();

      expect(recibidas, <LatLng>[const LatLng(4.6285, -74.0645), const LatLng(4.63, -74.065)]);
      expect(simulada.actual, const LatLng(4.63, -74.065));
    });
  });

  test('BleIndoorProvider es un stub sin posiciones (RF-NAV-08)', () async {
    const ble = BleIndoorProvider();
    expect(ble.disponible, isFalse);
    expect(await ble.posiciones().isEmpty, isTrue);
  });
}
