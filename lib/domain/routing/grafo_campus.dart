import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:pontimaps_app/core/utils/colecciones.dart';
import 'package:pontimaps_app/core/utils/geo_utils.dart';
import 'package:pontimaps_app/domain/routing/cola_prioridad.dart';
import 'package:pontimaps_app/models/reporte_comunidad.dart';
import 'package:pontimaps_app/models/ruta_calculada.dart';

/// Punto del grafo peatonal: entrada de edificio, esquina, escalera...
///
/// Un nodo con [idEdificioAsociado] es una **entrada** de ese edificio y es
/// una meta válida para [GrafoCampus.calcularRutaAStar].
class NodoCamino {
  const NodoCamino({
    required this.id,
    required this.ubicacion,
    this.idEdificioAsociado,
    this.esEscaleras = false,
  }) : assert(id != '');

  final String id;
  final LatLng ubicacion;
  final String? idEdificioAsociado;
  final bool esEscaleras;

  NodoCamino copyWith({
    String? id,
    LatLng? ubicacion,
    Object? idEdificioAsociado = sinCambio,
    bool? esEscaleras,
  }) {
    return NodoCamino(
      id: id ?? this.id,
      ubicacion: ubicacion ?? this.ubicacion,
      idEdificioAsociado: identical(idEdificioAsociado, sinCambio)
          ? this.idEdificioAsociado
          : idEdificioAsociado as String?,
      esEscaleras: esEscaleras ?? this.esEscaleras,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodoCamino &&
          other.id == id &&
          other.ubicacion == ubicacion &&
          other.idEdificioAsociado == idEdificioAsociado &&
          other.esEscaleras == esEscaleras;

  @override
  int get hashCode =>
      Object.hash(id, ubicacion, idEdificioAsociado, esEscaleras);

  @override
  String toString() => 'NodoCamino($id)';
}

/// Tramo peatonal entre dos nodos.
///
/// Costo de recorrerlo: `distanciaMetros * factorCongestion`.
/// Invariantes: `distanciaMetros > 0`, `factorCongestion >= 1.0` (nunca
/// abarata un tramo; es lo que mantiene admisible la heurística de A*) y
/// `origenId != destinoId`.
///
/// [esEscaleras] marca un tramo de escalones (`highway=steps` en OpenStreetMap):
/// la ruta accesible (`evitarEscaleras`) no lo recorre.
class AristaCamino {
  const AristaCamino({
    required this.id,
    required this.origenId,
    required this.destinoId,
    required this.distanciaMetros,
    this.factorCongestion = 1.0,
    this.bloqueada = false,
    this.esEscaleras = false,
  })  : assert(id != ''),
        assert(origenId != destinoId, 'Una arista no puede ser un bucle'),
        assert(distanciaMetros > 0),
        assert(factorCongestion >= 1.0);

  final String id;
  final String origenId;
  final String destinoId;
  final double distanciaMetros;
  final double factorCongestion;
  final bool bloqueada;
  final bool esEscaleras;

  /// Costo de recorrer la arista (metros "equivalentes").
  double get costo => distanciaMetros * factorCongestion;

  AristaCamino copyWith({
    String? id,
    String? origenId,
    String? destinoId,
    double? distanciaMetros,
    double? factorCongestion,
    bool? bloqueada,
    bool? esEscaleras,
  }) {
    return AristaCamino(
      id: id ?? this.id,
      origenId: origenId ?? this.origenId,
      destinoId: destinoId ?? this.destinoId,
      distanciaMetros: distanciaMetros ?? this.distanciaMetros,
      factorCongestion: factorCongestion ?? this.factorCongestion,
      bloqueada: bloqueada ?? this.bloqueada,
      esEscaleras: esEscaleras ?? this.esEscaleras,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AristaCamino &&
          other.id == id &&
          other.origenId == origenId &&
          other.destinoId == destinoId &&
          other.distanciaMetros == distanciaMetros &&
          other.factorCongestion == factorCongestion &&
          other.bloqueada == bloqueada &&
          other.esEscaleras == esEscaleras;

  @override
  int get hashCode => Object.hash(
        id,
        origenId,
        destinoId,
        distanciaMetros,
        factorCongestion,
        bloqueada,
        esEscaleras,
      );

  @override
  String toString() => 'AristaCamino($id: $origenId -> $destinoId)';
}

/// Por qué no se pudo calcular una ruta.
enum MotivoSinRuta {
  /// El grafo no tiene nodos.
  grafoVacio,

  /// Ningún nodo del grafo está asociado al edificio destino.
  edificioSinEntradas,

  /// No hay camino entre origen y destino, ni siquiera sin reportes.
  desconectado,

  /// Existe camino, pero los reportes vigentes lo bloquean por completo.
  bloqueadoPorReportes,

  /// Con `evitarEscaleras` no hay camino, pero sí lo hay usando escaleras
  /// (el destino no es accesible sin escalones según el mapa).
  soloPorEscaleras,
}

/// Se lanza cuando no existe ruta entre el origen y el edificio destino.
class RutaNoEncontradaException implements Exception {
  const RutaNoEncontradaException(this.motivo, this.mensaje);

  final MotivoSinRuta motivo;
  final String mensaje;

  @override
  String toString() => 'RutaNoEncontradaException(${motivo.name}): $mensaje';
}

class _Busqueda {
  _Busqueda(this.nodoIds, this.aristas, this.costo);

  final List<String> nodoIds;
  final List<AristaCamino> aristas;
  final double costo;
}

class _EntradaCola {
  const _EntradaCola(this.nodoId, this.f);

  final String nodoId;
  final double f;
}

/// Grafo ponderado de senderos peatonales del campus + motor de rutas A*.
///
/// **Modelo**
/// * Cada arista se almacena una sola vez. En un grafo no dirigido
///   (`dirigido == false`, por defecto) se recorre en ambos sentidos; en uno
///   dirigido solo de `origenId` a `destinoId`.
/// * Las aristas *base* (`agregarArista`) nunca cambian. Los reportes
///   vigentes se aplican como una **capa superpuesta** (`aplicarReportesVigentes`)
///   que se reemplaza completa cada vez, así que un reporte vencido deja de
///   afectar la ruta sin tener que "deshacerlo".
///
/// **A\***
/// * Costo = suma de `distanciaMetros * factorCongestion`; las aristas
///   bloqueadas no se recorren.
/// * Heurística: distancia Haversine al destino más cercano, multiplicada por
///   `min(1, min_aristas distancia/haversine)`. Esa escala garantiza que sea
///   admisible y consistente aunque los datos tengan aristas más cortas que
///   la línea recta, así que el resultado es óptimo.
/// * Destino: un edificio puede tener varias entradas; se llega a la más
///   barata (A* con múltiples metas).
/// * Complejidad: O((V + E) log V) en el peor caso; con la heurística explora
///   mucho menos. Una malla de ~14 000 nodos se resuelve en una fracción del
///   límite de 2 s (ver pruebas).
///
/// **Privacidad:** el grafo recibe una posición solo como argumento de
/// [calcularRutaAStar] y [nodoMasCercano]; no la guarda.
class GrafoCampus {
  GrafoCampus({this.dirigido = false});

  /// Velocidad peatonal por defecto para estimar tiempos (1,25 m/s ≈ 4,5 km/h).
  /// A calibrar en campo (REQUIREMENTS A-1).
  static const double velocidadPeatonalPorDefecto = 1.25;

  /// Giro mínimo (grados) para emitir una instrucción de "girar".
  static const double _umbralGiroGrados = 30.0;

  final bool dirigido;

  final Map<String, NodoCamino> _nodos = <String, NodoCamino>{};
  final Map<String, AristaCamino> _aristasBase = <String, AristaCamino>{};
  final Map<String, List<String>> _adyacencia = <String, List<String>>{};
  final Map<String, AristaCamino> _aristasConReportes =
      <String, AristaCamino>{};

  /// min(1, distancia / haversine) sobre todas las aristas: escala de la
  /// heurística para que nunca sobreestime.
  double _escalaHeuristica = 1.0;

  int get cantidadNodos => _nodos.length;
  int get cantidadAristas => _aristasBase.length;
  Iterable<NodoCamino> get nodos => _nodos.values;

  /// Aristas base (sin el efecto de los reportes).
  Iterable<AristaCamino> get aristas => _aristasBase.values;

  NodoCamino? nodoPorId(String id) => _nodos[id];

  /// `true` si todos los nodos quedan unidos en una sola pieza.
  ///
  /// Ignora el sentido de las aristas (conectividad débil) y los bloqueos de
  /// base: responde "¿el catálogo describe un campus de una sola pieza?", no
  /// "¿se puede llegar hoy?". Un grafo sin nodos **no** es conexo. O(n + m).
  bool get esConexo {
    if (_nodos.isEmpty) return false;
    final vecinos = <String, List<String>>{
      for (final id in _nodos.keys) id: <String>[],
    };
    for (final arista in _aristasBase.values) {
      vecinos[arista.origenId]!.add(arista.destinoId);
      vecinos[arista.destinoId]!.add(arista.origenId);
    }
    final visitados = <String>{_nodos.keys.first};
    final pendientes = <String>[_nodos.keys.first];
    while (pendientes.isNotEmpty) {
      final actual = pendientes.removeLast();
      for (final vecino in vecinos[actual]!) {
        if (visitados.add(vecino)) pendientes.add(vecino);
      }
    }
    return visitados.length == _nodos.length;
  }

  /// Arista tal como se usa hoy para rutear: base + efecto de reportes.
  AristaCamino? aristaEfectiva(String id) =>
      _aristasConReportes[id] ?? _aristasBase[id];

  /// Cuántas aristas están afectadas hoy por reportes vigentes.
  int get cantidadAristasAfectadas => _aristasConReportes.length;

  /// Agrega un nodo. Lanza [ArgumentError] si el id ya existe. O(1).
  void agregarNodo(NodoCamino nodo) {
    if (_nodos.containsKey(nodo.id)) {
      throw ArgumentError.value(nodo.id, 'nodo.id', 'Nodo duplicado');
    }
    _nodos[nodo.id] = nodo;
    _adyacencia[nodo.id] = <String>[];
  }

  /// Agrega una arista entre dos nodos existentes. Lanza [ArgumentError] si el
  /// id está repetido o algún extremo no existe. O(1).
  void agregarArista(AristaCamino arista) {
    if (_aristasBase.containsKey(arista.id)) {
      throw ArgumentError.value(arista.id, 'arista.id', 'Arista duplicada');
    }
    final origen = _nodos[arista.origenId];
    final destino = _nodos[arista.destinoId];
    if (origen == null || destino == null) {
      throw ArgumentError(
        'La arista ${arista.id} referencia un nodo inexistente '
        '(${arista.origenId} -> ${arista.destinoId})',
      );
    }
    final recta = distanciaHaversine(origen.ubicacion, destino.ubicacion);
    if (recta > 0) {
      _escalaHeuristica = math.min(
        _escalaHeuristica,
        arista.distanciaMetros / recta,
      );
    }
    _aristasBase[arista.id] = arista;
    _adyacencia[arista.origenId]!.add(arista.id);
    if (!dirigido) {
      _adyacencia[arista.destinoId]!.add(arista.id);
    }
  }

  /// Atajo: crea y agrega una arista entre [origenId] y [destinoId]. Si no se
  /// da [distanciaMetros] se usa la distancia Haversine entre los nodos.
  void conectar(
    String id,
    String origenId,
    String destinoId, {
    double? distanciaMetros,
    double factorCongestion = 1.0,
    bool bloqueada = false,
    bool esEscaleras = false,
  }) {
    final origen = _nodos[origenId];
    final destino = _nodos[destinoId];
    if (origen == null || destino == null) {
      throw ArgumentError('Nodo inexistente al conectar $id');
    }
    agregarArista(
      AristaCamino(
        id: id,
        origenId: origenId,
        destinoId: destinoId,
        distanciaMetros: distanciaMetros ??
            distanciaHaversine(origen.ubicacion, destino.ubicacion),
        factorCongestion: factorCongestion,
        bloqueada: bloqueada,
        esEscaleras: esEscaleras,
      ),
    );
  }

  /// Nodo más cercano a [posicion] (distancia Haversine). O(V).
  /// Lanza [StateError] si el grafo está vacío.
  NodoCamino nodoMasCercano(LatLng posicion) {
    if (_nodos.isEmpty) throw StateError('El grafo no tiene nodos');
    NodoCamino? mejor;
    var mejorDistancia = double.infinity;
    for (final nodo in _nodos.values) {
      final d = distanciaHaversine(posicion, nodo.ubicacion);
      if (d < mejorDistancia) {
        mejorDistancia = d;
        mejor = nodo;
      }
    }
    return mejor!;
  }

  /// Arista base más cercana a [posicion] dentro de [maxMetros], o `null`. O(E).
  AristaCamino? aristaMasCercana(LatLng posicion, {double maxMetros = 30}) {
    AristaCamino? mejor;
    var mejorDistancia = maxMetros;
    for (final arista in _aristasBase.values) {
      final a = _nodos[arista.origenId]!.ubicacion;
      final b = _nodos[arista.destinoId]!.ubicacion;
      final d = distanciaPuntoSegmentoMetros(posicion, a, b);
      if (d <= mejorDistancia) {
        mejorDistancia = d;
        mejor = arista;
      }
    }
    return mejor;
  }

  /// Reemplaza la capa de reportes por la que resulta de [reportes].
  ///
  /// * Se ignoran los que no estén vigentes en [ahora] (por defecto
  ///   `DateTime.now()`; inyéctalo en pruebas).
  /// * Cada reporte afecta a su `idAristaAfectada` o, si no la trae o no
  ///   existe, a la arista más cercana a su ubicación (hasta 30 m). Si no hay
  ///   ninguna, se ignora.
  /// * `cierre` bloquea la arista; `fila`/`altaAfluencia` suben su
  ///   `factorCongestion` (se toma el mayor si hay varios).
  ///
  /// Devuelve cuántos reportes se aplicaron. O(R · E) en el peor caso.
  int aplicarReportesVigentes(
    List<ReporteComunidad> reportes, {
    DateTime? ahora,
  }) {
    _aristasConReportes.clear();
    final instante = ahora ?? DateTime.now();
    var aplicados = 0;

    for (final reporte in reportes) {
      if (!reporte.estaVigente(instante)) continue;

      var idArista = reporte.idAristaAfectada;
      if (idArista == null || !_aristasBase.containsKey(idArista)) {
        idArista = aristaMasCercana(reporte.ubicacion)?.id;
      }
      if (idArista == null) continue;

      final actual = _aristasConReportes[idArista] ?? _aristasBase[idArista]!;
      final factor = reporte.factorPenalizacion();
      final nueva = reporte.tipo == TipoReporte.cierre
          ? actual.copyWith(bloqueada: true)
          : actual.copyWith(
              factorCongestion: math.max(actual.factorCongestion, factor),
            );
      _aristasConReportes[idArista] = nueva;
      aplicados++;
    }
    return aplicados;
  }

  /// Quita el efecto de todos los reportes.
  void limpiarReportes() => _aristasConReportes.clear();

  /// Calcula la ruta más barata desde [origen] hasta una entrada del edificio
  /// [idEdificioDestino].
  ///
  /// * El origen se ajusta al nodo más cercano del grafo.
  /// * [evitarEscaleras] excluye los nodos `esEscaleras` (accesibilidad).
  /// * [velocidadMetrosPorSegundo] convierte costo en minutos.
  /// * `tieneDesvioPorReporte` es `true` si, sin los reportes, la ruta óptima
  ///   habría sido otra.
  ///
  /// Lanza [RutaNoEncontradaException] si no hay ruta (con el motivo).
  RutaCalculada calcularRutaAStar(
    LatLng origen,
    String idEdificioDestino, {
    bool evitarEscaleras = false,
    double velocidadMetrosPorSegundo = velocidadPeatonalPorDefecto,
  }) {
    if (velocidadMetrosPorSegundo <= 0) {
      throw ArgumentError.value(
        velocidadMetrosPorSegundo,
        'velocidadMetrosPorSegundo',
        'Debe ser positiva',
      );
    }
    if (_nodos.isEmpty) {
      throw const RutaNoEncontradaException(
        MotivoSinRuta.grafoVacio,
        'El grafo del campus no tiene nodos',
      );
    }
    final metas = <NodoCamino>[
      for (final nodo in _nodos.values)
        if (nodo.idEdificioAsociado == idEdificioDestino) nodo,
    ];
    if (metas.isEmpty) {
      throw RutaNoEncontradaException(
        MotivoSinRuta.edificioSinEntradas,
        'No hay entradas registradas para el edificio $idEdificioDestino',
      );
    }

    final inicio = nodoMasCercano(origen);
    final conReportes = _buscar(inicio, metas, evitarEscaleras, true);
    final hayReportes = _aristasConReportes.isNotEmpty;
    // Sin reportes la búsqueda "base" es la misma; solo se repite si hay capa.
    final sinReportes = hayReportes
        ? _buscar(inicio, metas, evitarEscaleras, false)
        : conReportes;

    if (conReportes == null) {
      if (evitarEscaleras &&
          _buscar(inicio, metas, false, true) != null) {
        throw const RutaNoEncontradaException(
          MotivoSinRuta.soloPorEscaleras,
          'El destino solo se alcanza por escaleras',
        );
      }
      if (sinReportes != null) {
        throw const RutaNoEncontradaException(
          MotivoSinRuta.bloqueadoPorReportes,
          'Los reportes vigentes bloquean todos los caminos al destino',
        );
      }
      throw RutaNoEncontradaException(
        MotivoSinRuta.desconectado,
        'No hay camino entre el origen y el edificio $idEdificioDestino',
      );
    }

    final desvio = hayReportes &&
        sinReportes != null &&
        !listasIguales(sinReportes.nodoIds, conReportes.nodoIds);

    final puntos = <LatLng>[
      for (final id in conReportes.nodoIds) _nodos[id]!.ubicacion,
    ];
    final distancia = conReportes.aristas.fold<double>(
      0,
      (suma, a) => suma + a.distanciaMetros,
    );
    var minutos = (conReportes.costo / velocidadMetrosPorSegundo / 60).round();
    if (minutos == 0 && distancia > 0) minutos = 1;

    return RutaCalculada(
      puntos: puntos,
      distanciaMetros: distancia,
      tiempoEstimadoMinutos: minutos,
      instrucciones: _construirInstrucciones(conReportes),
      tieneDesvioPorReporte: desvio,
    );
  }

  // --------------------------------------------------------------- A* ----

  _Busqueda? _buscar(
    NodoCamino inicio,
    List<NodoCamino> metas,
    bool evitarEscaleras,
    bool usarReportes,
  ) {
    final idsMetas = <String>{for (final m in metas) m.id};

    double heuristica(NodoCamino nodo) {
      var minima = double.infinity;
      for (final meta in metas) {
        final d = distanciaHaversine(nodo.ubicacion, meta.ubicacion);
        if (d < minima) minima = d;
      }
      return minima * _escalaHeuristica;
    }

    final g = <String, double>{inicio.id: 0.0};
    final previoNodo = <String, String>{};
    final previoArista = <String, AristaCamino>{};
    final cerrados = <String>{};
    final cola = ColaPrioridad<_EntradaCola>((a, b) => a.f.compareTo(b.f));
    cola.agregar(_EntradaCola(inicio.id, heuristica(inicio)));

    while (!cola.estaVacia) {
      final actual = cola.extraerMinimo();
      if (!cerrados.add(actual.nodoId)) continue; // entrada obsoleta

      if (idsMetas.contains(actual.nodoId)) {
        return _reconstruir(actual.nodoId, g[actual.nodoId]!, previoNodo, previoArista);
      }

      final costoActual = g[actual.nodoId]!;
      for (final idArista in _adyacencia[actual.nodoId]!) {
        final arista = usarReportes
            ? (_aristasConReportes[idArista] ?? _aristasBase[idArista]!)
            : _aristasBase[idArista]!;
        if (arista.bloqueada) continue;
        if (evitarEscaleras && arista.esEscaleras) continue;

        final vecinoId = arista.origenId == actual.nodoId
            ? arista.destinoId
            : arista.origenId;
        if (cerrados.contains(vecinoId)) continue;

        final vecino = _nodos[vecinoId]!;
        if (evitarEscaleras &&
            vecino.esEscaleras &&
            !idsMetas.contains(vecinoId)) {
          continue;
        }

        final tentativo = costoActual + arista.costo;
        if (tentativo < (g[vecinoId] ?? double.infinity)) {
          g[vecinoId] = tentativo;
          previoNodo[vecinoId] = actual.nodoId;
          previoArista[vecinoId] = arista;
          cola.agregar(_EntradaCola(vecinoId, tentativo + heuristica(vecino)));
        }
      }
    }
    return null;
  }

  _Busqueda _reconstruir(
    String metaId,
    double costo,
    Map<String, String> previoNodo,
    Map<String, AristaCamino> previoArista,
  ) {
    final ids = <String>[metaId];
    final aristas = <AristaCamino>[];
    var actual = metaId;
    while (previoNodo.containsKey(actual)) {
      aristas.add(previoArista[actual]!);
      actual = previoNodo[actual]!;
      ids.add(actual);
    }
    return _Busqueda(
      ids.reversed.toList(growable: false),
      aristas.reversed.toList(growable: false),
      costo,
    );
  }

  // ------------------------------------------------------ instrucciones ----

  List<InstruccionTramo> _construirInstrucciones(_Busqueda busqueda) {
    final ids = busqueda.nodoIds;
    final ultimo = ids.length - 1;
    const llegada = 'Llegaste a tu destino';

    if (ultimo == 0) {
      return const <InstruccionTramo>[
        InstruccionTramo(
          maniobra: TipoManiobra.llegada,
          texto: llegada,
          distanciaMetros: 0,
          indicePuntoInicio: 0,
          indicePuntoFin: 0,
        ),
      ];
    }

    final ubic = <LatLng>[for (final id in ids) _nodos[id]!.ubicacion];
    final rumbos = <double>[
      for (var i = 0; i < ultimo; i++) rumboGrados(ubic[i], ubic[i + 1]),
    ];

    // Un nodo intermedio abre un tramo nuevo si hay un giro marcado o escaleras.
    // Entrar a un tramo de escalones también abre tramo; al salir de ellos se
    // abre uno nuevo para que el texto no siga diciendo "escaleras".
    TipoManiobra? maniobraEn(int i) {
      final entraAEscaleras =
          busqueda.aristas[i].esEscaleras && !busqueda.aristas[i - 1].esEscaleras;
      final saleDeEscaleras =
          !busqueda.aristas[i].esEscaleras && busqueda.aristas[i - 1].esEscaleras;
      if (_nodos[ids[i]]!.esEscaleras || entraAEscaleras) {
        return TipoManiobra.escaleras;
      }
      final giro = diferenciaRumbo(rumbos[i - 1], rumbos[i]);
      if (giro.abs() >= _umbralGiroGrados) {
        return giro > 0 ? TipoManiobra.derecha : TipoManiobra.izquierda;
      }
      return saleDeEscaleras ? TipoManiobra.recto : null;
    }

    final instrucciones = <InstruccionTramo>[];
    var inicioTramo = 0;
    // Si el primer paso ya son escalones, el tramo inicial lo dice.
    var maniobraTramo = busqueda.aristas.first.esEscaleras
        ? TipoManiobra.escaleras
        : TipoManiobra.inicio;

    void cerrarTramo(int fin) {
      final metros = busqueda.aristas
          .sublist(inicioTramo, fin)
          .fold<double>(0, (suma, a) => suma + a.distanciaMetros);
      final distanciaTexto = '${metros.round()} m';
      final texto = switch (maniobraTramo) {
        TipoManiobra.inicio =>
          'Camina hacia el ${nombreCardinal(rumbos[inicioTramo])} $distanciaTexto',
        TipoManiobra.izquierda => 'Gira a la izquierda y camina $distanciaTexto',
        TipoManiobra.derecha => 'Gira a la derecha y camina $distanciaTexto',
        TipoManiobra.escaleras => 'Toma las escaleras y sigue $distanciaTexto',
        TipoManiobra.recto || TipoManiobra.llegada =>
          'Sigue recto $distanciaTexto',
      };
      instrucciones.add(
        InstruccionTramo(
          maniobra: maniobraTramo,
          texto: texto,
          distanciaMetros: metros,
          indicePuntoInicio: inicioTramo,
          indicePuntoFin: fin,
        ),
      );
    }

    for (var i = 1; i < ultimo; i++) {
      final maniobra = maniobraEn(i);
      if (maniobra == null) continue;
      cerrarTramo(i);
      inicioTramo = i;
      maniobraTramo = maniobra;
    }
    cerrarTramo(ultimo);

    instrucciones.add(
      InstruccionTramo(
        maniobra: TipoManiobra.llegada,
        texto: llegada,
        distanciaMetros: 0,
        indicePuntoInicio: ultimo,
        indicePuntoFin: ultimo,
      ),
    );
    return instrucciones;
  }
}
