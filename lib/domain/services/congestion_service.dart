import 'package:latlong2/latlong.dart';
import 'package:pontimaps_app/core/utils/geo_utils.dart';
import 'package:pontimaps_app/data/campus_cartography.dart';
import 'package:pontimaps_app/models/negocio_servicio.dart';
import 'package:pontimaps_app/models/reporte_comunidad.dart';

/// Una zona del campus sobre la que se agregan los reportes: uno o varios
/// puntos ([anclas], tomados del catálogo) con un [radioMetros] de alcance.
class ZonaCongestion {
  const ZonaCongestion({
    required this.id,
    required this.nombre,
    required this.anclas,
    required this.radioMetros,
  })  : assert(id != ''),
        assert(nombre != ''),
        assert(radioMetros > 0);

  final String id;
  final String nombre;
  final List<LatLng> anclas;
  final double radioMetros;

  /// Distancia en metros desde [punto] hasta el ancla más cercana.
  double distanciaA(LatLng punto) {
    var mejor = double.infinity;
    for (final ancla in anclas) {
      final d = distanciaHaversine(punto, ancla);
      if (d < mejor) mejor = d;
    }
    return mejor;
  }

  bool contiene(LatLng punto) => distanciaA(punto) <= radioMetros;
}

/// Congestión de una zona en un instante.
class CongestionZona {
  const CongestionZona({
    required this.zona,
    required this.nivel,
    required this.puntaje,
    required this.reportes,
  });

  final ZonaCongestion zona;

  /// `null` si no hay reportes vigentes en la zona: «Sin datos recientes».
  final NivelCongestion? nivel;

  /// Suma ponderada de los reportes vigentes de la zona.
  final double puntaje;

  /// Cantidad de reportes vigentes que cuentan en la zona.
  final int reportes;

  /// «Baja», «Media», «Alta» o «Sin datos recientes» (texto, no solo color).
  String get etiqueta => CongestionService.etiquetaNivel(nivel);
}

/// Congestión por zonas a partir de los reportes vigentes (Path 4, P4-01).
///
/// Privacidad (Ley 1581): solo se usan reportes anónimos y vigentes. No hay
/// presencia ni posiciones de personas, ni historial por usuario.
///
/// Regla de puntaje de cada reporte vigente: *Alta afluencia* 2,0 · *Fila larga*
/// 1,5 · *Cierre de paso* 1,0; cada confirmación suma 0,5 y cada voto negativo
/// resta 0,5 (sin bajar de 0). El nivel de la zona sale de la suma:
/// 0 reportes → sin datos · `< 2` → **Baja** · `< 4` → **Media** · `≥ 4` → **Alta**.
abstract final class CongestionService {
  static const double pesoAltaAfluencia = 2.0;
  static const double pesoFila = 1.5;
  static const double pesoCierre = 1.0;
  static const double ajustePorVoto = 0.5;

  /// Puntaje desde el que una zona pasa de Baja a Media.
  static const double umbralMedia = 2.0;

  /// Puntaje desde el que una zona pasa de Media a Alta.
  static const double umbralAlta = 4.0;

  static String etiquetaNivel(NivelCongestion? nivel) {
    switch (nivel) {
      case null:
        return 'Sin datos recientes';
      case NivelCongestion.baja:
        return 'Baja';
      case NivelCongestion.media:
        return 'Media';
      case NivelCongestion.alta:
        return 'Alta';
    }
  }

  /// Aporte de un reporte al puntaje de su zona.
  static double puntajeDe(ReporteComunidad reporte) {
    final base = switch (reporte.tipo) {
      TipoReporte.altaAfluencia => pesoAltaAfluencia,
      TipoReporte.fila => pesoFila,
      TipoReporte.cierre => pesoCierre,
    };
    final ajustado =
        base + ajustePorVoto * reporte.confirmaciones - ajustePorVoto * reporte.reportesNegativos;
    return ajustado < 0 ? 0 : ajustado;
  }

  static NivelCongestion? nivelPara(double puntaje, int reportes) {
    if (reportes == 0) return null;
    if (puntaje >= umbralAlta) return NivelCongestion.alta;
    if (puntaje >= umbralMedia) return NivelCongestion.media;
    return NivelCongestion.baja;
  }

  /// Las cinco zonas del campus. Sus puntos salen del catálogo (edificios y
  /// servicios reales), salvo la Plazoleta Central (`4.6285, -74.0645`).
  static List<ZonaCongestion> zonasDelCampus(CampusCartography cartografia) {
    LatLng? edificio(String id) => cartografia.edificioPorId(id)?.ubicacion;
    LatLng? servicio(String id) => cartografia.negocioPorId(id)?.ubicacion;
    List<LatLng> puntos(Iterable<LatLng?> candidatos) => <LatLng>[
          for (final p in candidatos) ?p,
        ];

    return <ZonaCongestion>[
      const ZonaCongestion(
        id: 'plazoleta-central',
        nombre: 'Plazoleta Central',
        anclas: <LatLng>[LatLng(4.6285, -74.0645)],
        radioMetros: 60,
      ),
      ZonaCongestion(
        id: 'ingenieria',
        nombre: 'Ingeniería',
        anclas: puntos(<LatLng?>[edificio(IdEdificio.ed11), edificio(IdEdificio.ed12)]),
        radioMetros: 70,
      ),
      ZonaCongestion(
        id: 'ciencias-biblioteca',
        nombre: 'Ciencias y Biblioteca',
        anclas: puntos(<LatLng?>[edificio(IdEdificio.biblioteca), edificio(IdEdificio.cienciasPuj)]),
        radioMetros: 90,
      ),
      ZonaCongestion(
        id: 'artes-pablo-vi',
        nombre: 'Artes y Pablo VI',
        anclas: puntos(<LatLng?>[edificio(IdEdificio.ed41), edificio('ed42')]),
        radioMetros: 60,
      ),
      ZonaCongestion(
        id: 'cafeteria-central',
        nombre: 'Cafetería Central',
        anclas: puntos(<LatLng?>[servicio('cafeteria-la-central')]),
        radioMetros: 40,
      ),
    ].where((z) => z.anclas.isNotEmpty).toList(growable: false);
  }

  /// Congestión de cada zona con los reportes vigentes en [ahora]. Un reporte
  /// cuenta una sola vez, en la zona cuya ancla le queda más cerca (dentro de su
  /// radio); los vencidos u ocultos no cuentan.
  static List<CongestionZona> calcular({
    required List<ZonaCongestion> zonas,
    required Iterable<ReporteComunidad> reportes,
    required DateTime ahora,
  }) {
    final puntajes = <String, double>{for (final z in zonas) z.id: 0};
    final cantidades = <String, int>{for (final z in zonas) z.id: 0};

    for (final r in reportes) {
      if (!r.estaVigente(ahora)) continue;
      ZonaCongestion? destino;
      var mejor = double.infinity;
      for (final z in zonas) {
        final d = z.distanciaA(r.ubicacion);
        if (d <= z.radioMetros && d < mejor) {
          mejor = d;
          destino = z;
        }
      }
      if (destino == null) continue;
      puntajes[destino.id] = puntajes[destino.id]! + puntajeDe(r);
      cantidades[destino.id] = cantidades[destino.id]! + 1;
    }

    return <CongestionZona>[
      for (final z in zonas)
        CongestionZona(
          zona: z,
          nivel: nivelPara(puntajes[z.id]!, cantidades[z.id]!),
          puntaje: puntajes[z.id]!,
          reportes: cantidades[z.id]!,
        ),
    ];
  }
}
