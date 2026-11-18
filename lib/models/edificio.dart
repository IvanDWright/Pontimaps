import 'package:latlong2/latlong.dart';
import 'package:pontimaps_app/core/utils/colecciones.dart';
import 'package:pontimaps_app/core/utils/text_normalizer.dart';
import 'package:pontimaps_app/models/salon.dart';

/// Cómo se llega a un piso concreto de un edificio, desde la entrada.
///
/// Es **información**, no enrutamiento interior: PontiMaps guía hasta la
/// entrada del edificio y dice qué esperar para llegar al piso (REQUIREMENTS
/// §1.4: no hay navegación interior paso a paso).
class AccesoVertical {
  const AccesoVertical({
    required this.piso,
    required this.llegaEnAscensor,
    required this.multiplesAscensores,
    required this.etiqueta,
    this.advertencia,
  });

  /// Piso consultado.
  final int piso;

  /// `true` si se puede llegar a [piso] sin usar escaleras (ascensor, o nivel o
  /// rampa en la planta baja).
  final bool llegaEnAscensor;

  /// `true` si el edificio tiene una batería de más de un ascensor.
  final bool multiplesAscensores;

  /// Texto para el usuario (p. ej. "Acceso por ascensor disponible (múltiples
  /// ascensores)").
  final String etiqueta;

  /// Aviso adicional cuando el usuario pidió evitar escaleras y el piso no es
  /// alcanzable sin ellas; `null` si no hay nada que advertir.
  final String? advertencia;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccesoVertical &&
          other.piso == piso &&
          other.llegaEnAscensor == llegaEnAscensor &&
          other.multiplesAscensores == multiplesAscensores &&
          other.etiqueta == etiqueta &&
          other.advertencia == advertencia;

  @override
  int get hashCode => Object.hash(
        piso,
        llegaEnAscensor,
        multiplesAscensores,
        etiqueta,
        advertencia,
      );

  @override
  String toString() => 'AccesoVertical(piso $piso: $etiqueta)';
}

/// Edificio del campus, con su catálogo de salones.
///
/// Inmutable: las listas se copian y quedan no modificables.
///
/// Invariantes:
/// * `id` y `nombre` no vacíos.
/// * `numero` es `null` (edificio sin número oficial, como la Biblioteca o el
///   Hospital) o positivo.
/// * `niveles` (pisos sobre el suelo, de OpenStreetMap `building:levels`) es
///   `null` si se desconoce, o `>= 1`; ningún salón está por encima de él.
/// * `sotanos` (niveles subterráneos, pisos `-1 … -sotanos`) es `>= 0`; ningún
///   salón está en `piso == 0` ni por debajo de `-sotanos`.
/// * `perimetro` está vacío o tiene al menos 3 vértices.
/// * Todo salón de [salones] pertenece a este edificio (`idEdificio == id`
///   y `numeroEdificio == numero`).
/// * Los códigos de salón son únicos (comparados sin espacios ni mayúsculas).
/// * Accesibilidad: varios ascensores implican que hay ascensor; un edificio de
///   un solo nivel sin sótanos no puede tener ascensor; y mientras
///   [accesibilidadConfirmada] sea `false` los tres indicadores de
///   accesibilidad permanecen en `false` (desconocido, nunca "sí").
///
/// No es `const` porque copia defensivamente las listas e indexa los salones.
class Edificio {
  Edificio({
    required this.id,
    required this.numero,
    required this.nombre,
    required this.ubicacion,
    this.niveles,
    this.sotanos = 0,
    List<LatLng> perimetro = const <LatLng>[],
    List<Salon> salones = const <Salon>[],
    this.tieneAccesoMovilidadReducida = false,
    this.tieneAscensor = false,
    this.tieneMultiplesAscensores = false,
    this.accesibilidadConfirmada = false,
  })  : perimetro = List<LatLng>.unmodifiable(perimetro),
        salones = List<Salon>.unmodifiable(salones),
        _indicePorCodigo = _construirIndice(salones),
        assert(id != '', 'id no puede estar vacío'),
        assert(numero == null || numero > 0, 'numero debe ser positivo'),
        assert(nombre != '', 'nombre no puede estar vacío'),
        assert(niveles == null || niveles >= 1, 'niveles debe ser >= 1'),
        assert(sotanos >= 0, 'sotanos debe ser >= 0'),
        assert(
          perimetro.isEmpty || perimetro.length >= 3,
          'Un perímetro necesita al menos 3 vértices',
        ),
        assert(
          salones.every((s) => s.idEdificio == id && s.numeroEdificio == numero),
          'Todos los salones deben pertenecer a este edificio',
        ),
        assert(
          niveles == null || salones.every((s) => s.piso <= niveles),
          'Ningún salón puede estar por encima de los niveles del edificio',
        ),
        assert(
          salones.every((s) => s.piso != 0 && (s.piso > 0 || -s.piso <= sotanos)),
          'Ningún salón puede estar en el piso 0 ni por debajo de los sótanos del edificio',
        ),
        assert(
          !tieneMultiplesAscensores || tieneAscensor,
          'Varios ascensores implican que hay ascensor',
        ),
        assert(
          !tieneAscensor || niveles == null || niveles > 1 || sotanos > 0,
          'Un edificio de un solo nivel sin sótanos no tiene ascensor',
        ),
        assert(
          accesibilidadConfirmada ||
              (!tieneAscensor &&
                  !tieneMultiplesAscensores &&
                  !tieneAccesoMovilidadReducida),
          'Sin confirmar, la accesibilidad debe quedar en false (desconocida)',
        );

