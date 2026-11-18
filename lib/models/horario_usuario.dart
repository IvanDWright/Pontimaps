import 'package:pontimaps_app/core/utils/author_hash.dart';
import 'package:pontimaps_app/core/utils/colecciones.dart';

/// Rol del usuario dentro de la app.
///
/// * `estudiante`, `profesor` y `administrativo` se eligen al registrarse
///   (informativos en el MVP).
/// * `admin` **nunca** se elige desde la app: lo asigna el equipo editando el
///   documento del usuario en la consola de Firebase (ver
///   [UsuarioPerfil.registro], que lo rechaza).
/// * `invitado` es el visitante sin cuenta.
enum RolUsuario { estudiante, profesor, administrativo, admin, invitado }

/// Estado de una cuenta institucional. Solo un administrador puede cambiarlo.
enum EstadoCuenta { activo, bloqueado }

/// Estado de sesión que evalúa el *Auth Guard* antes de cualquier flujo.
enum AuthState {
  /// No hay sesión ni modo visitante elegido.
  sinSesion,

  /// Modo visitante: solo lectura, sin cuenta ni sesión en la nube.
  visitante,

  /// Cuenta registrada pero con `emailVerified == false`: solo lectura hasta
  /// verificar el correo con el enlace de Firebase.
  institucionalNoVerificado,

  /// Cuenta activa y con correo verificado: acceso completo.
  institucionalVerificado,

  /// Cuenta con `estado == bloqueado`: pierde todo permiso de escritura y la
  /// app la degrada a `visitante`.
  bloqueado,
}

/// Clase del horario académico (un bloque semanal recurrente).
///
/// `diaSemana` sigue `DateTime.weekday`: 1 = lunes ... 7 = domingo.
/// `horaInicio` y `horaFin` son **minutos desde la medianoche** (se evita
/// `TimeOfDay` para no depender de Flutter): 8:30 -> 510.
///
/// Invariantes: `1 <= diaSemana <= 7`; `0 <= horaInicio < horaFin <= 1440`.
class BloqueHorario {
  const BloqueHorario({
    required this.id,
    required this.materia,
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFin,
    required this.idEdificio,
    required this.codigoSalon,
  })  : assert(id != ''),
        assert(materia != ''),
        assert(diaSemana >= 1 && diaSemana <= 7),
        assert(horaInicio >= 0 && horaInicio < 1440),
        assert(horaFin > horaInicio && horaFin <= 1440),
        assert(idEdificio != ''),
        assert(codigoSalon != '');

  final String id;
  final String materia;
  final int diaSemana;
  final int horaInicio;
  final int horaFin;
  final String idEdificio;
  final String codigoSalon;

  /// Convierte hora y minuto a minutos desde la medianoche.
  static int minutos(int hora, int minuto) => hora * 60 + minuto;

