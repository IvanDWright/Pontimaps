/// Rutas de PontiMaps.
abstract final class Rutas {
  static const String splash = '/';
  static const String permiso = '/permiso';
  static const String mapa = '/mapa';
  static const String horario = '/horario';
  static const String admin = '/admin';

  /// Puerta de entrada (S02), inicio de sesión (S05), registro (S03) y espera de
  /// verificación del correo (S04).
  static const String acceso = '/acceso';
  static const String login = '/acceso/login';
  static const String registro = '/acceso/registro';
  static const String verificar = '/acceso/verificar';

  /// Pantalla de diagnóstico de la base cartográfica (no forma parte del flujo).
  static const String estado = '/estado';
}