  final String id;

  /// Número oficial (`null` si no tiene).
  final int? numero;
  final String nombre;
  final LatLng ubicacion;

  /// Pisos sobre el suelo (`building:levels`), o `null` si no se conocen.
  final int? niveles;

  /// Cantidad de sótanos (`building:levels:underground`), numerados `-1 … -sotanos`.
  final int sotanos;
  final List<LatLng> perimetro;
  final List<Salon> salones;

  /// La entrada es accesible sin escalones (a nivel o con rampa).
  final bool tieneAccesoMovilidadReducida;

  /// Hay al menos un ascensor público operativo para subir a los pisos
  /// superiores o bajar a los sótanos.
  final bool tieneAscensor;

  /// Hay más de un ascensor (batería de ascensores: menos espera).
  final bool tieneMultiplesAscensores;

  /// `true` si los tres indicadores anteriores fueron levantados
  /// (`docs/edificios_ascensores.json`). `false` = **no se sabe**: la interfaz
  /// debe decir "sin confirmar", no "sin ascensor".
  final bool accesibilidadConfirmada;

  final Map<String, Salon> _indicePorCodigo;

  /// `"Edificio 51"`, o el nombre si el edificio no tiene número.
  String get etiqueta => numero == null ? nombre : 'Edificio $numero';

  /// Pisos sobre el suelo disponibles: `[1 … niveles]`, o vacío si se desconocen.
  List<int> get pisos {
    final n = niveles;
    if (n == null) return const <int>[];
    return <int>[for (var piso = 1; piso <= n; piso++) piso];
  }

  /// Pisos subterráneos disponibles: `[-1 … -sotanos]`, o vacío si no tiene sótanos.
  List<int> get pisosSotano => <int>[for (var s = -1; s >= -sotanos; s--) s];

  bool _pisoExiste(int piso) {
    if (piso == 0) return false;
    if (piso < 0) return -piso <= sotanos;
    return niveles == null || piso <= niveles!;
  }

  static String _nombreNivel(int piso) =>
      piso < 0 ? 'sótano ${-piso}' : 'piso $piso';

