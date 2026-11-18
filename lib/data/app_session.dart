import 'package:flutter/foundation.dart';
import 'package:pontimaps_app/data/auth_repository.dart';
import 'package:pontimaps_app/models/horario_usuario.dart';

/// Perfiles de demostración del modo sin Firebase (cuentas de prueba en memoria).
/// El selector solo existe en el modo demostración; con
/// Firebase configurado lo reemplaza el inicio de sesión real.
enum PerfilDemo {
  visitante('Visitante'),
  verificado('Institucional Verificado'),

  /// Solo demostración: en producción `rol: admin` se asigna únicamente editando
  /// el documento del usuario en la consola de Firebase.
  administrador('Administrador');

  const PerfilDemo(this.etiqueta);

  final String etiqueta;
}

/// Sesión de la app: quién es la persona y, por tanto, qué puede hacer.
///
/// El [perfil] sale de la **cuenta** autenticada ([usarCuenta]) si hay una; si no,
/// del perfil de demostración (Visitante por defecto). El visitante no tiene `uid`
/// ni correo y no crea nada en la nube (Path 0B). Una cuenta cuyo `authorHash`
/// fue bloqueado queda degradada a solo lectura (Visitante).
class AppSession extends ChangeNotifier {
  AppSession([PerfilDemo inicial = PerfilDemo.visitante]) : _perfilDemo = inicial;

  /// `uid` de la cuenta de prueba verificada (solo existe en memoria).
  static const String uidDemo = 'demo-estudiante-001';

  /// `uid` de la cuenta de prueba de administrador (solo demostración).
  static const String uidAdminDemo = 'demo-admin-001';

  PerfilDemo _perfilDemo;
  CuentaAuth? _cuenta;
  final Set<String> _hashesBloqueados = <String>{};

  PerfilDemo get perfilDemo => _perfilDemo;

  /// Cuenta autenticada (Firebase o en memoria); `null` si no hay sesión.
  CuentaAuth? get cuenta => _cuenta;

  UsuarioPerfil get perfil {
    final base = _perfilBase();
    final hash = base.authorHash;
    if (hash != null && _hashesBloqueados.contains(hash) && base.estado == EstadoCuenta.activo) {
      return UsuarioPerfil.institucional(
        uid: base.uid!,
        correoInstitucional: base.correoInstitucional!,
        rol: base.rol,
        emailVerified: base.emailVerified,
        estado: EstadoCuenta.bloqueado,
        consentimientoLey1581Aceptado: true,
      );
    }
    return base;
  }

  UsuarioPerfil _perfilBase() {
    final cuenta = _cuenta;
    if (cuenta != null) return cuenta.toPerfil();
    switch (_perfilDemo) {
      case PerfilDemo.visitante:
        return UsuarioPerfil.invitado();
      case PerfilDemo.verificado:
        return UsuarioPerfil.institucional(
          uid: uidDemo,
          correoInstitucional: 'demo.estudiante@javeriana.edu.co',
          rol: RolUsuario.estudiante,
          emailVerified: true,
          consentimientoLey1581Aceptado: true,
        );
      case PerfilDemo.administrador:
        return UsuarioPerfil.institucional(
          uid: uidAdminDemo,
          correoInstitucional: 'demo.admin@javeriana.edu.co',
          rol: RolUsuario.admin,
          emailVerified: true,
          consentimientoLey1581Aceptado: true,
        );
    }
  }

  AuthState get authState => perfil.authState;

  void elegir(PerfilDemo nuevo) {
    if (nuevo == _perfilDemo) return;
    _perfilDemo = nuevo;
    notifyListeners();
  }

  /// Fija (o borra, con `null`) la cuenta autenticada.
  void usarCuenta(CuentaAuth? cuenta) {
    if (cuenta == _cuenta) return;
    _cuenta = cuenta;
    notifyListeners();
  }

  /// Degrada a Visitante a la cuenta con ese `authorHash` (modo demostración:
  /// con Firebase el bloqueo llega como cambio de `estado` en `users/{uid}`).
  void bloquearHash(String authorHash) {
    if (_hashesBloqueados.add(authorHash)) notifyListeners();
  }
}
