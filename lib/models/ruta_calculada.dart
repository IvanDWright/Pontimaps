import 'package:latlong2/latlong.dart';
import 'package:pontimaps_app/core/utils/colecciones.dart';
import 'package:pontimaps_app/core/utils/geo_utils.dart';
import 'package:pontimaps_app/models/edificio.dart';

/// Tipo de maniobra al iniciar un tramo de la ruta.
enum TipoManiobra { inicio, recto, izquierda, derecha, escaleras, llegada }

/// Un tramo de la ruta entre dos maniobras consecutivas.
///
/// Cubre los segmentos `puntos[indicePuntoInicio] -> ... -> puntos[indicePuntoFin]`
/// de la [RutaCalculada]. La instrucción de llegada es un tramo de longitud 0
/// (`indicePuntoInicio == indicePuntoFin`, `distanciaMetros == 0`).
class InstruccionTramo {
  const InstruccionTramo({
    required this.maniobra,
    required this.texto,
    required this.distanciaMetros,
    required this.indicePuntoInicio,
    required this.indicePuntoFin,
  })  : assert(texto != ''),
        assert(distanciaMetros >= 0),
        assert(indicePuntoInicio >= 0),
        assert(indicePuntoFin >= indicePuntoInicio);

  final TipoManiobra maniobra;
  final String texto;
  final double distanciaMetros;
  final int indicePuntoInicio;
  final int indicePuntoFin;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstruccionTramo &&
          other.maniobra == maniobra &&
          other.texto == texto &&
          other.distanciaMetros == distanciaMetros &&
          other.indicePuntoInicio == indicePuntoInicio &&
          other.indicePuntoFin == indicePuntoFin;

  @override
  int get hashCode => Object.hash(
        maniobra,
        texto,
        distanciaMetros,
        indicePuntoInicio,
        indicePuntoFin,
      );

  @override
  String toString() => 'InstruccionTramo(${maniobra.name}: $texto)';
}

/// Resultado inmutable de un cálculo de ruta peatonal.
///
/// Privacidad (Ley 1581): contiene solo el trazado sobre el grafo del campus.
/// No guarda la posición del usuario ni un historial de posiciones.
///
/// Invariantes: `puntos` e `instrucciones` no vacíos; `distanciaMetros >= 0`;
/// `tiempoEstimadoMinutos >= 0`; la última instrucción es la de llegada y los
/// índices de las instrucciones caen dentro de `puntos`.
class RutaCalculada {
  RutaCalculada({
    required List<LatLng> puntos,
    required this.distanciaMetros,
    required this.tiempoEstimadoMinutos,
    required List<InstruccionTramo> instrucciones,
    this.tieneDesvioPorReporte = false,
    this.accesoVertical,
  })  : puntos = List<LatLng>.unmodifiable(puntos),
        instrucciones = List<InstruccionTramo>.unmodifiable(instrucciones),
        assert(puntos.isNotEmpty, 'La ruta necesita al menos un punto'),
        assert(instrucciones.isNotEmpty, 'La ruta necesita instrucciones'),
        assert(distanciaMetros >= 0),
        assert(tiempoEstimadoMinutos >= 0),
        assert(
          instrucciones.last.maniobra == TipoManiobra.llegada,
          'La última instrucción debe ser la llegada',
        ),
        assert(
          instrucciones.every((i) => i.indicePuntoFin < puntos.length),
          'Índice de instrucción fuera de los puntos',
        );

  final List<LatLng> puntos;
  final double distanciaMetros;
  final int tiempoEstimadoMinutos;
  final List<InstruccionTramo> instrucciones;

  /// `true` si, por reportes comunitarios vigentes, la ruta es distinta de la
  /// que se habría calculado sin ellos.
  final bool tieneDesvioPorReporte;

  /// Cómo se llega al piso pedido dentro del edificio destino (ascensor o
  /// escaleras internas). `null` si la consulta no incluyó un piso. Es solo
  /// información sobre la **entrada**: no hay enrutamiento interior.
  final AccesoVertical? accesoVertical;

  LatLng get destino => puntos.last;

  /// `true` si [posicionActual] está a [radioMetros] o menos del destino.
  bool haLlegado(LatLng posicionActual, {double radioMetros = 15}) =>
      distanciaHaversine(posicionActual, destino) <= radioMetros;

  /// Instrucción del tramo que el usuario debe recorrer ahora.
  ///
  /// Busca el segmento de la polilínea más cercano a [posicionActual] y
  /// devuelve la instrucción que lo contiene. Si ya llegó (ver [haLlegado]) o
  /// la ruta no tiene segmentos, devuelve la instrucción de llegada.
  /// No guarda estado: no se conserva la posición recibida. O(|puntos|).
  InstruccionTramo obtenerSiguienteTramo(LatLng posicionActual) {
    final llegada = instrucciones.last;
    if (puntos.length < 2 || haLlegado(posicionActual)) return llegada;

    var mejorSegmento = 0;
    var mejorDistancia = double.infinity;
    for (var i = 0; i < puntos.length - 1; i++) {
      final d = distanciaPuntoSegmentoMetros(
        posicionActual,
        puntos[i],
        puntos[i + 1],
      );
      if (d < mejorDistancia) {
        mejorDistancia = d;
        mejorSegmento = i;
      }
    }
    for (final instruccion in instrucciones) {
      if (instruccion.indicePuntoInicio <= mejorSegmento &&
          mejorSegmento < instruccion.indicePuntoFin) {
        return instruccion;
      }
    }
    return llegada;
  }

  RutaCalculada copyWith({
    List<LatLng>? puntos,
    double? distanciaMetros,
    int? tiempoEstimadoMinutos,
    List<InstruccionTramo>? instrucciones,
    bool? tieneDesvioPorReporte,
    Object? accesoVertical = sinCambio,
  }) {
    return RutaCalculada(
      puntos: puntos ?? this.puntos,
      distanciaMetros: distanciaMetros ?? this.distanciaMetros,
      tiempoEstimadoMinutos:
          tiempoEstimadoMinutos ?? this.tiempoEstimadoMinutos,
      instrucciones: instrucciones ?? this.instrucciones,
      tieneDesvioPorReporte:
          tieneDesvioPorReporte ?? this.tieneDesvioPorReporte,
      accesoVertical: identical(accesoVertical, sinCambio)
          ? this.accesoVertical
          : accesoVertical as AccesoVertical?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RutaCalculada &&
          other.distanciaMetros == distanciaMetros &&
          other.tiempoEstimadoMinutos == tiempoEstimadoMinutos &&
          other.tieneDesvioPorReporte == tieneDesvioPorReporte &&
          other.accesoVertical == accesoVertical &&
          listasIguales(other.puntos, puntos) &&
          listasIguales(other.instrucciones, instrucciones);

  @override
  int get hashCode => Object.hash(
        distanciaMetros,
        tiempoEstimadoMinutos,
        tieneDesvioPorReporte,
        accesoVertical,
        Object.hashAll(puntos),
        Object.hashAll(instrucciones),
      );

  @override
  String toString() =>
      'RutaCalculada(${distanciaMetros.round()} m, $tiempoEstimadoMinutos min, '
      '${puntos.length} puntos, desvío: $tieneDesvioPorReporte)';
}
