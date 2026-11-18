import 'package:latlong2/latlong.dart';
import 'package:pontimaps_app/core/utils/text_normalizer.dart';
import 'package:pontimaps_app/data/campus_osm_data.dart';
import 'package:pontimaps_app/domain/routing/grafo_campus.dart';
import 'package:pontimaps_app/models/edificio.dart';
import 'package:pontimaps_app/models/negocio_servicio.dart';
import 'package:pontimaps_app/models/ruta_calculada.dart';
import 'package:pontimaps_app/models/salon.dart';

// ============================================================================
// Base cartográfica de PontiMaps.
//
// Funciona 100 % sin red: es el catálogo local que usan visitantes y la demo.
//
// ORIGEN DE LOS DATOS — OpenStreetMap (`docs/javeriana_osm.geojson`, © colabora-
// dores de OpenStreetMap, licencia ODbL; hay que mostrar la atribución en la
// app). `tool/generar_campus_osm.py` filtra el GeoJSON y escribe
// `campus_osm_data.dart` con:
//   * edificios y servicios del campus: nombre y número oficiales, centroide real
//     del polígono y `building:levels` como número de pisos;
//   * el grafo peatonal real (`highway=footway|pedestrian|path|steps`): cada
//     distancia es Haversine sobre la polilínea real y los tramos `steps` son
//     escaleras (`esEscaleras`).
//
// Lo que NO viene de OpenStreetMap (y sigue siendo provisional):
//   * Los salones (excepto 67-205, del mockup) son ejemplos coherentes con los
//     pisos de cada edificio; el catálogo real de salones está por levantar.
//   * Los horarios de la mayoría de los servicios (`horarioConfirmado: false`).
//   * Ascensores y accesibilidad vienen de `docs/edificios_ascensores.json`
//     (cruzado con el GeoJSON por `osmWayId`; no se usa el ascensor privado de
//     OSM). Solo 20 edificios de clase, Biblioteca y Edificio Ciencias PUJ
//     están cubiertos (`accesibilidadConfirmada: true`); en el resto la
//     accesibilidad queda "sin confirmar" (todos los indicadores en `false`,
//     que significa "no se sabe", nunca "sin ascensor").
//   * Las entradas son el vértice del contorno del edificio más cercano a un
//     sendero, no una puerta medida en campo.
// ============================================================================

/// IDs de edificios que usan las pruebas y las pantallas.
abstract final class IdEdificio {
  static const String ed02 = 'ed02';
  static const String ed03 = 'ed03';
  static const String ed08 = 'ed08';
  static const String ed11 = 'ed11';
  static const String ed12 = 'ed12';
  static const String ed18 = 'ed18';
  static const String ed20 = 'ed20';
  static const String ed21 = 'ed21';
  static const String ed24 = 'ed24';
  static const String ed25 = 'ed25';
  static const String ed41 = 'ed41';
  static const String ed51 = 'ed51';
  static const String ed52 = 'ed52';
  static const String ed53 = 'ed53';
  static const String ed67 = 'ed67';
  static const String biblioteca = 'biblioteca';
  static const String hospital = 'hospital';
  static const String cienciasPuj = 'ciencias-puj';
}

class _SalonSemilla {
  const _SalonSemilla(this.codigo, this.piso, [this.tipo = TipoSalon.aula]);

  final String codigo;
  final int piso;
  final TipoSalon tipo;
}

/// Salones por edificio. El primer dígito del número es el piso. Solo `67-205`
/// viene del mockup; el resto son ejemplos coherentes con `building:levels`.
const Map<String, List<_SalonSemilla>> _salonesSemilla = <String, List<_SalonSemilla>>{
  IdEdificio.ed02: <_SalonSemilla>[
    _SalonSemilla('2-101', 1),
    _SalonSemilla('2-204', 2),
    _SalonSemilla('2-501', 5),
  ],
  IdEdificio.ed03: <_SalonSemilla>[
    _SalonSemilla('3-101', 1),
    _SalonSemilla('3-302', 3),
  ],
  IdEdificio.ed11: <_SalonSemilla>[
    _SalonSemilla('11-201', 2),
    _SalonSemilla('11-405', 4),
  ],
  IdEdificio.ed12: <_SalonSemilla>[
    _SalonSemilla('12-S101', -1, TipoSalon.laboratorio),
    _SalonSemilla('12-301', 3, TipoSalon.laboratorio),
  ],
  IdEdificio.ed18: <_SalonSemilla>[
    _SalonSemilla('18-101', 1),
    _SalonSemilla('18-201', 2),
  ],
  IdEdificio.ed21: <_SalonSemilla>[
    _SalonSemilla('21-105', 1),
    _SalonSemilla('21-304', 3),
  ],
  IdEdificio.ed51: <_SalonSemilla>[
    _SalonSemilla('51-101', 1),
    _SalonSemilla('51-301', 3),
    _SalonSemilla('51-LAB2', 1, TipoSalon.laboratorio),
  ],
  IdEdificio.ed52: <_SalonSemilla>[
    _SalonSemilla('52-203', 2),
    _SalonSemilla('52-601', 6),
  ],
  IdEdificio.ed53: <_SalonSemilla>[
    _SalonSemilla('53-101', 1),
    _SalonSemilla('53-302', 3),
  ],
  IdEdificio.ed67: <_SalonSemilla>[
    _SalonSemilla('67-101', 1),
    _SalonSemilla('67-205', 2), // del mockup: "Edificio 67 · Piso 2"
    _SalonSemilla('67-301', 3, TipoSalon.laboratorio),
  ],
};

