import 'package:pontimaps_app/data/reports_repository.dart';
import 'package:pontimaps_app/models/reporte_comunidad.dart';

/// Resultado de una acción de moderación.
enum ResultadoModeracion {
  hecho,
  noEncontrado,

  /// El reporte existe pero no se puede saber quién lo hizo (o esa cuenta no existe).
  autorNoEncontrado,

  /// Quien llama no es administrador. La autoridad real son las reglas de Firestore.
  sinPermiso,
}

/// Moderación de reportes por un administrador (`rol == 'admin'`).
///
/// * **Eliminar reporte:** desaparece de todos los clientes.
/// * **Bloquear autor:** usa el `authorHash` interno (privado) para poner
///   `estado = bloqueado` a esa cuenta; queda degradada a Visitante en solo
///   lectura. La interfaz **nunca** muestra el hash ni la identidad.
abstract class AdminRepository {
  /// Reportes vigentes, en tiempo real, para la lista del panel (sin autor).
  Stream<List<ReporteComunidad>> reportesActivos();

  Future<ResultadoModeracion> eliminarReporte(String idReporte);

  Future<ResultadoModeracion> bloquearAutor(String idReporte);
}

/// Moderación en memoria (modo demostración sin Firebase).
///
/// [esAdmin] se consulta en cada acción: sin rol de administrador no se hace
/// nada. [alBloquearHash] avisa a la sesión para degradar a esa cuenta.
class InMemoryAdminRepository implements AdminRepository {
  const InMemoryAdminRepository({
    required this.reportes,
    required this.esAdmin,
    required this.alBloquearHash,
  });

  final InMemoryReportsRepository reportes;
  final bool Function() esAdmin;
  final void Function(String authorHash) alBloquearHash;

  @override
  Stream<List<ReporteComunidad>> reportesActivos() => reportes.observar();

  @override
  Future<ResultadoModeracion> eliminarReporte(String idReporte) async {
    if (!esAdmin()) return ResultadoModeracion.sinPermiso;
    return reportes.eliminar(idReporte)
        ? ResultadoModeracion.hecho
        : ResultadoModeracion.noEncontrado;
  }

  @override
  Future<ResultadoModeracion> bloquearAutor(String idReporte) async {
    if (!esAdmin()) return ResultadoModeracion.sinPermiso;
    final hash = reportes.hashDeAutor(idReporte);
    if (hash == null) return ResultadoModeracion.noEncontrado;
    alBloquearHash(hash);
    return ResultadoModeracion.hecho;
  }
}
