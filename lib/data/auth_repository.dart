import 'dart:async';

import 'package:pontimaps_app/core/utils/password_policy.dart';
import 'package:pontimaps_app/models/horario_usuario.dart';

/// Motivo de un fallo de autenticación (sin revelar si el correo existe).
enum ErrorAuth {
  correoNoInstitucional('Usa tu correo institucional (@javeriana.edu.co).'),
  contrasenaDebil('La contraseña no cumple los requisitos.'),
  correoYaRegistrado('Ese correo ya tiene una cuenta. Inicia sesión.'),
  credencialesInvalidas('Correo o contraseña incorrectos.'),
  demasiadosIntentos('Demasiados intentos. Espera un momento e inténtalo de nuevo.'),
  rolInvalido('Ese tipo de usuario no se puede elegir.'),
  sinConexion('Sin conexión. Revisa tu internet e inténtalo de nuevo.'),
  sinSesion('No hay una sesión iniciada.'),
  desconocido('No pudimos completar la acción. Inténtalo de nuevo.');

  const ErrorAuth(this.mensaje);

  final String mensaje;
}

class AuthException implements Exception {
  const AuthException(this.codigo);

  final ErrorAuth codigo;

  String get mensaje => codigo.mensaje;

  @override
  String toString() => 'AuthException(${codigo.name})';
}

/// Cuenta autenticada: lo que la app necesita para decidir qué puede hacer.
class CuentaAuth {
  const CuentaAuth({
    required this.uid,
    required this.correo,
    required this.rol,
    this.emailVerified = false,
    this.estado = EstadoCuenta.activo,
  });

  final String uid;
  final String correo;
  final RolUsuario rol;
  final bool emailVerified;
  final EstadoCuenta estado;

  CuentaAuth copyWith({bool? emailVerified, EstadoCuenta? estado, RolUsuario? rol}) => CuentaAuth(
        uid: uid,
        correo: correo,
        rol: rol ?? this.rol,
        emailVerified: emailVerified ?? this.emailVerified,
        estado: estado ?? this.estado,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CuentaAuth &&
          other.uid == uid &&
          other.correo == correo &&
          other.rol == rol &&
          other.emailVerified == emailVerified &&
          other.estado == estado;

  @override
  int get hashCode => Object.hash(uid, correo, rol, emailVerified, estado);

  /// Perfil de dominio. Un administrador solo existe si el documento
  /// `users/{uid}` lo dice (asignado a mano en la consola de Firebase).
  UsuarioPerfil toPerfil() => UsuarioPerfil.institucional(
        uid: uid,
        correoInstitucional: correo,
        rol: rol,
        emailVerified: emailVerified,
        estado: estado,
        consentimientoLey1581Aceptado: true,
      );

  /// Correo con el usuario parcialmente oculto (`ju***@javeriana.edu.co`).
  String get correoEnmascarado {
    final usuario = usuarioDelCorreo(correo);
    final resto = correo.substring(usuario.length);
    final visibles = usuario.length <= 2 ? 1 : 2;
    return '${usuario.substring(0, visibles)}***$resto';
  }
}

/// Autenticación institucional (módulo `firebase_backend`).
///
/// * Registro **solo** con `@javeriana.edu.co`, contraseña fuerte y verificación
///   por el **enlace nativo** de Firebase Auth (`sendEmailVerification()`); no hay
///   códigos OTP propios ni Cloud Functions.
/// * El modo **Visitante** no usa este repositorio: no crea usuario ni sesión
///   anónima.
abstract class AuthRepository {
  /// Cuenta actual o `null`.
  CuentaAuth? get actual;

  /// Emite la cuenta al suscribirse y cada vez que cambia (inicio o cierre de
  /// sesión, verificación del correo, bloqueo por un administrador).
  Stream<CuentaAuth?> cambios();

  /// Crea la cuenta, envía el enlace de verificación y deja la sesión iniciada
  /// (sin verificar). [tipo] solo puede ser estudiante, profesor o administrativo.
  Future<void> registrar({
    required String correo,
    required String contrasena,
    required RolUsuario tipo,
  });

  Future<void> iniciarSesion({required String correo, required String contrasena});

  Future<void> cerrarSesion();

  /// Reenvía el enlace de verificación del correo.
  Future<void> reenviarVerificacion();