/// Construye el grafo peatonal real del campus: un nodo por vértice relevante
/// del sendero, una **entrada** por edificio/servicio (`idEdificioAsociado`) y
/// un tramo por cada polilínea simplificada, con su distancia en metros y
/// `esEscaleras` para los `highway=steps`. Es conexo (se comprueba en las
/// pruebas y en [CampusCartography.validar]).
GrafoCampus crearGrafoCampus() {
  final grafo = GrafoCampus();
  for (final (id, lat, lng, lugar) in osmNodos) {
    grafo.agregarNodo(
      NodoCamino(id: id, ubicacion: LatLng(lat, lng), idEdificioAsociado: lugar),
    );
  }
  final repeticiones = <String, int>{};
  for (final (origen, destino, metros, escaleras) in osmSenderos) {
    final base = 'e_${origen}_$destino';
    final n = repeticiones.update(base, (v) => v + 1, ifAbsent: () => 0);
    grafo.conectar(
      n == 0 ? base : '${base}_$n',
      origen,
      destino,
      distanciaMetros: metros,
      esEscaleras: escaleras,
    );
  }
  return grafo;
}

Edificio _construirEdificio(OsmEdificio o) {
  return Edificio(
    id: o.id,
    numero: o.numero,
    nombre: o.nombre,
    ubicacion: LatLng(o.lat, o.lng),
    niveles: o.niveles,
    sotanos: o.sotanos,
    tieneAscensor: o.tieneAscensor,
    tieneMultiplesAscensores: o.tieneMultiplesAscensores,
    tieneAccesoMovilidadReducida: o.accesoMovilidadReducida,
    accesibilidadConfirmada: o.accesibilidadConfirmada,
    perimetro: <LatLng>[for (final (lat, lng) in o.perimetro) LatLng(lat, lng)],
    salones: <Salon>[
      for (final salon in _salonesSemilla[o.id] ?? const <_SalonSemilla>[])
        Salon(
          codigo: salon.codigo,
          piso: salon.piso,
          idEdificio: o.id,
          nombreEdificio: o.nombre,
          numeroEdificio: o.numero,
          tipo: salon.tipo,
        ),
    ],
  );
}

NegocioServicio _construirNegocio(OsmServicio o) {
  return NegocioServicio(
    id: o.id,
    nombre: o.nombre,
    categoria: CategoriaServicio.values.byName(o.categoria),
    ubicacion: LatLng(o.lat, o.lng),
    idEdificioCercano: o.idEdificio,
    horaApertura: o.apertura,
    horaCierre: o.cierre,
    piso: o.piso,
    dentroDeEdificio: o.dentroDeEdificio,
    horarioConfirmado: o.horarioConfirmado,
  );
}

/// Catálogo local del campus: edificios (con sus salones), servicios y grafo
/// peatonal. Dart puro: no depende de Flutter ni de Firebase.
class CampusCartography {
  CampusCartography._({
    required List<Edificio> edificios,
    required List<NegocioServicio> negocios,
    required this.grafo,
  })  : edificios = List<Edificio>.unmodifiable(edificios),
        negocios = List<NegocioServicio>.unmodifiable(negocios);

  /// Catálogo del campus (el que usa la app sin red).
  factory CampusCartography.seed() {
    final edificios = <Edificio>[for (final o in osmEdificios) _construirEdificio(o)];
    return CampusCartography._(
      edificios: edificios,
      negocios: <NegocioServicio>[
        for (final o in osmServicios) _construirNegocio(o),
        ..._serviciosAnclados(edificios),
      ],
      grafo: crearGrafoCampus(),
    );
  }

