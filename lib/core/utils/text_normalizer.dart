const Map<String, String> _reemplazos = <String, String>{
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
  'ñ': 'n',
};

final RegExp _espacios = RegExp(r'\s+');

/// Normaliza [texto] para comparaciones tolerantes: minúsculas, sin tildes,
/// sin espacios sobrantes. "  Ed.  José Rafael Arboleda " -> "ed. jose rafael arboleda".
String normalizarTexto(String texto) {
  final buffer = StringBuffer();
  for (final caracter in texto.toLowerCase().split('')) {
    buffer.write(_reemplazos[caracter] ?? caracter);
  }
  return buffer.toString().trim().replaceAll(_espacios, ' ');
}
