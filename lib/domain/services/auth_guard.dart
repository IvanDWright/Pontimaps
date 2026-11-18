import 'package:pontimaps_app/models/horario_usuario.dart';

/// Acciones de **escritura** que el Auth Guard protege (USER_PATHS §1.3).
enum AccionProtegida {
  crearReporte,
  calificarReporte,
  reportarFila,
  guardarHorario,
  miProximaClase,
}

/// Qué debe pasar cuando se intenta una [AccionProtegida].
enum ResultadoGuard {
  /// Cuenta institucional verificada y activa: la acción continúa.
  permitido,

  /// Visitante, sin sesión o bloqueado: modal «Necesitas una cuenta
  /// institucional verificada» (S10).
  requiereCuenta,

  /// Cuenta institucional sin verificar: modal «Verifica tu correo para
  /// continuar» (S07).
  requiereVerificacion,
}

/// Auth Guard como función pura (`AuthState` × acción protegida).
///
/// La UI solo lo usa para decidir qué mostrar; la autoridad final son las
/// *Firestore Security Rules*. Un usuario bloqueado queda
/// degradado a visitante.
ResultadoGuard evaluarAccion(AuthState estado, AccionProtegida accion) {
  switch (estado) {
    case AuthState.institucionalVerificado:
      return ResultadoGuard.permitido;
    case AuthState.institucionalNoVerificado:
      return ResultadoGuard.requiereVerificacion;
    case AuthState.visitante:
    case AuthState.sinSesion:
    case AuthState.bloqueado:
      return ResultadoGuard.requiereCuenta;
  }
}

/// Atajo: evalúa la acción para el [perfil] actual.
ResultadoGuard evaluarAccionDePerfil(UsuarioPerfil perfil, AccionProtegida accion) =>
    evaluarAccion(perfil.authState, accion);