  /// `true`: edificios, servicios y senderos provienen de OpenStreetMap
  /// (`docs/javeriana_osm.geojson`), no de una estimación. Siguen sin verificarse
  /// puertas ni rampas en campo (ver el encabezado de este archivo).
  static const bool coordenadasVerificadas = true;

  /// Atribución obligatoria de los datos (licencia ODbL).
  static const String atribucion = '© colaboradores de OpenStreetMap';

  final List<Edificio> edificios;
  final List<NegocioServicio> negocios;
  final GrafoCampus grafo;

  /// Todos los salones del campus.
  List<Salon> get salones => <Salon>[
        for (final edificio in edificios) ...edificio.salones,
      ];

  /// Edificios que tienen salones (los de clase).
  List<Edificio> get edificiosDeClase =>
      edificios.where((e) => e.salones.isNotEmpty).toList(growable: false);

  Edificio? edificioPorId(String id) {
    for (final edificio in edificios) {
      if (edificio.id == id) return edificio;
    }
    return null;
  }

  Edificio? edificioPorNumero(int numero) {
    for (final edificio in edificios) {
      if (edificio.numero == numero) return edificio;
    }
    return null;
  }

  NegocioServicio? negocioPorId(String id) {
    for (final negocio in negocios) {
      if (negocio.id == id) return negocio;
    }
    return null;
  }

  /// Nodos de entrada del lugar [idLugar] (un edificio o un servicio
  /// independiente): las metas del A*.
  List<NodoCamino> entradasDe(String idLugar) => <NodoCamino>[
        for (final nodo in grafo.nodos)
          if (nodo.idEdificioAsociado == idLugar) nodo,
      ];

  /// Id con el que se pide la ruta hacia [negocio]: su propio id si es una
  /// construcción independiente, o el de su edificio si queda dentro de él.
  String idDestinoRuta(NegocioServicio negocio) =>
      negocio.dentroDeEdificio ? negocio.idEdificioCercano : negocio.id;

  /// Calcula la ruta exterior hasta la entrada de [idDestino] (un edificio o un
  /// servicio independiente) y, si se indica el [piso], le adjunta el
  /// [AccesoVertical] del edificio: si ese piso se alcanza por ascensor (y si
  /// hay varios) o solo por escaleras internas.
  ///
  /// No hay enrutamiento interior (REQUIREMENTS §1.4): la ruta termina en la
  /// entrada y el acceso vertical es información. Con [evitarEscaleras] los
  /// senderos exteriores con gradas se evitan y, si el piso solo se alcanza por
  /// escaleras internas, el acceso trae una `advertencia`. Lanza
  /// [RutaNoEncontradaException] igual que `GrafoCampus.calcularRutaAStar`.
  RutaCalculada calcularRuta(
    LatLng origen,
    String idDestino, {
    int? piso,
    bool evitarEscaleras = false,
    double velocidadMetrosPorSegundo = GrafoCampus.velocidadPeatonalPorDefecto,
  }) {
    final ruta = grafo.calcularRutaAStar(
      origen,
      idDestino,
      evitarEscaleras: evitarEscaleras,
      velocidadMetrosPorSegundo: velocidadMetrosPorSegundo,
    );
    final edificio = edificioPorId(idDestino);
    if (piso == null || edificio == null) return ruta;
    return ruta.copyWith(
      accesoVertical: edificio.accesoVertical(piso, evitarEscaleras: evitarEscaleras),
    );
  }

  /// Ruta hasta el edificio de un [salon], con el acceso vertical a su piso.
  RutaCalculada calcularRutaHaciaSalon(
    LatLng origen,
    Salon salon, {
    bool evitarEscaleras = false,
    double velocidadMetrosPorSegundo = GrafoCampus.velocidadPeatonalPorDefecto,
  }) {
    return calcularRuta(
      origen,
      salon.idEdificio,
      piso: salon.piso,
      evitarEscaleras: evitarEscaleras,
      velocidadMetrosPorSegundo: velocidadMetrosPorSegundo,
    );
  }

  /// Busca un salón por código en todo el campus (sin importar mayúsculas ni
  /// espacios: `"67-205"`, `"67 - 205"`). `null` si no existe.
  Salon? buscarSalon(String codigo) {
    for (final edificio in edificios) {
      final salon = edificio.buscarSalon(codigo);
      if (salon != null) return salon;
    }
    return null;
  }

