import 'package:pontimaps_app/data/campus_cartography.dart';
import 'package:pontimaps_app/domain/services/opening_hours.dart';
import 'package:pontimaps_app/models/negocio_servicio.dart';
import 'package:pontimaps_app/models/reporte_comunidad.dart';

/// Filtros por categoría del directorio (chips de `directory_screen`).
enum FiltroDirectorio {
  todos('Todos'),
  cafeterias('Cafeterías'),
  papelerias('Papelerías'),
  atencion('Atención'),
  bienestar('Bienestar');

  const FiltroDirectorio(this.etiqueta);

  final String etiqueta;

  /// `true` si [categoria] pertenece a este filtro. Los comercios aliados
  /// (p. ej. el plotter de la Calle 40C) cuentan como papelerías.
  bool incluye(CategoriaServicio categoria) {
    switch (this) {
      case FiltroDirectorio.todos:
        return true;
      case FiltroDirectorio.cafeterias:
        return categoria == CategoriaServicio.cafeteria;
      case FiltroDirectorio.papelerias:
        return categoria == CategoriaServicio.papeleria ||
            categoria == CategoriaServicio.comercioAliado;
      case FiltroDirectorio.atencion:
        return categoria == CategoriaServicio.atencionEstudiante;
      case FiltroDirectorio.bienestar:
        return categoria == CategoriaServicio.bienestar;
    }
  }
}

/// Un lugar del directorio con su estado de apertura y nivel de fila vigentes.
class LugarDirectorio {
  const LugarDirectorio({
    required this.negocio,
    required this.horario,
    required this.nivelFila,
    required this.ubicacionEtiqueta,
  });

  final NegocioServicio negocio;
  final EstadoHorario horario;

  /// `null` si no hay un reporte `Fila larga` vigente en el lugar.
  final NivelCongestion? nivelFila;

  /// `Edificio 24 · Piso 1` o `Cerca del Edificio 21`.
  final String ubicacionEtiqueta;

  /// Los comercios aliados se marcan con la etiqueta «Aliado» (RF-DIR-05).
  bool get esAliado => negocio.categoria == CategoriaServicio.comercioAliado;

  String get etiquetaFila => etiquetaNivelFila(nivelFila);
}

/// Texto del nivel de fila. Sin reporte vigente es **«Sin datos recientes»**,
/// nunca «Sin fila» (RF-DIR-04).
String etiquetaNivelFila(NivelCongestion? nivel) {
  switch (nivel) {
    case null:
      return 'Sin datos recientes';
    case NivelCongestion.baja:
      return 'Sin fila';
    case NivelCongestion.media:
      return 'Fila moderada';
    case NivelCongestion.alta:
      return 'Fila larga';
  }
}

/// Nivel de fila de un lugar a partir de los reportes `fila` vigentes anclados
/// a él: ninguno → `null`; un reporte sin confirmar → moderada; dos reportes o
/// al menos una confirmación → larga.
NivelCongestion? nivelFilaDe(
  String idLugar,
  Iterable<ReporteComunidad> reportes,
  DateTime ahora,
) {
  var cantidad = 0;
  var confirmaciones = 0;
  for (final r in reportes) {
    if (r.tipo != TipoReporte.fila || r.idLugar != idLugar || !r.estaVigente(ahora)) continue;
    cantidad++;
    confirmaciones += r.confirmaciones;
  }
  if (cantidad == 0) return null;
  return cantidad >= 2 || confirmaciones >= 1 ? NivelCongestion.alta : NivelCongestion.media;
}

/// Fuente de los lugares del directorio.
abstract class PlacesRepository {
  List<LugarDirectorio> lugares({
    FiltroDirectorio filtro = FiltroDirectorio.todos,
    required DateTime ahora,
    Iterable<ReporteComunidad> reportes = const <ReporteComunidad>[],
  });
}

/// Lugares semilla del catálogo local (funciona sin red, RF-DIR-01).
class SeedPlacesRepository implements PlacesRepository {
  SeedPlacesRepository(this._cartografia);

  final CampusCartography _cartografia;

  @override
  List<LugarDirectorio> lugares({
    FiltroDirectorio filtro = FiltroDirectorio.todos,
    required DateTime ahora,
    Iterable<ReporteComunidad> reportes = const <ReporteComunidad>[],
  }) {
    return <LugarDirectorio>[
      for (final n in _cartografia.negocios)
        if (filtro.incluye(n.categoria))
          LugarDirectorio(
            negocio: n,
            horario: estadoDeNegocio(n, ahora),
            nivelFila: nivelFilaDe(n.id, reportes, ahora),
            ubicacionEtiqueta: _cartografia.etiquetaUbicacion(n),
          ),
    ];
  }
}
