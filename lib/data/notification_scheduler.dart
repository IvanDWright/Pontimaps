import 'package:flutter/foundation.dart';
import 'package:pontimaps_app/domain/services/departure_planner.dart';

/// Programa las alertas de hora de salida (RF-HOR-05).
///
/// La app depende de esta interfaz, no de ningún plugin de notificaciones: así la
/// alerta funciona hoy como aviso dentro de la app y una implementación con
/// notificaciones del sistema (`flutter_local_notifications`) puede añadirse sin
/// tocar la UI.
abstract class NotificationScheduler implements Listenable {
  /// `true` si hay permiso para mostrar notificaciones del sistema.
  Future<bool> permisoConcedido();

  /// Programa (o reprograma) la alerta de [alerta]. Solo hay una alerta activa.
  Future<void> programar(AlertaSalida alerta);

  /// Cancela la alerta activa.
  Future<void> cancelar();

  /// La alerta activa, o `null`.
  AlertaSalida? get activa;
}

/// Alerta como **aviso dentro de la app** (*banner* con «Iniciar ruta»): no
/// necesita permisos y es el respaldo cuando las notificaciones del sistema están
/// desactivadas. Todo vive en memoria; nada se guarda.
class InAppNotificationScheduler extends ChangeNotifier implements NotificationScheduler {
  AlertaSalida? _activa;

  @override
  AlertaSalida? get activa => _activa;

  @override
  Future<bool> permisoConcedido() async => false;

  @override
  Future<void> programar(AlertaSalida alerta) async {
    if (_activa?.id == alerta.id && _activa?.horaSalida == alerta.horaSalida) return;
    _activa = alerta;
    notifyListeners();
  }

  @override
  Future<void> cancelar() async {
    if (_activa == null) return;
    _activa = null;
    notifyListeners();
  }
}