  /// `true` si se puede llegar al [piso] **sin usar escaleras**.
  ///
  /// * `piso == 1`: la planta baja es accesible si la entrada es a nivel o
  ///   tiene rampa ([tieneAccesoMovilidadReducida]).
  /// * `piso > 1` o `piso < 0` (sótano): hace falta un ascensor ([tieneAscensor]).
  /// * Si [accesibilidadConfirmada] es `false` o el piso/sótano no existe,
  ///   responde `false`: no se promete un acceso que no se conoce.
  bool puedeLlegarEnAscensor(int piso) {
    if (!accesibilidadConfirmada || !_pisoExiste(piso)) return false;
    return piso == 1 ? tieneAccesoMovilidadReducida : tieneAscensor;
  }

  /// Explica en una frase cómo llegar al [piso] sin escaleras (o por qué no).
  String etiquetaAccesibilidadVertical(int piso) {
    if (piso == 0) {
      return 'El piso 0 no existe (la planta baja es el piso 1 y los sótanos son negativos)';
    }
    if (!_pisoExiste(piso)) {
      if (piso < 0) {
        return sotanos == 0
            ? 'El sótano ${-piso} no existe: el edificio no tiene sótanos'
            : 'El sótano ${-piso} no existe: el edificio tiene $sotanos sótanos';
      }
      return 'El piso $piso no existe: el edificio tiene $niveles pisos';
    }
    if (!accesibilidadConfirmada) {
      return piso == 1
          ? 'Accesibilidad del piso 1 sin confirmar'
          : 'Acceso por ascensor sin confirmar para el ${_nombreNivel(piso)}';
    }
    if (piso == 1) {
      return tieneAccesoMovilidadReducida
          ? 'Acceso a nivel o por rampa'
          : 'Acceso al piso 1 con escalones (sin rampa)';
    }
    if (tieneAscensor) {
      return tieneMultiplesAscensores
          ? 'Acceso por ascensor disponible (múltiples ascensores)'
          : 'Acceso por ascensor disponible';
    }
    return 'Sin ascensor (solo escaleras internas para ${_nombreNivel(piso)})';
  }

  /// Acceso vertical al [piso]. Con [evitarEscaleras] añade una advertencia si
  /// no se puede llegar sin escaleras. No hace enrutamiento interior.
  AccesoVertical accesoVertical(int piso, {bool evitarEscaleras = false}) {
    final llega = puedeLlegarEnAscensor(piso);
    final String? advertencia;
    if (!evitarEscaleras || llega) {
      advertencia = null;
    } else if (!_pisoExiste(piso)) {
      advertencia = etiquetaAccesibilidadVertical(piso);
    } else if (!accesibilidadConfirmada) {
      advertencia = 'Pediste evitar escaleras, pero no se sabe si $etiqueta '
          'tiene acceso sin escaleras al ${_nombreNivel(piso)}.';
    } else if (piso == 1) {
      advertencia = 'Pediste evitar escaleras, pero la entrada de $etiqueta '
          'tiene escalones (sin rampa).';
    } else {
      advertencia = 'Pediste evitar escaleras, pero $etiqueta no tiene '
          'ascensor: el ${_nombreNivel(piso)} solo se alcanza por escaleras internas.';
    }
    return AccesoVertical(
      piso: piso,
      llegaEnAscensor: llega,
      multiplesAscensores: accesibilidadConfirmada && tieneMultiplesAscensores,
      etiqueta: etiquetaAccesibilidadVertical(piso),
      advertencia: advertencia,
    );
  }

  static Map<String, Salon> _construirIndice(List<Salon> salones) {
    final indice = <String, Salon>{};
    for (final salon in salones) {
      final clave = Salon.normalizarCodigo(salon.codigo);
      if (indice.containsKey(clave)) {
        throw ArgumentError('Código de salón duplicado: ${salon.codigo}');
      }
      indice[clave] = salon;
    }
    return Map<String, Salon>.unmodifiable(indice);
  }

