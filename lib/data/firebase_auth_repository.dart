import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pontimaps_app/core/utils/author_hash.dart';
import 'package:pontimaps_app/data/auth_repository.dart';
import 'package:pontimaps_app/data/consent_repository.dart';
import 'package:pontimaps_app/models/horario_usuario.dart';

/// Autenticación real con Firebase Auth + el perfil `users/{uid}` de Firestore
/// (plan Spark, sin Cloud Functions).
///
/// * Registro con `createUserWithEmailAndPassword` y envío del **enlace nativo**
///   de verificación (`sendEmailVerification()`).
/// * El rol y el estado salen del documento `users/{uid}`. `rol: admin` **solo**
///   se asigna a mano en la consola de Firebase; ningún cliente puede cambiarlo
///   (lo impiden `firestore.rules`).
/// * Un administrador que bloquea la cuenta cambia `estado`; este repositorio
///   escucha el documento y la app degrada a esa persona a modo Visitante.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance {
    _suscripcionAuth = _auth.userChanges().listen(_alCambiarUsuario);
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final StreamController<CuentaAuth?> _cambios = StreamController<CuentaAuth?>.broadcast();
  StreamSubscription<User?>? _suscripcionAuth;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _suscripcionPerfil;
  CuentaAuth? _actual;

  @override
  CuentaAuth? get actual => _actual;

  @override
  Stream<CuentaAuth?> cambios() async* {
    yield _actual;
    yield* _cambios.stream;
  }

  void _emitir(CuentaAuth? cuenta) {
    _actual = cuenta;
    if (!_cambios.isClosed) _cambios.add(cuenta);
  }

  static RolUsuario _rolDe(Object? valor) {
    for (final r in RolUsuario.values) {
      if (r.name == valor && r != RolUsuario.invitado) return r;
    }
    return RolUsuario.estudiante;
  }

  static EstadoCuenta _estadoDe(Object? valor) =>
      valor == 'bloqueado' ? EstadoCuenta.bloqueado : EstadoCuenta.activo;

  CuentaAuth _construir(User usuario, Map<String, dynamic>? perfil) => CuentaAuth(
        uid: usuario.uid,
        correo: (usuario.email ?? '').toLowerCase(),
        rol: _rolDe(perfil?['rol']),
        emailVerified: usuario.emailVerified,
        estado: _estadoDe(perfil?['estado']),
      );

  void _alCambiarUsuario(User? usuario) {
    _suscripcionPerfil?.cancel();
    _suscripcionPerfil = null;
    if (usuario == null) {
      _emitir(null);
      return;
    }
    // Hasta que llegue el perfil, la cuenta es de estudiante activo (el mínimo).
    _emitir(_construir(usuario, null));
    _suscripcionPerfil = _db.collection('users').doc(usuario.uid).snapshots().listen(
      (doc) => _emitir(_construir(usuario, doc.data())),
      onError: (Object _) {
        // Sin acceso al perfil (p. ej. sin red): se conserva la última cuenta.
      },
    );
  }

  static AuthException _traducir(Object error) {
    if (error is AuthException) return error;
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return const AuthException(ErrorAuth.correoYaRegistrado);
        case 'weak-password':
          return const AuthException(ErrorAuth.contrasenaDebil);
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
        case 'invalid-email':
        case 'user-disabled':
          return const AuthException(ErrorAuth.credencialesInvalidas);
        case 'too-many-requests':
          return const AuthException(ErrorAuth.demasiadosIntentos);
        case 'network-request-failed':
          return const AuthException(ErrorAuth.sinConexion);
      }
    }
    return const AuthException(ErrorAuth.desconocido);
  }

  @override
  Future<void> registrar({
    required String correo,
    required String contrasena,
    required RolUsuario tipo,
  }) async {
    validarRegistro(correo: correo, contrasena: contrasena, tipo: tipo);
    try {
      final credencial = await _auth.createUserWithEmailAndPassword(
        email: correo.trim().toLowerCase(),
        password: contrasena,
      );
      final usuario = credencial.user;
      if (usuario == null) throw const AuthException(ErrorAuth.desconocido);
      // Perfil: el cliente solo puede crearlo como no administrador y activo; las
      // reglas lo exigen. `authorHash` es el SHA-256 irreversible del uid.
      await _db.collection('users').doc(usuario.uid).set(<String, Object?>{
        'rol': tipo.name,
        'estado': 'activo',
        'authorHash': calcularAuthorHash(usuario.uid),
        'createdAt': FieldValue.serverTimestamp(),
        'consent': <String, Object?>{
          'version': kConsentVersion,
          'acceptedAt': FieldValue.serverTimestamp(),
        },
      });
      // Enlace de verificación nativo de Firebase Auth (sin SMTP ni funciones).
      await usuario.sendEmailVerification();
    } catch (e) {
      throw _traducir(e);
    }
  }

  @override
  Future<void> iniciarSesion({required String correo, required String contrasena}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: correo.trim().toLowerCase(),
        password: contrasena,
      );
    } catch (e) {
      throw _traducir(e);
    }
  }

  @override
  Future<void> cerrarSesion() => _auth.signOut();

  @override
  Future<void> reenviarVerificacion() async {
    final usuario = _auth.currentUser;
    if (usuario == null) throw const AuthException(ErrorAuth.sinSesion);
    try {
      await usuario.sendEmailVerification();
    } catch (e) {
      throw _traducir(e);
    }
  }

  @override
  Future<CuentaAuth?> recargar() async {
    final usuario = _auth.currentUser;
    if (usuario == null) return null;
    try {
      await usuario.reload();
      await _auth.currentUser?.getIdToken(true);
      final refrescado = _auth.currentUser;
      if (refrescado == null) return null;
      final doc = await _db.collection('users').doc(refrescado.uid).get();
      final cuenta = _construir(refrescado, doc.data());
      _emitir(cuenta);
      return cuenta;
    } catch (e) {
      throw _traducir(e);
    }
  }

  Future<void> cerrar() async {
    await _suscripcionAuth?.cancel();
    await _suscripcionPerfil?.cancel();
    await _cambios.close();
  }
}
