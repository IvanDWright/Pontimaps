import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Prefijo fijo (versionado) del `authorHash`. Cambiarlo invalida todos los
/// hashes existentes: no lo modifiques sin migrar los datos.
const String _prefijoAuthorHash = 'pontimaps:author:v1:';

final RegExp _formatoAuthorHash = RegExp(r'^[0-9a-f]{64}$');

/// Seudónimo estable de una cuenta para moderar reportes: SHA-256 (hex, 64
/// caracteres) de `"pontimaps:author:v1:<uid>"`.
///
/// **Qué es y qué no es**
/// * Es **seudonimización**, no anonimización: quien conozca los `uid` (el
///   administrador, que ve la lista de usuarios) puede recalcular el hash y
///   resolver a qué cuenta pertenece. Por eso sigue siendo un dato personal
///   bajo la Ley 1581 y debe quedar fuera de la vista de los demás usuarios.
/// * Es irreversible: del hash no se obtiene el `uid`.
/// * No contiene ni permite reconstruir coordenadas ni recorridos.
///
/// Lanza [ArgumentError] si [uid] está vacío.
String calcularAuthorHash(String uid) {
  if (uid.isEmpty) {
    throw ArgumentError.value(uid, 'uid', 'No puede estar vacío');
  }
  return sha256.convert(utf8.encode('$_prefijoAuthorHash$uid')).toString();
}

/// `true` si [valor] tiene la forma de un `authorHash` (64 hex en minúscula).
bool esAuthorHashValido(String valor) => _formatoAuthorHash.hasMatch(valor);
