import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:pontimaps_app/domain/services/moderation_service.dart';
import 'package:pontimaps_app/models/reporte_comunidad.dart';

/// Reloj inyectable: las pruebas lo adelantan para comprobar la expiración
/// exacta a los 60 minutos.
typedef Reloj = DateTime Function();

/// Resultado de publicar un reporte.
class ResultadoPublicar {
  const ResultadoPublicar(this.resultado, {this.reporte, this.duplicado});

  final ResultadoPublicacion resultado;

  /// El reporte publicado (vista pública, sin autor).
  final ReporteComunidad? reporte;

  /// Con [ResultadoPublicacion.duplicado]: el reporte igual que ya existía.
  final ReporteComunidad? duplicado;

  bool get publicado => resultado == ResultadoPublicacion.publicado;
}

/// Almacén de reportes colaborativos (módulo `reports_service`).
///
/// Anonimato (RF-REP-07): todo lo que sale de aquí es una
/// vista pública **sin `authorHash` ni `uid`**. El hash solo entra como dato de
/// publicación y de voto, y se queda dentro del repositorio.
abstract class ReportsRepository {
  /// Reportes vigentes ahora: filtrados por `expiraEn` y por votos negativos
  /// (el cliente es la autoridad; un TTL de servidor solo recoge los vencidos).
  List<ReporteComunidad> vigentes();

  /// Flujo reactivo: emite la lista vigente al suscribirse y en cada cambio.
  Stream<List<ReporteComunidad>> observar();

  /// Vuelve a evaluar la vigencia (el tiempo pasó) y avisa si cambió algo.
  void refrescar();

  Future<ResultadoPublicar> publicar({
    required TipoReporte tipo,
    required LatLng ubicacion,
    required String autorHash,
    String? idArista,
    String? idLugar,
  });

  /// Califica un reporte. Un voto por cuenta y reporte; el autor no vota el suyo.
  Future<ResultadoVoto> calificar({
    required String idReporte,
    required String votanteHash,
    required VotoReporte voto,
  });
}

class _Registro {
  _Registro(this.reporte);

  ReporteComunidad reporte;
  final Set<String> votantes = <String>{};
}

/// Implementación en memoria (modo demostración sin Firebase, RF-REP-09). Crear,
/// votar y expirar a los 60 minutos funcionan sin red y sin lanzar excepciones.
class InMemoryReportsRepository implements ReportsRepository {
  InMemoryReportsRepository({Reloj? reloj}) : _reloj = reloj ?? DateTime.now;

  final Reloj _reloj;
  final Map<String, _Registro> _registros = <String, _Registro>{};
  final Map<String, DateTime> _ultimoReportePorAutor = <String, DateTime>{};
  final StreamController<List<ReporteComunidad>> _cambios =
      StreamController<List<ReporteComunidad>>.broadcast();
  int _contador = 0;

  List<ReporteComunidad> _publicos() {
    final ahora = _reloj();
    return List<ReporteComunidad>.unmodifiable(<ReporteComunidad>[
      for (final r in _registros.values)
        if (r.reporte.estaVigente(ahora)) r.reporte.sinAutor(),
    ]);
  }

  void _notificar() {
    if (!_cambios.isClosed) _cambios.add(_publicos());
  }

  @override
  List<ReporteComunidad> vigentes() => _publicos();

  @override
  Stream<List<ReporteComunidad>> observar() async* {
    yield _publicos();
    yield* _cambios.stream;
  }

  @override
  void refrescar() {
    final ahora = _reloj();
    final antes = _registros.length;
    _registros.removeWhere((_, r) => !r.reporte.estaVigente(ahora));
    // Aunque no se borre nada, quien escucha vuelve a evaluar la vigencia.
    if (antes != _registros.length || _cambios.hasListener) _notificar();
  }

  @override
  Future<ResultadoPublicar> publicar({
    required TipoReporte tipo,
    required LatLng ubicacion,
    required String autorHash,
    String? idArista,
    String? idLugar,
  }) async {
    final ahora = _reloj();
    if (!ModerationService.puedePublicar(
      ultimoReporteEn: _ultimoReportePorAutor[autorHash],
      ahora: ahora,
    )) {
      return const ResultadoPublicar(ResultadoPublicacion.demasiadoPronto);
    }
    final duplicado = ModerationService.buscarDuplicado(
      existentes: _registros.values.map((r) => r.reporte),
      tipo: tipo,
      idArista: idArista,
      idLugar: idLugar,
      ahora: ahora,
    );
    if (duplicado != null) {
      return ResultadoPublicar(
        ResultadoPublicacion.duplicado,
        duplicado: duplicado.sinAutor(),
      );
    }

    _contador++;
    final reporte = ReporteComunidad.nuevo(
      id: 'rep-$_contador',
      tipo: tipo,
      ubicacion: ubicacion,
      ahora: ahora,
      authorHash: autorHash,
      idAristaAfectada: idArista,
      idLugar: idLugar,
    );
    _registros[reporte.id] = _Registro(reporte);
    _ultimoReportePorAutor[autorHash] = ahora;
    _notificar();
    return ResultadoPublicar(
      ResultadoPublicacion.publicado,
      reporte: reporte.sinAutor(),
    );
  }

  @override
  Future<ResultadoVoto> calificar({
    required String idReporte,
    required String votanteHash,
    required VotoReporte voto,
  }) async {
    final registro = _registros[idReporte];
    if (registro == null) return ResultadoVoto.noVigente;

    final calificacion = ModerationService.calificar(
      reporte: registro.reporte,
      votanteHash: votanteHash,
      voto: voto,
      votantesPrevios: registro.votantes,
      ahora: _reloj(),
    );
    if (calificacion.registro) {
      registro.reporte = calificacion.reporte;
      registro.votantes.add(votanteHash);
      _notificar();
    }
    return calificacion.resultado;
  }

  /// Elimina un reporte al instante (acción del administrador). `false` si no existe.
  bool eliminar(String idReporte) {
    final existia = _registros.remove(idReporte) != null;
    if (existia) _notificar();
    return existia;
  }

  /// `authorHash` interno de un reporte: **solo** para la moderación del
  /// administrador ("Bloquear autor"); nunca se muestra ni sale en una vista pública.
  String? hashDeAutor(String idReporte) => _registros[idReporte]?.reporte.authorHash;

  /// Libera el flujo reactivo.
  Future<void> cerrar() => _cambios.close();
}
