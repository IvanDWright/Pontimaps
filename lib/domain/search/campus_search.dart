import 'package:pontimaps_app/core/utils/text_normalizer.dart';
import 'package:pontimaps_app/data/campus_cartography.dart';
import 'package:pontimaps_app/models/edificio.dart';
import 'package:pontimaps_app/models/negocio_servicio.dart';
import 'package:pontimaps_app/models/salon.dart';

/// Etiqueta de ubicación de un salón: **siempre** `Edificio X · Piso Y`; en un
/// sótano (`piso < 0`) añade el nombre explícito del nivel: `(sótano 1)`.
String etiquetaSalon(Salon salon) {
  final base = salon.etiquetaUbicacion();
  return salon.piso < 0 ? '$base (sótano ${-salon.piso})' : base;
}

/// Resultado de una búsqueda sobre el catálogo del campus.
sealed class ResultadoBusqueda {
  const ResultadoBusqueda();

  /// Texto principal del resultado.
  String get titulo;

  /// Segunda línea: dónde queda (para un salón, `Edificio X · Piso Y`).
  String get subtitulo;
}

class ResultadoEdificio extends ResultadoBusqueda {
  const ResultadoEdificio(this.edificio);

  final Edificio edificio;

  @override
  String get titulo => edificio.nombre;

  @override
  String get subtitulo => edificio.etiqueta;
}

class ResultadoSalon extends ResultadoBusqueda {
  const ResultadoSalon(this.salon, this.edificio);

  final Salon salon;
  final Edificio edificio;

  @override
  String get titulo => 'Salón ${salon.codigo}';

  @override
  String get subtitulo => etiquetaSalon(salon);
}

class ResultadoServicio extends ResultadoBusqueda {
  const ResultadoServicio(this.negocio, this.ubicacion);

  final NegocioServicio negocio;

  /// `"Edificio 24 · Piso 1"` o `"Cerca del Edificio 21"`.
  final String ubicacion;

  @override
  String get titulo => negocio.nombre;

  @override
  String get subtitulo => ubicacion;
}

/// Resultados agrupados *Edificios · Salones · Servicios* (RF-BUS-04).
class ResultadosAgrupados {
  const ResultadosAgrupados({
    this.edificios = const <ResultadoEdificio>[],
    this.salones = const <ResultadoSalon>[],
    this.servicios = const <ResultadoServicio>[],
  });

  final List<ResultadoEdificio> edificios;
  final List<ResultadoSalon> salones;
  final List<ResultadoServicio> servicios;

  bool get vacio => edificios.isEmpty && salones.isEmpty && servicios.isEmpty;

  int get total => edificios.length + salones.length + servicios.length;
}

/// Búsqueda local e instantánea (sin red) sobre edificios, salones y servicios.
///
/// Tolerante a tildes, mayúsculas, números y nombres parciales: `"51"`, `"ed 51"`,
/// `"gerardo arango"`, `"67-205"`, `"67205"`, `"205"`. Una consulta vacía no
/// devuelve nada. Nunca inventa un edificio ni un piso para un salón.
class CampusSearch {
  CampusSearch(this._cartografia);

  final CampusCartography _cartografia;

  /// Máximo de resultados por grupo.
  static const int maximoPorGrupo = 8;

  static String _compactar(String texto) =>
      normalizarTexto(texto).replaceAll(RegExp(r'[^a-z0-9]'), '');

  ResultadosAgrupados buscar(String consulta) {
    final texto = normalizarTexto(consulta);
    if (texto.isEmpty) return const ResultadosAgrupados();

    final edificios = <ResultadoEdificio>[
      for (final e in _cartografia.buscarEdificios(consulta).take(maximoPorGrupo))
        ResultadoEdificio(e),
    ];

    final compacta = _compactar(consulta);
    final salones = <ResultadoSalon>[];
    if (compacta.length >= 2) {
      for (final edificio in _cartografia.edificios) {
        for (final salon in edificio.salones) {
          if (_compactar(salon.codigo).contains(compacta)) {
            salones.add(ResultadoSalon(salon, edificio));
            if (salones.length >= maximoPorGrupo) break;
          }
        }
        if (salones.length >= maximoPorGrupo) break;
      }
    }

    final servicios = <ResultadoServicio>[
      for (final n in _cartografia.buscarNegocios(consulta).take(maximoPorGrupo))
        ResultadoServicio(n, _cartografia.etiquetaUbicacion(n)),
    ];

    return ResultadosAgrupados(
      edificios: edificios,
      salones: salones,
      servicios: servicios,
    );
  }
}
