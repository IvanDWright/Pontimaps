/// Cola de prioridad mínima (montículo binario) para el motor de rutas.
///
/// Dart no incluye una en la biblioteca estándar. `agregar` y `extraerMinimo`
/// cuestan O(log n); `estaVacia` y `longitud` O(1).
class ColaPrioridad<T> {
  ColaPrioridad(this._comparar);

  final int Function(T a, T b) _comparar;
  final List<T> _heap = <T>[];

  bool get estaVacia => _heap.isEmpty;
  int get longitud => _heap.length;

  void agregar(T elemento) {
    _heap.add(elemento);
    _subir(_heap.length - 1);
  }

  /// Extrae y devuelve el menor elemento. Lanza [StateError] si está vacía.
  T extraerMinimo() {
    if (_heap.isEmpty) throw StateError('La cola de prioridad está vacía');
    final minimo = _heap.first;
    final ultimo = _heap.removeLast();
    if (_heap.isNotEmpty) {
      _heap[0] = ultimo;
      _bajar(0);
    }
    return minimo;
  }

  void _subir(int indice) {
    var i = indice;
    while (i > 0) {
      final padre = (i - 1) ~/ 2;
      if (_comparar(_heap[i], _heap[padre]) >= 0) break;
      _intercambiar(i, padre);
      i = padre;
    }
  }

  void _bajar(int indice) {
    var i = indice;
    final n = _heap.length;
    while (true) {
      final izquierdo = 2 * i + 1;
      final derecho = izquierdo + 1;
      var menor = i;
      if (izquierdo < n && _comparar(_heap[izquierdo], _heap[menor]) < 0) {
        menor = izquierdo;
      }
      if (derecho < n && _comparar(_heap[derecho], _heap[menor]) < 0) {
        menor = derecho;
      }
      if (menor == i) break;
      _intercambiar(i, menor);
      i = menor;
    }
  }

  void _intercambiar(int a, int b) {
    final temporal = _heap[a];
    _heap[a] = _heap[b];
    _heap[b] = temporal;
  }
}