  /// Busca un salón por código, ignorando espacios y mayúsculas. O(1).
  /// Devuelve `null` si no existe.
  Salon? buscarSalon(String codigo) =>
      _indicePorCodigo[Salon.normalizarCodigo(codigo)];

  static const Set<String> _palabrasIgnoradas = <String>{
    'ed',
    'ed.',
    'edificio',
    'no',
    'no.',
    'nro',
    'numero',
    '#',
  };

  /// `true` si el edificio responde a la búsqueda [query].
  ///
  /// Tolerante a tildes y mayúsculas. Cada palabra de la consulta debe
  /// coincidir: o bien es exactamente el número del edificio, o bien está
  /// contenida en el nombre. Las palabras "ed", "edificio", "no" se ignoran,
  /// de modo que `"51"`, `"ed 51"` y `"edificio angel valtierra"` funcionan.
  /// Una consulta vacía no coincide con nada. O(palabras · |nombre|).
  bool coincideConBusqueda(String query) {
    final palabras = normalizarTexto(query)
        .split(' ')
        .where((p) => p.isNotEmpty && !_palabrasIgnoradas.contains(p))
        .toList();
    if (palabras.isEmpty) return false;
    final nombreNormalizado = normalizarTexto(nombre);
    final numeroTexto = numero?.toString();
    return palabras.every(
      (p) => p == numeroTexto || nombreNormalizado.contains(p),
    );
  }

  Edificio copyWith({
    String? id,
    Object? numero = sinCambio,
    String? nombre,
    LatLng? ubicacion,
    Object? niveles = sinCambio,
    int? sotanos,
    List<LatLng>? perimetro,
    List<Salon>? salones,
    bool? tieneAccesoMovilidadReducida,
    bool? tieneAscensor,
    bool? tieneMultiplesAscensores,
    bool? accesibilidadConfirmada,
  }) {
    return Edificio(
      id: id ?? this.id,
      numero: identical(numero, sinCambio) ? this.numero : numero as int?,
      nombre: nombre ?? this.nombre,
      ubicacion: ubicacion ?? this.ubicacion,
      niveles: identical(niveles, sinCambio) ? this.niveles : niveles as int?,
      sotanos: sotanos ?? this.sotanos,
      perimetro: perimetro ?? this.perimetro,
      salones: salones ?? this.salones,
      tieneAccesoMovilidadReducida:
          tieneAccesoMovilidadReducida ?? this.tieneAccesoMovilidadReducida,
      tieneAscensor: tieneAscensor ?? this.tieneAscensor,
      tieneMultiplesAscensores:
          tieneMultiplesAscensores ?? this.tieneMultiplesAscensores,
      accesibilidadConfirmada:
          accesibilidadConfirmada ?? this.accesibilidadConfirmada,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Edificio &&
          other.id == id &&
          other.numero == numero &&
          other.nombre == nombre &&
          other.ubicacion == ubicacion &&
          other.niveles == niveles &&
          other.sotanos == sotanos &&
          other.tieneAccesoMovilidadReducida == tieneAccesoMovilidadReducida &&
          other.tieneAscensor == tieneAscensor &&
          other.tieneMultiplesAscensores == tieneMultiplesAscensores &&
          other.accesibilidadConfirmada == accesibilidadConfirmada &&
          listasIguales(other.perimetro, perimetro) &&
          listasIguales(other.salones, salones);

  @override
  int get hashCode => Object.hash(
        id,
        numero,
        nombre,
        ubicacion,
        niveles,
        sotanos,
        tieneAccesoMovilidadReducida,
        tieneAscensor,
        tieneMultiplesAscensores,
        accesibilidadConfirmada,
        Object.hashAll(perimetro),
        Object.hashAll(salones),
      );

  @override
  String toString() => 'Edificio($etiqueta · $nombre, ${salones.length} salones)';
}
