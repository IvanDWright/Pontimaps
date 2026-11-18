import 'package:flutter/foundation.dart' show setEquals;
import 'package:latlong2/latlong.dart';

/// Categoría de un negocio o servicio del campus.
enum CategoriaServicio {
  cafeteria,
  papeleria,
  atencionEstudiante,
  bienestar,
  comercioAliado,
  biblioteca,
  salud,
}

/// Nivel de congestión / fila reportado.
enum NivelCongestion { baja, media, alta }

/// Cafetería, papelería, punto de atención o comercio aliado del campus.
///
/// Horario: un único intervalo diario `horaApertura`-`horaCierre` en formato
/// `"HH:mm"` (24 h). Limitación conocida: no modela horarios por día de la
/// semana ni festivos (REQUIREMENTS RF-DIR-03 los pide para una iteración
/// posterior).
///
/// Invariantes: `id`, `nombre` e `idEdificioCercano` no vacíos; las horas
/// cumplen `HH:mm` válido.
class NegocioServicio {
  NegocioServicio({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.ubicacion,
    required this.idEdificioCercano,
    required this.horaApertura,
    required this.horaCierre,
    this.piso = 1,
    this.dentroDeEdificio = true,
    this.horarioConfirmado = true,
    this.nivelFilaActual,
    this.diasAbierto = todosLosDias,
  })  : assert(id != '', 'id no puede estar vacío'),
        assert(nombre != '', 'nombre no puede estar vacío'),
        assert(idEdificioCercano != ''),
        assert(esHoraValida(horaApertura), 'horaApertura inválida'),
        assert(esHoraValida(horaCierre), 'horaCierre inválida');

  final String id;
  final String nombre;
  final CategoriaServicio categoria;
  final LatLng ubicacion;
  final String idEdificioCercano;
  final String horaApertura;
  final String horaCierre;

  /// Piso del edificio donde queda el servicio (puede ser negativo: sótano).
  final int piso;

  /// `true` si el servicio queda dentro del edificio [idEdificioCercano]
  /// ("Edificio 18 · Piso 1"); `false` si es una construcción propia cercana a
  /// él ("Cerca del Edificio 18").
  final bool dentroDeEdificio;

  /// `false` si el horario es un valor de reemplazo todavía sin confirmar (la
  /// interfaz debe mostrar "Horario por confirmar").
  final bool horarioConfirmado;

  /// Nivel de fila según reportes vigentes. `null` = "sin datos recientes"
  /// (no es lo mismo que "sin fila"; REQUIREMENTS RF-DIR-04).
  final NivelCongestion? nivelFilaActual;

  /// Días de la semana en que abre (1 = lunes … 7 = domingo). Por defecto, todos.
  /// Atención al Estudiante, p. ej., abre de lunes a viernes (`Mo-Fr`).
  final Set<int> diasAbierto;

  /// Los siete días de la semana.
  static const Set<int> todosLosDias = <int>{1, 2, 3, 4, 5, 6, 7};

  /// Lunes a viernes (`Mo-Fr`).
  static const Set<int> lunesAViernes = <int>{1, 2, 3, 4, 5};

  static final RegExp _formatoHora = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

  /// `true` si [hora] cumple `HH:mm` entre `00:00` y `23:59`.
  static bool esHoraValida(String hora) => _formatoHora.hasMatch(hora);

  /// Minutos desde la medianoche para una hora `HH:mm` válida.
  /// Lanza [FormatException] si el formato es incorrecto.
  static int minutosDesdeMedianoche(String hora) {
    final coincidencia = _formatoHora.firstMatch(hora);
    if (coincidencia == null) {
      throw FormatException('Hora inválida (se esperaba HH:mm): "$hora"');
    }
    return int.parse(coincidencia.group(1)!) * 60 +
        int.parse(coincidencia.group(2)!);
  }

  /// `true` si el negocio está abierto en [ahora]. O(1).
  ///
  /// * Apertura incluida, cierre excluido (a las 18:00 en punto con cierre
  ///   18:00 ya está cerrado).
  /// * Si el cierre es anterior a la apertura (p. ej. 22:00-02:00) el
  ///   intervalo cruza la medianoche.
  /// * Si apertura == cierre se interpreta como abierto las 24 horas.
  /// * Colombia usa UTC-5 todo el año: si [ahora] viene en UTC se convierte;
  ///   si viene local se usa tal cual.
  bool estaAbierto(DateTime ahora) {
    final local = ahora.isUtc ? ahora.subtract(const Duration(hours: 5)) : ahora;
    final minutoActual = local.hour * 60 + local.minute;
    final apertura = minutosDesdeMedianoche(horaApertura);
    final cierre = minutosDesdeMedianoche(horaCierre);
    if (apertura == cierre) return true;
    if (apertura < cierre) {
      return minutoActual >= apertura && minutoActual < cierre;
    }
    return minutoActual >= apertura || minutoActual < cierre;
  }

  NegocioServicio copyWith({
    String? id,
    String? nombre,
    CategoriaServicio? categoria,
    LatLng? ubicacion,
    String? idEdificioCercano,
    String? horaApertura,
    String? horaCierre,
    int? piso,
    bool? dentroDeEdificio,
    bool? horarioConfirmado,
    NivelCongestion? nivelFilaActual,
    bool borrarNivelFila = false,
    Set<int>? diasAbierto,
  }) {
    return NegocioServicio(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      categoria: categoria ?? this.categoria,
      ubicacion: ubicacion ?? this.ubicacion,
      idEdificioCercano: idEdificioCercano ?? this.idEdificioCercano,
      horaApertura: horaApertura ?? this.horaApertura,
      horaCierre: horaCierre ?? this.horaCierre,
      piso: piso ?? this.piso,
      dentroDeEdificio: dentroDeEdificio ?? this.dentroDeEdificio,
      horarioConfirmado: horarioConfirmado ?? this.horarioConfirmado,
      nivelFilaActual:
          borrarNivelFila ? null : (nivelFilaActual ?? this.nivelFilaActual),
      diasAbierto: diasAbierto ?? this.diasAbierto,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NegocioServicio &&
          other.id == id &&
          other.nombre == nombre &&
          other.categoria == categoria &&
          other.ubicacion == ubicacion &&
          other.idEdificioCercano == idEdificioCercano &&
          other.horaApertura == horaApertura &&
          other.horaCierre == horaCierre &&
          other.piso == piso &&
          other.dentroDeEdificio == dentroDeEdificio &&
          other.horarioConfirmado == horarioConfirmado &&
          other.nivelFilaActual == nivelFilaActual &&
          setEquals(other.diasAbierto, diasAbierto);

  @override
  int get hashCode => Object.hash(
        id,
        nombre,
        categoria,
        ubicacion,
        idEdificioCercano,
        horaApertura,
        horaCierre,
        piso,
        dentroDeEdificio,
        horarioConfirmado,
        nivelFilaActual,
        Object.hashAll(diasAbierto.toList()..sort()),
      );

  @override
  String toString() => 'NegocioServicio($nombre, ${categoria.name})';
}