  /// Vuelve a leer la cuenta (`reload()` y renovar el token) para saber si ya
  /// verificó el correo o si cambió su estado.
  Future<CuentaAuth?> recargar();
}

/// Valida el registro antes de llamar al servidor. Lanza [AuthException].
void validarRegistro({
  required String correo,
  required String contrasena,
  required RolUsuario tipo,
}) {
  if (!UsuarioPerfil.esCorreoInstitucional(correo)) {
    throw const AuthException(ErrorAuth.correoNoInstitucional);
  }
  if (tipo != RolUsuario.estudiante &&
      tipo != RolUsuario.profesor &&
      tipo != RolUsuario.administrativo) {
    throw const AuthException(ErrorAuth.rolInvalido);
  }
  if (!contrasenaValida(contrasena, correo: correo)) {
    throw const AuthException(ErrorAuth.contrasenaDebil);
  }
}

class _CuentaEnMemoria {
  _CuentaEnMemoria(this.cuenta, this.contrasena);

  CuentaAuth cuenta;
  final String contrasena;
}

/// Cuentas de prueba **en memoria** (modo demostración sin Firebase). El enlace
/// de verificación se simula con [simularEnlaceDeVerificacion],
/// un método de depuración que solo existe aquí: con Firebase configurado la
/// verificación real es el enlace del correo.
class InMemoryAuthRepository implements AuthRepository {
  final Map<String, _CuentaEnMemoria> _cuentas = <String, _CuentaEnMemoria>{};
  final StreamController<CuentaAuth?> _cambios = StreamController<CuentaAuth?>.broadcast();
  String? _correoActual;
  int _contador = 0;

  /// Cuántos enlaces de verificación se enviaron (para pruebas y depuración).
  int enlacesEnviados = 0;

  @override
  CuentaAuth? get actual => _correoActual == null ? null : _cuentas[_correoActual]?.cuenta;

  void _emitir() => _cambios.add(actual);

  static String _clave(String correo) => correo.trim().toLowerCase();

  @override
  Stream<CuentaAuth?> cambios() async* {
    yield actual;
    yield* _cambios.stream;
  }

  @override
  Future<void> registrar({
    required String correo,
    required String contrasena,
    required RolUsuario tipo,
  }) async {
    validarRegistro(correo: correo, contrasena: contrasena, tipo: tipo);
    final clave = _clave(correo);
    if (_cuentas.containsKey(clave)) throw const AuthException(ErrorAuth.correoYaRegistrado);
    _contador++;
    _cuentas[clave] = _CuentaEnMemoria(
      CuentaAuth(uid: 'mem-$_contador', correo: clave, rol: tipo),
      contrasena,
    );
    _correoActual = clave;
    enlacesEnviados++;
    _emitir();
  }

  @override
  Future<void> iniciarSesion({required String correo, required String contrasena}) async {
    final clave = _clave(correo);
    final registro = _cuentas[clave];
    // Mismo error para «no existe» y «contraseña incorrecta»: no revela cuentas.
    if (registro == null || registro.contrasena != contrasena) {
      throw const AuthException(ErrorAuth.credencialesInvalidas);
    }
    _correoActual = clave;
    _emitir();
  }

  @override
  Future<void> cerrarSesion() async {
    _correoActual = null;
    _emitir();
  }

  @override
  Future<void> reenviarVerificacion() async {
    if (actual == null) throw const AuthException(ErrorAuth.sinSesion);
    enlacesEnviados++;
  }

  @override
  Future<CuentaAuth?> recargar() async {
    _emitir();
    return actual;
  }

  /// **Solo demostración:** simula que la persona abrió el enlace del correo.
  void simularEnlaceDeVerificacion() {
    final registro = _correoActual == null ? null : _cuentas[_correoActual];
    if (registro == null) return;
    registro.cuenta = registro.cuenta.copyWith(emailVerified: true);
    _emitir();
  }

  /// Cambia el estado de una cuenta (lo que hace un administrador al bloquear).
  void cambiarEstado(String uid, EstadoCuenta estado) {
    for (final registro in _cuentas.values) {
      if (registro.cuenta.uid == uid) {
        registro.cuenta = registro.cuenta.copyWith(estado: estado);
      }
    }
    _emitir();
  }

  Future<void> cerrar() => _cambios.close();
}
