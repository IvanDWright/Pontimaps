import 'package:pontimaps_app/domain/services/opening_hours.dart';
import 'package:pontimaps_app/models/horario_usuario.dart';

/// La próxima clase del usuario con el momento exacto en que empieza.
class ProximaClase {
  const ProximaClase({required this.bloque, required this.inicio, required this.ahora});

  final BloqueHorario bloque;

  /// Inicio de la clase en hora de Bogotá (campos de pared, en UTC).
  final DateTime inicio;

  /// «Ahora» en hora de Bogotá, con el que se calculó.
  final DateTime ahora;

  /// Minutos que faltan para que empiece; negativo si ya empezó.
  int get minutosParaInicio => inicio.difference(ahora).inMinutes;

  bool get yaEmpezo => inicio.isBefore(ahora);

  static const List<String> _dias = <String>[
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  /// Nombre del día de la semana (1 = lunes … 7 = domingo).
  static String nombreDia(int diaSemana) => _dias[diaSemana - 1];

  /// «hoy», «mañana» o el nombre del día (E2-04).
  String get cuando {
    final hoy = DateTime.utc(ahora.year, ahora.month, ahora.day);
    final dia = DateTime.utc(inicio.year, inicio.month, inicio.day);
    final diferencia = dia.difference(hoy).inDays;
    if (diferencia == 0) return 'hoy';
    if (diferencia == 1) return 'mañana';
    return nombreDia(bloque.diaSemana);
  }

  /// «Tu clase empezó hace 4 min», «Empieza en 25 min» o «Empieza mañana».
  String get estado {
    if (yaEmpezo) {
      final hace = -minutosParaInicio;
      return 'Tu clase empezó hace $hace min';
    }
    if (cuando == 'hoy') return 'Empieza en ${minutosParaInicio < 1 ? 'menos de 1' : minutosParaInicio} min';
    return 'Empieza $cuando';
  }
}

/// Busca la próxima clase de [horario] (RF-HOR-06): la primera cuyo inicio es
/// `>= ahora - 10 min`, mirando hasta 7 días adelante. `null` si no hay clases.
///
/// [ahora] puede venir en cualquier zona: se convierte a hora de Bogotá para
/// comparar con los horarios, que están en hora de pared de Bogotá.
ProximaClase? calcularProximaClase(
  UsuarioPerfil perfil,
  List<BloqueHorario> horario,
  DateTime ahora, {
  Duration tolerancia = const Duration(minutes: 10),
}) {
  final enBogota = horaBogota(ahora);
  final bloque = perfil.obtenerProximaClase(horario, enBogota, tolerancia: tolerancia);
  if (bloque == null) return null;

  final limite = enBogota.subtract(tolerancia);
  for (var desplazamiento = -1; desplazamiento <= 7; desplazamiento++) {
    final dia = DateTime.utc(enBogota.year, enBogota.month, enBogota.day + desplazamiento);
    if (dia.weekday != bloque.diaSemana) continue;
    final inicio = bloque.inicioEn(dia);
    if (inicio.isBefore(limite)) continue;
    return ProximaClase(bloque: bloque, inicio: inicio, ahora: enBogota);
  }
  return null;
}
