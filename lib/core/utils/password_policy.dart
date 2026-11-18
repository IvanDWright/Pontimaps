/// Requisitos de la contraseña (USER_PATHS S03).
enum RequisitoContrasena {
  longitudMinima('Al menos 8 caracteres'),
  mayuscula('Una letra mayúscula'),
  minuscula('Una letra minúscula'),
  numero('Un número'),
  simbolo('Un símbolo especial (!, @, #, ...)'),
  sinEspacios('Sin espacios'),
  sinUsuarioDelCorreo('No contiene tu usuario del correo');

  const RequisitoContrasena(this.texto);

  final String texto;
}

/// Longitud mínima de la contraseña.
const int longitudMinimaContrasena = 8;

/// Parte local de [correo] (lo que va antes de la `@`), en minúsculas.
String usuarioDelCorreo(String correo) {
  final c = correo.trim().toLowerCase();
  final arroba = c.indexOf('@');
  return arroba < 0 ? c : c.substring(0, arroba);
}

/// Requisitos que [contrasena] **cumple** (para la lista ✓/✗ del registro).
///
/// Política: mínimo 8 caracteres, al menos 1 mayúscula, 1 minúscula, 1 número y
/// 1 símbolo especial, sin espacios y sin contener el usuario del correo
/// (si ese usuario tiene 3 o más caracteres).
Set<RequisitoContrasena> requisitosCumplidos(String contrasena, {String correo = ''}) {
  final usuario = usuarioDelCorreo(correo);
  return <RequisitoContrasena>{
    if (contrasena.length >= longitudMinimaContrasena) RequisitoContrasena.longitudMinima,
    if (RegExp(r'[A-ZÁÉÍÓÚÑ]').hasMatch(contrasena)) RequisitoContrasena.mayuscula,
    if (RegExp(r'[a-záéíóúñ]').hasMatch(contrasena)) RequisitoContrasena.minuscula,
    if (RegExp(r'[0-9]').hasMatch(contrasena)) RequisitoContrasena.numero,
    if (RegExp(r'[^A-Za-z0-9ÁÉÍÓÚÑáéíóúñ\s]').hasMatch(contrasena)) RequisitoContrasena.simbolo,
    if (!RegExp(r'\s').hasMatch(contrasena)) RequisitoContrasena.sinEspacios,
    if (usuario.length < 3 || !contrasena.toLowerCase().contains(usuario))
      RequisitoContrasena.sinUsuarioDelCorreo,
  };
}

/// Requisitos que [contrasena] **no** cumple, en el orden de la lista.
List<RequisitoContrasena> requisitosFaltantes(String contrasena, {String correo = ''}) {
  final cumplidos = requisitosCumplidos(contrasena, correo: correo);
  return <RequisitoContrasena>[
    for (final r in RequisitoContrasena.values)
      if (!cumplidos.contains(r)) r,
  ];
}

/// `true` si [contrasena] cumple toda la política.
bool contrasenaValida(String contrasena, {String correo = ''}) =>
    requisitosFaltantes(contrasena, correo: correo).isEmpty;
