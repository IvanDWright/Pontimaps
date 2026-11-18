import 'package:pontimaps_app/models/reporte_comunidad.dart';

/// Voto de la comunidad sobre un reporte.
enum VotoReporte {
  /// «Sigue ahí»: confirma el reporte (+1 y +30 min de vida).
  sigueAhi,

  /// «Falso / Ya no está»: voto negativo (con 3 el reporte se oculta).
  falso,
}

/// Resultado de intentar calificar un reporte.
enum ResultadoVoto {
  registrado,

  /// El reporte venció o se ocultó: no se puede calificar ni revivir (E3-11).
  noVigente,

  /// El autor no califica su propio reporte.
  esAutor,

  /// Un voto por cuenta y reporte.
  yaVoto,
}

/// Reporte tras un intento de calificación.
class CalificacionResultado {
  const CalificacionResultado(this.resultado, this.reporte);

  final ResultadoVoto resultado;

  /// El reporte, actualizado solo si el voto se [registro].
  final ReporteComunidad reporte;

  bool get registro => resultado == ResultadoVoto.registrado;
}

/// Resultado de intentar publicar un reporte nuevo.
enum ResultadoPublicacion {
  publicado,

  /// Se reportó hace menos del intervalo mínimo (E3-04).
  demasiadoPronto,

  /// Ya hay un reporte igual vigente en ese tramo: se ofrece confirmarlo (E3-05).
  duplicado,
}

/// Lógica pura de moderación comunitaria (módulo `moderation_service`).
///
/// No guarda estado ni identidades: recibe el reporte, quién vota y quiénes
/// votaron antes. El *hash* del votante es el mismo `authorHash` seudonimizado
/// (SHA-256 del `uid`); nunca se muestra.
abstract final class ModerationService {
  /// Intervalo mínimo entre dos reportes de la misma cuenta (RF-REP-06).
  static const Duration intervaloMinimoEntreReportes = Duration(minutes: 1);

  /// Ventana en la que un reporte igual en el mismo tramo cuenta como duplicado.
  static const Duration ventanaDuplicado = Duration(minutes: 10);

  /// Aplica el [voto] de [votanteHash] sobre [reporte].
  ///
  /// Reglas (RF-REP-04 y RF-REP-05), en este orden:
  /// 1. un reporte vencido u oculto no se califica ni se revive;
  /// 2. el autor no vota el suyo;
  /// 3. una cuenta vota una sola vez por reporte (cualquiera de los dos votos);
  /// 4. «Sigue ahí» suma una confirmación y extiende `expiraEn` +30 min
  ///    (tope 180 min desde `creadoEn`); «Falso / Ya no está» suma un voto
  ///    negativo y con 3 el reporte deja de estar vigente.
  static CalificacionResultado calificar({
    required ReporteComunidad reporte,
    required String votanteHash,
    required VotoReporte voto,
    required Set<String> votantesPrevios,
    required DateTime ahora,
  }) {
    if (!reporte.estaVigente(ahora)) {
      return CalificacionResultado(ResultadoVoto.noVigente, reporte);
    }
    if (reporte.authorHash != null && reporte.authorHash == votanteHash) {
      return CalificacionResultado(ResultadoVoto.esAutor, reporte);
    }
    if (votantesPrevios.contains(votanteHash)) {
      return CalificacionResultado(ResultadoVoto.yaVoto, reporte);
    }
    final actualizado = voto == VotoReporte.sigueAhi ? reporte.confirmar(ahora) : reporte.negar();
    return CalificacionResultado(ResultadoVoto.registrado, actualizado);
  }

  /// `true` si la cuenta ya puede publicar otro reporte: pasó el
  /// [intervaloMinimoEntreReportes] desde el último que publicó.
  static bool puedePublicar({DateTime? ultimoReporteEn, required DateTime ahora}) {
    if (ultimoReporteEn == null) return true;
    return ahora.difference(ultimoReporteEn) >= intervaloMinimoEntreReportes;
  }

  /// Reporte vigente igual (mismo tipo y mismo tramo o lugar) creado hace menos
  /// de [ventanaDuplicado]; `null` si no hay. Es de mejor esfuerzo, en el cliente.
  static ReporteComunidad? buscarDuplicado({
    required Iterable<ReporteComunidad> existentes,
    required TipoReporte tipo,
    String? idArista,
    String? idLugar,
    required DateTime ahora,
  }) {
    if (idArista == null && idLugar == null) return null;
    for (final r in existentes) {
      if (r.tipo != tipo || !r.estaVigente(ahora)) continue;
      if (ahora.difference(r.creadoEn) > ventanaDuplicado) continue;
      final mismoLugar = idLugar != null && r.idLugar == idLugar;
      final mismoTramo = idLugar == null && idArista != null && r.idAristaAfectada == idArista;
      if (mismoLugar || mismoTramo) return r;
    }
    return null;
  }

  /// Tiempo que le queda de vida al [reporte]; `Duration.zero` si ya no está
  /// vigente.
  static Duration tiempoRestante(ReporteComunidad reporte, DateTime ahora) {
    if (!reporte.estaVigente(ahora)) return Duration.zero;
    return reporte.expiraEn.difference(ahora);
  }
}
