/// Centinela para distinguir "no cambiar" de "poner null" en los `copyWith`
/// de campos anulables.
const Object sinCambio = Object();

/// Igualdad elemento a elemento entre dos listas (mismo orden).
bool listasIguales<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