  /// Formatea minutos desde la medianoche como `"HH:mm"`.
  static String formatoHora(int minutosDesdeMedianoche) {
    final h = (minutosDesdeMedianoche ~/ 60).toString().padLeft(2, '0');
    final m = (minutosDesdeMedianoche % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Instante de inicio de este bloque en el día calendario de [fecha]
  /// (UTC si [fecha] es UTC; local en caso contrario).
  DateTime inicioEn(DateTime fecha) {
    final h = horaInicio ~/ 60;
    final m = horaInicio % 60;
    return fecha.isUtc
        ? DateTime.utc(fecha.year, fecha.month, fecha.day, h, m)
        : DateTime(fecha.year, fecha.month, fecha.day, h, m);
  }

  BloqueHorario copyWith({
    String? id,
    String? materia,
    int? diaSemana,
    int? horaInicio,
    int? horaFin,
    String? idEdificio,
    String? codigoSalon,
  }) {
    return BloqueHorario(
      id: id ?? this.id,
      materia: materia ?? this.materia,
      diaSemana: diaSemana ?? this.diaSemana,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFin: horaFin ?? this.horaFin,
      idEdificio: idEdificio ?? this.idEdificio,
      codigoSalon: codigoSalon ?? this.codigoSalon,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BloqueHorario &&
          other.id == id &&
          other.materia == materia &&
          other.diaSemana == diaSemana &&
          other.horaInicio == horaInicio &&
          other.horaFin == horaFin &&
          other.idEdificio == idEdificio &&
          other.codigoSalon == codigoSalon;

  @override
  int get hashCode => Object.hash(
        id,
        materia,
        diaSemana,
        horaInicio,
        horaFin,
        idEdificio,
        codigoSalon,
      );

  @override
  String toString() =>
      'BloqueHorario($materia, día $diaSemana ${formatoHora(horaInicio)}-${formatoHora(horaFin)})';
}

/// Perfil de usuario de PontiMaps: quién está usando la app y qué puede hacer.
///
/// **Privacidad (Ley 1581 de 2012):** no contiene posiciones ni historial de
/// posiciones. Solo identidad mínima, rol, estado y consentimientos.
/// `toString` no imprime correo ni uid.
///
/// **Visitante:** `rol == invitado` no tiene `uid` ni correo, porque no existe
/// sesión en la nube (no se crea ningún usuario en Firebase Auth).
///
/// **Invariantes**
/// 1. `invitado` ⇔ sin `uid`, sin correo, sin correo verificado y sin opt-in.
///    Cualquier otro rol exige `uid` no vacío y un correo `@javeriana.edu.co`
///    (sin distinguir mayúsculas).
/// 2. `compartirUbicacionOptIn` (por defecto `false`; función de Fase 2) solo
///    puede ser `true` si el correo está verificado, la cuenta está `activa` y
///    el consentimiento de la Ley 1581 fue aceptado.
///
/// **Permisos derivados:** solo escribe quien cumple [puedeEscribir]
/// (cuenta institucional + `emailVerified == true` + `estado == activo`).
///
/// Los `assert` no existen en release: para datos externos usa las fábricas
/// ([UsuarioPerfil.registro], [UsuarioPerfil.institucional],
/// [UsuarioPerfil.invitado]), que validan siempre y lanzan [ArgumentError].
class UsuarioPerfil {
  UsuarioPerfil({
    required this.rol,
    this.uid,
    this.correoInstitucional,
    this.emailVerified = false,
    this.estado = EstadoCuenta.activo,
    this.compartirUbicacionOptIn = false,
    this.consentimientoLey1581Aceptado = false,
  })  : assert(
          rol == RolUsuario.invitado
              ? (uid == null &&
                  correoInstitucional == null &&
                  !emailVerified &&
                  !compartirUbicacionOptIn)
              : (uid != null &&
                  uid != '' &&
                  correoInstitucional != null &&
                  esCorreoInstitucional(correoInstitucional)),
          'Invitado sin uid/correo; los demás roles con uid y correo @javeriana.edu.co',
        ),
        assert(
          !compartirUbicacionOptIn ||
              (emailVerified &&
                  estado == EstadoCuenta.activo &&
                  consentimientoLey1581Aceptado),
          'Compartir ubicación exige correo verificado, cuenta activa y consentimiento',
        );

  /// Alta desde la pantalla de registro. El rol es el **tipo de usuario** que
  /// elige la persona; `admin` e `invitado` se rechazan siempre: un
  /// administrador nunca se crea desde la app. El correo nace sin verificar.
  factory UsuarioPerfil.registro({
    required String uid,
    required String correoInstitucional,
    required RolUsuario tipo,
    bool consentimientoLey1581Aceptado = false,
  }) {
    if (tipo != RolUsuario.estudiante &&
        tipo != RolUsuario.profesor &&
        tipo != RolUsuario.administrativo) {
      throw ArgumentError.value(
        tipo,
        'tipo',
        'Solo estudiante, profesor o administrativo pueden registrarse; '
            'admin no se puede elegir desde la app',
      );
    }
    return UsuarioPerfil.institucional(
      uid: uid,
      correoInstitucional: correoInstitucional,
      rol: tipo,
      consentimientoLey1581Aceptado: consentimientoLey1581Aceptado,
    );
  }

  /// Reconstruye una cuenta institucional ya existente (p. ej. desde
  /// Firestore + Firebase Auth). Acepta `admin` porque ese rol viene del
  /// servidor, no del usuario. Valida siempre (no solo en debug).
  factory UsuarioPerfil.institucional({
    required String uid,
    required String correoInstitucional,
    required RolUsuario rol,
    bool emailVerified = false,
    EstadoCuenta estado = EstadoCuenta.activo,
    bool compartirUbicacionOptIn = false,
    bool consentimientoLey1581Aceptado = false,
  }) {
    if (uid.isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'No puede estar vacío');
    }
    if (rol == RolUsuario.invitado) {
      throw ArgumentError.value(rol, 'rol', 'Use UsuarioPerfil.invitado');
    }
    if (!esCorreoInstitucional(correoInstitucional)) {
      throw ArgumentError.value(
        correoInstitucional,
        'correoInstitucional',
        'Debe terminar en @$dominioInstitucional',
      );
    }
    if (compartirUbicacionOptIn &&
        !(emailVerified &&
            estado == EstadoCuenta.activo &&
            consentimientoLey1581Aceptado)) {
      throw ArgumentError(
        'Compartir ubicación exige correo verificado, cuenta activa y consentimiento',
      );
    }
    return UsuarioPerfil(
      uid: uid,
      rol: rol,
      correoInstitucional: correoInstitucional.trim().toLowerCase(),
      emailVerified: emailVerified,
      estado: estado,
      compartirUbicacionOptIn: compartirUbicacionOptIn,
      consentimientoLey1581Aceptado: consentimientoLey1581Aceptado,
    );
  }

  /// Visitante del campus: sin cuenta, sin sesión en la nube, solo lectura.
  factory UsuarioPerfil.invitado({
    bool consentimientoLey1581Aceptado = false,
  }) {
    return UsuarioPerfil(
      rol: RolUsuario.invitado,
      consentimientoLey1581Aceptado: consentimientoLey1581Aceptado,
    );
  }

  static const String dominioInstitucional = 'javeriana.edu.co';

  /// `null` solo para el visitante.
  final String? uid;
  final RolUsuario rol;
  final String? correoInstitucional;

  /// Refleja `User.emailVerified` de Firebase Auth.
  final bool emailVerified;
  final EstadoCuenta estado;

  /// Solo Fase 2. Apagado por defecto.
  final bool compartirUbicacionOptIn;
  final bool consentimientoLey1581Aceptado;

  bool get esInvitado => rol == RolUsuario.invitado;

  /// `true` solo si puede ejecutar acciones de escritura (crear o calificar
  /// reportes, guardar horario, compartir ubicación en Fase 2): cuenta
  /// institucional, correo verificado y cuenta activa.
  bool get puedeEscribir =>
      !esInvitado && emailVerified && estado == EstadoCuenta.activo;

  /// `true` solo para un administrador **activo y verificado**.
  bool get esAdministrador => rol == RolUsuario.admin && puedeEscribir;

  /// Estado que usa el *Auth Guard*. (`sinSesion` es la ausencia de perfil:
  /// ver [authStateDe].)
  AuthState get authState {
    if (esInvitado) return AuthState.visitante;
    if (estado == EstadoCuenta.bloqueado) return AuthState.bloqueado;
    if (!emailVerified) return AuthState.institucionalNoVerificado;
    return AuthState.institucionalVerificado;
  }

  /// Seudónimo de moderación de esta cuenta (ver [calcularAuthorHash]), o
  /// `null` para el visitante. Es lo único que se asocia a un reporte; nunca
  /// se muestra a otros usuarios.
  String? get authorHash {
    final id = uid;
    return id == null ? null : calcularAuthorHash(id);
  }

  /// `true` si [correo] tiene la forma `usuario@javeriana.edu.co`
  /// (sin distinguir mayúsculas, con parte local no vacía y sin espacios).
  static bool esCorreoInstitucional(String correo) {
    final c = correo.trim().toLowerCase();
    final sufijo = '@$dominioInstitucional';
    if (!c.endsWith(sufijo)) return false;
    final local = c.substring(0, c.length - sufijo.length);
    return local.isNotEmpty && !local.contains('@') && !local.contains(' ');
  }

  /// Próxima clase de [horario] a partir de [ahora], o `null` si no hay.
  ///
  /// Reglas (REQUIREMENTS RF-HOR-06):
  /// * Se considera "próxima" la clase de inicio más cercano que no haya
  ///   empezado hace más de [tolerancia] (por defecto 10 min): si llegas 5
  ///   minutos tarde, la clase en curso todavía es tu próxima clase.
  /// * Se busca hasta 7 días hacia adelante (el mismo día de la semana de la
  ///   próxima semana cuenta).
  /// * Si dos bloques empiezan a la vez, gana el de `id` menor (determinista).
  ///
  /// Solo calcula; guardar o editar el horario es una escritura protegida por
  /// [puedeEscribir]. Complejidad O(|horario| · 9).
  BloqueHorario? obtenerProximaClase(
    List<BloqueHorario> horario,
    DateTime ahora, {
    Duration tolerancia = const Duration(minutes: 10),
  }) {
    final limite = ahora.subtract(tolerancia);
    BloqueHorario? mejor;
    DateTime? mejorInicio;

    for (final bloque in horario) {
      // -1 cubre una clase de ayer que empezó justo antes de medianoche.
      for (var desplazamiento = -1; desplazamiento <= 7; desplazamiento++) {
        final dia = ahora.isUtc
            ? DateTime.utc(ahora.year, ahora.month, ahora.day + desplazamiento)
            : DateTime(ahora.year, ahora.month, ahora.day + desplazamiento);
        if (dia.weekday != bloque.diaSemana) continue;
        final inicio = bloque.inicioEn(dia);
        if (inicio.isBefore(limite)) continue;
        final esMejor = mejorInicio == null ||
            inicio.isBefore(mejorInicio) ||
            (inicio.isAtSameMomentAs(mejorInicio) &&
                bloque.id.compareTo(mejor!.id) < 0);
        if (esMejor) {
          mejor = bloque;
          mejorInicio = inicio;
        }
        break; // la primera ocurrencia válida de este bloque es la más cercana
      }
    }
    return mejor;
  }

  /// Copia con cambios. El opt-in de ubicación se apaga solo si el resultado
  /// ya no cumple sus requisitos (consentimiento revocado, correo sin
  /// verificar o cuenta bloqueada): bloquear o revocar nunca deja una
  /// ubicación compartida activa.
  UsuarioPerfil copyWith({
    Object? uid = sinCambio,
    RolUsuario? rol,
    Object? correoInstitucional = sinCambio,
    bool? emailVerified,
    EstadoCuenta? estado,
    bool? compartirUbicacionOptIn,
    bool? consentimientoLey1581Aceptado,
  }) {
    final verificado = emailVerified ?? this.emailVerified;
    final nuevoEstado = estado ?? this.estado;
    final consentimiento =
        consentimientoLey1581Aceptado ?? this.consentimientoLey1581Aceptado;
    final optIn = (compartirUbicacionOptIn ?? this.compartirUbicacionOptIn) &&
        verificado &&
        nuevoEstado == EstadoCuenta.activo &&
        consentimiento;
    return UsuarioPerfil(
      uid: identical(uid, sinCambio) ? this.uid : uid as String?,
      rol: rol ?? this.rol,
      correoInstitucional: identical(correoInstitucional, sinCambio)
          ? this.correoInstitucional
          : correoInstitucional as String?,
      emailVerified: verificado,
      estado: nuevoEstado,
      compartirUbicacionOptIn: optIn,
      consentimientoLey1581Aceptado: consentimiento,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UsuarioPerfil &&
          other.uid == uid &&
          other.rol == rol &&
          other.correoInstitucional == correoInstitucional &&
          other.emailVerified == emailVerified &&
          other.estado == estado &&
          other.compartirUbicacionOptIn == compartirUbicacionOptIn &&
          other.consentimientoLey1581Aceptado == consentimientoLey1581Aceptado;

  @override
  int get hashCode => Object.hash(
        uid,
        rol,
        correoInstitucional,
        emailVerified,
        estado,
        compartirUbicacionOptIn,
        consentimientoLey1581Aceptado,
      );

  // No imprime correo ni uid: evita filtrar datos personales en logs.
  @override
  String toString() => 'UsuarioPerfil(${rol.name}, ${estado.name})';
}

/// [AuthState] de una sesión: sin perfil no hay sesión.
AuthState authStateDe(UsuarioPerfil? perfil) =>
    perfil?.authState ?? AuthState.sinSesion;
