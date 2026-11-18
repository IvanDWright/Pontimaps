import 'package:pontimaps_app/core/utils/colecciones.dart';

/// Tipo de espacio dentro de un edificio.
enum TipoSalon { aula, laboratorio, auditorio, oficina }

/// Salón de un edificio del campus.
///
/// Un salón **siempre** sabe en qué edificio y en qué piso está
/// (regla de UI del proyecto: nunca mostrar un salón sin Edificio + Piso).
///
/// Invariantes: `codigo`, `idEdificio` y `nombreEdificio` no vacíos;
/// `numeroEdificio` es `null` (edificio sin número oficial, p. ej. la
/// Biblioteca) o positivo. El piso puede ser negativo (sótanos).
class Salon {
  const Salon({
    required this.codigo,
    required this.piso,
    required this.idEdificio,
    required this.nombreEdificio,
    required this.numeroEdificio,
    this.tipo = TipoSalon.aula,
  })  : assert(codigo != '', 'El código del salón no puede estar vacío'),
        assert(idEdificio != '', 'idEdificio no puede estar vacío'),
        assert(nombreEdificio != '', 'nombreEdificio no puede estar vacío'),
        assert(
          numeroEdificio == null || numeroEdificio > 0,
          'numeroEdificio debe ser positivo',
        );

  final String codigo;
  final int piso;
  final String idEdificio;
  final String nombreEdificio;

  /// Número oficial del edificio, o `null` si el edificio no tiene.
  final int? numeroEdificio;
  final TipoSalon tipo;

  /// Forma canónica de un código para compararlo: sin espacios y en mayúsculas.
  static String normalizarCodigo(String codigo) =>
      codigo.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  /// Etiqueta de ubicación visible al usuario: `"Edificio 51 · Piso 3"`.
  /// Si el edificio no tiene número, usa su nombre: `"Biblioteca … · Piso 2"`.
  String etiquetaUbicacion() {
    final edificio =
        numeroEdificio == null ? nombreEdificio : 'Edificio $numeroEdificio';
    return '$edificio · Piso $piso';
  }

  Salon copyWith({
    String? codigo,
    int? piso,
    String? idEdificio,
    String? nombreEdificio,
    Object? numeroEdificio = sinCambio,
    TipoSalon? tipo,
  }) {
    return Salon(
      codigo: codigo ?? this.codigo,
      piso: piso ?? this.piso,
      idEdificio: idEdificio ?? this.idEdificio,
      nombreEdificio: nombreEdificio ?? this.nombreEdificio,
      numeroEdificio: identical(numeroEdificio, sinCambio)
          ? this.numeroEdificio
          : numeroEdificio as int?,
      tipo: tipo ?? this.tipo,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Salon &&
          other.codigo == codigo &&
          other.piso == piso &&
          other.idEdificio == idEdificio &&
          other.nombreEdificio == nombreEdificio &&
          other.numeroEdificio == numeroEdificio &&
          other.tipo == tipo;

  @override
  int get hashCode => Object.hash(
        codigo,
        piso,
        idEdificio,
        nombreEdificio,
        numeroEdificio,
        tipo,
      );

  @override
  String toString() => 'Salon($codigo, ${etiquetaUbicacion()}, ${tipo.name})';
}
