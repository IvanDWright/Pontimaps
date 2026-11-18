import 'package:latlong2/latlong.dart';
import 'package:pontimaps_app/data/campus_cartography.dart';
import 'package:pontimaps_app/domain/routing/grafo_campus.dart';
import 'package:pontimaps_app/domain/services/next_class.dart';
import 'package:pontimaps_app/models/horario_usuario.dart';
import 'package:pontimaps_app/models/salon.dart';

/// Cuándo debe salir el estudiante hacia su próxima clase (RF-HOR-05).
class AlertaSalida {
  const AlertaSalida({
    required this.id,
    required this.proxima,
    required this.salon,
    required this.horaSalida,
    required this.duracionRuta,
    required this.margen,
  });

  /// Identifica la alerta (clase y día) para no repetirla ni volver a mostrarla.
  final String id;
  final ProximaClase proxima;
  final Salon salon;

  /// Momento de salida, en hora de Bogotá (campos de pared, en UTC).
  final DateTime horaSalida;

  /// Duración estimada de la ruta A\* hasta el edificio de la clase.
  final Duration duracionRuta;
  final Duration margen;

  /// Minutos que faltan para salir en [ahora] (hora de Bogotá); `<= 0` es «sal ya».
  int minutosParaSalir(DateTime ahora) => horaSalida.difference(ahora).inMinutes;

  /// «Sal en 4 min hacia Edificio 67 · Piso 2» o «Sal ya hacia …».
  String texto(DateTime ahora) {
    final faltan = minutosParaSalir(ahora);
    final destino = salon.etiquetaUbicacion();
    return faltan <= 0 ? 'Sal ya hacia $destino' : 'Sal en $faltan min hacia $destino';
  }
}

/// Calcula la hora de salida hacia la próxima clase.
abstract final class DeparturePlanner {
  /// Margen de seguridad por defecto.
  static const Duration margenPorDefecto = Duration(minutes: 5);

  /// `horaSalida = inicioClase − duracionRuta − margen`.
  static DateTime calcularHoraSalida({
    required DateTime inicioClase,
    required Duration duracionRuta,
    Duration margen = margenPorDefecto,
  }) =>
      inicioClase.subtract(duracionRuta).subtract(margen);

  /// Desde dónde se camina hasta la clase: la posición actual si se conoce; si no,
  /// el edificio de la clase anterior del mismo día que termina antes de que
  /// empiece la próxima. `null` si no hay ninguno de los dos.
  static LatLng? origenParaClase({
    LatLng? posicion,
    required ProximaClase proxima,
    required List<BloqueHorario> horario,
    required CampusCartography cartografia,
  }) {
    if (posicion != null) return posicion;
    BloqueHorario? anterior;
    for (final b in horario) {
      if (b.id == proxima.bloque.id || b.diaSemana != proxima.bloque.diaSemana) continue;
      if (b.horaFin > proxima.bloque.horaInicio) continue;
      if (anterior == null || b.horaFin > anterior.horaFin) anterior = b;
    }
    return anterior == null ? null : cartografia.edificioPorId(anterior.idEdificio)?.ubicacion;
  }

  /// Planifica la alerta de salida de la próxima clase, o `null` si no hay clase,
  /// no se conoce el origen, el salón no existe o no hay ruta.
  static AlertaSalida? planificar({
    required UsuarioPerfil perfil,
    required List<BloqueHorario> horario,
    required DateTime ahora,
    required CampusCartography cartografia,
    LatLng? posicion,
    double velocidadMetrosPorSegundo = GrafoCampus.velocidadPeatonalPorDefecto,
    Duration margen = margenPorDefecto,
  }) {
    final proxima = calcularProximaClase(perfil, horario, ahora);
    if (proxima == null) return null;
    final edificio = cartografia.edificioPorId(proxima.bloque.idEdificio);
    final salon = edificio?.buscarSalon(proxima.bloque.codigoSalon);
    if (salon == null) return null;
    final origen = origenParaClase(
      posicion: posicion,
      proxima: proxima,
      horario: horario,
      cartografia: cartografia,
    );
    if (origen == null) return null;

    final Duration duracion;
    try {
      final ruta = cartografia.calcularRutaHaciaSalon(
        origen,
        salon,
        velocidadMetrosPorSegundo: velocidadMetrosPorSegundo,
      );
      duracion = Duration(minutes: ruta.tiempoEstimadoMinutos);
    } on RutaNoEncontradaException {
      return null;
    }
    return AlertaSalida(
      id: '${proxima.bloque.id}@${proxima.inicio.toIso8601String()}',
      proxima: proxima,
      salon: salon,
      horaSalida: calcularHoraSalida(
        inicioClase: proxima.inicio,
        duracionRuta: duracion,
        margen: margen,
      ),
      duracionRuta: duracion,
      margen: margen,
    );
  }
}