  /// Edificios que responden a la consulta (ver `Edificio.coincideConBusqueda`).
  List<Edificio> buscarEdificios(String query) => edificios
      .where((e) => e.coincideConBusqueda(query))
      .toList(growable: false);

  /// Servicios cuyo nombre contiene la consulta (sin tildes ni mayúsculas).
  List<NegocioServicio> buscarNegocios(String query) {
    final buscado = normalizarTexto(query);
    if (buscado.isEmpty) return const <NegocioServicio>[];
    return negocios
        .where((n) => normalizarTexto(n.nombre).contains(buscado))
        .toList(growable: false);
  }

  /// Ubicación legible de un servicio: `"Edificio 24 · Piso 1"` si queda dentro
  /// de un edificio, o `"Cerca del Edificio 21"` si es una construcción propia.
  /// Lanza [StateError] si su edificio no existe.
  String etiquetaUbicacion(NegocioServicio negocio) {
    final edificio = edificioPorId(negocio.idEdificioCercano);
    if (edificio == null) {
      throw StateError(
        'El edificio ${negocio.idEdificioCercano} de ${negocio.nombre} no existe',
      );
    }
    return negocio.dentroDeEdificio
        ? '${edificio.etiqueta} · Piso ${negocio.piso}'
        : 'Cerca de ${edificio.etiqueta == edificio.nombre ? 'el ${edificio.nombre}' : edificio.etiqueta}';
  }

  /// Revisa la integridad del catálogo y devuelve los problemas encontrados
  /// (lista vacía = todo bien):
  ///
  /// * el grafo debe ser conexo;
  /// * todo edificio y todo servicio independiente debe tener un nodo de entrada;
  /// * todo nodo de entrada debe apuntar a un edificio o servicio existente;
  /// * todo servicio debe estar junto a un edificio existente.
  List<String> validar() {
    final problemas = <String>[];
    if (!grafo.esConexo) {
      problemas.add('El grafo peatonal no es conexo');
    }
    for (final edificio in edificios) {
      if (entradasDe(edificio.id).isEmpty) {
        problemas.add('${edificio.etiqueta} no tiene nodo de entrada');
      }
    }
    for (final negocio in negocios) {
      if (edificioPorId(negocio.idEdificioCercano) == null) {
        problemas.add(
          '${negocio.nombre} apunta al edificio inexistente ${negocio.idEdificioCercano}',
        );
      }
      if (!negocio.dentroDeEdificio && entradasDe(negocio.id).isEmpty) {
        problemas.add('${negocio.nombre} no tiene nodo de entrada');
      }
    }
    for (final nodo in grafo.nodos) {
      final id = nodo.idEdificioAsociado;
      if (id != null && edificioPorId(id) == null && negocioPorId(id) == null) {
        problemas.add('El nodo ${nodo.id} apunta al lugar inexistente $id');
      }
    }
    return problemas;
  }
}

/// Servicios del campus que OpenStreetMap no trae como lugares propios y que se
/// **anclan a edificios reales del catálogo**: usan la ubicación del edificio (no
/// una coordenada inventada), así el buscador, los pines y las rutas funcionan.
///
/// * Atención al Estudiante → Edificio 21 (Emilio Arango, S.J.), piso 1, `Mo-Fr 08:00-17:00`.
/// * Centro de Bienestar / Medio Universitario → Edificio 41 (Pablo VI), piso 1, `Mo-Fr 07:00-19:00`.
List<NegocioServicio> _serviciosAnclados(List<Edificio> edificios) {
  Edificio? porNumero(int numero) {
    for (final e in edificios) {
      if (e.numero == numero) return e;
    }
    return null;
  }

  final ed21 = porNumero(21);
  final ed41 = porNumero(41);
  return <NegocioServicio>[
    if (ed21 != null)
      NegocioServicio(
        id: 'atencion-estudiante',
        nombre: 'Atención al Estudiante',
        categoria: CategoriaServicio.atencionEstudiante,
        ubicacion: ed21.ubicacion,
        idEdificioCercano: ed21.id,
        horaApertura: '08:00',
        horaCierre: '17:00',
        diasAbierto: NegocioServicio.lunesAViernes,
      ),
    if (ed41 != null)
      NegocioServicio(
        id: 'centro-bienestar',
        nombre: 'Centro de Bienestar (Medio Universitario)',
        categoria: CategoriaServicio.bienestar,
        ubicacion: ed41.ubicacion,
        idEdificioCercano: ed41.id,
        horaApertura: '07:00',
        horaCierre: '19:00',
        diasAbierto: NegocioServicio.lunesAViernes,
      ),
  ];
}
