import 'package:pontimaps_app/models/negocio_servicio.dart';

/// Estado de apertura de un lugar en un instante.
enum EstadoApertura { abierto, cierraPronto, cerrado }

/// Estado de apertura con los textos listos para mostrar (siempre texto, no
/// solo color: WCAG 1.4.1).
class EstadoHorario {
  const EstadoHorario(this.estado, this.etiqueta, this.detalle);

  final EstadoApertura estado;

  /// «Abierto», «Cierra pronto» o «Cerrado».
  final String etiqueta;

  /// «Cierra a las 21:00», «Cierra en 12 min» o «Abre a las 06:00».
  final String detalle;

  bool get estaAbierto => estado != EstadoApertura.cerrado;
}

/// Desfase fijo de Colombia respecto a UTC (no hay horario de verano).
const Duration desfaseBogota = Duration(hours: 5);

/// Umbral para avisar «Cierra pronto».
const Duration umbralCierraPronto = Duration(minutes: 30);

/// Hora de pared de `America/Bogota` para el instante [instante], como un
/// `DateTime` en UTC cuyos campos (hora, día, día de la semana) son los de
/// Bogotá. Funciona igual sin importar la zona horaria del dispositivo.
DateTime horaBogota(DateTime instante) => instante.toUtc().subtract(desfaseBogota);

/// Calcula si un lugar con horario [apertura]–[cierre] (`HH:mm`) está abierto
/// en [ahora], en hora de Bogotá (RF-DIR-03).
///
/// * La apertura se incluye y el cierre se excluye.
/// * Si `cierre <= apertura` el horario cruza la medianoche (`10:00–00:00`).
/// * `apertura == cierre` es 24 horas: siempre abierto.
/// * «Cierra pronto» cuando faltan menos de 30 minutos para cerrar.
EstadoHorario calcularEstadoHorario({
  required String apertura,
  required String cierre,
  required DateTime ahora,
  Set<int> dias = NegocioServicio.todosLosDias,
}) {
  final local = horaBogota(ahora);
  final minutoActual = local.hour * 60 + local.minute;
  final minutosApertura = NegocioServicio.minutosDesdeMedianoche(apertura);
  final minutosCierre = NegocioServicio.minutosDesdeMedianoche(cierre);

  if (minutosApertura == minutosCierre) {
    return const EstadoHorario(EstadoApertura.abierto, 'Abierto', 'Abierto las 24 horas');
  }

  final cruzaMedianoche = minutosCierre < minutosApertura;
  final enHorario = cruzaMedianoche
      ? (minutoActual >= minutosApertura || minutoActual < minutosCierre)
      : (minutoActual >= minutosApertura && minutoActual < minutosCierre);

  // La madrugada de un horario que cruza la medianoche pertenece al día anterior.
  final diaDelHorario = cruzaMedianoche && minutoActual < minutosCierre
      ? (local.weekday == DateTime.monday ? DateTime.sunday : local.weekday - 1)
      : local.weekday;
  final abre = dias.contains(diaDelHorario);

  if (!enHorario || !abre) {
    return EstadoHorario(
      EstadoApertura.cerrado,
      'Cerrado',
      _cuandoAbre(apertura, minutoActual, minutosApertura, local.weekday, dias),
    );
  }

  var faltan = minutosCierre - minutoActual;
  if (faltan <= 0) faltan += 24 * 60;
  if (faltan < umbralCierraPronto.inMinutes) {
    return EstadoHorario(EstadoApertura.cierraPronto, 'Cierra pronto', 'Cierra en $faltan min');
  }
  return EstadoHorario(EstadoApertura.abierto, 'Abierto', 'Cierra a las $cierre');
}

/// «Abre a las 08:00», «Abre mañana a las 08:00» o «Abre el lunes a las 08:00».
String _cuandoAbre(String apertura, int minutoActual, int minutosApertura, int diaHoy, Set<int> dias) {
  const nombres = <String>['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  if (dias.contains(diaHoy) && minutoActual < minutosApertura) return 'Abre a las $apertura';
  for (var i = 1; i <= 7; i++) {
    final dia = (diaHoy - 1 + i) % 7 + 1;
    if (!dias.contains(dia)) continue;
    return i == 1 ? 'Abre mañana a las $apertura' : 'Abre el ${nombres[dia - 1]} a las $apertura';
  }
  return 'Sin horario';
}

/// Estado de apertura de un [negocio] (ver [calcularEstadoHorario]).
EstadoHorario estadoDeNegocio(NegocioServicio negocio, DateTime ahora) => calcularEstadoHorario(
      apertura: negocio.horaApertura,
      cierre: negocio.horaCierre,
      ahora: ahora,
      dias: negocio.diasAbierto,
    );
