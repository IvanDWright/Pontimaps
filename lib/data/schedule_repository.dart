import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pontimaps_app/data/campus_cartography.dart';
import 'package:pontimaps_app/models/horario_usuario.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Almacén del horario académico. **Solo local, en el dispositivo** (RF-HOR-02):
/// nunca se sube a la nube, y cada cuenta tiene el suyo.
abstract class ScheduleRepository {
  Future<List<BloqueHorario>> cargar(String cuentaId);
  Future<void> guardar(String cuentaId, List<BloqueHorario> bloques);
}

/// Implementación en memoria (pruebas y modo sin almacenamiento).
class MemoryScheduleRepository implements ScheduleRepository {
  final Map<String, List<BloqueHorario>> _porCuenta = <String, List<BloqueHorario>>{};

  @override
  Future<List<BloqueHorario>> cargar(String cuentaId) async =>
      List<BloqueHorario>.of(_porCuenta[cuentaId] ?? const <BloqueHorario>[]);

  @override
  Future<void> guardar(String cuentaId, List<BloqueHorario> bloques) async {
    _porCuenta[cuentaId] = List<BloqueHorario>.of(bloques);
  }
}

/// Implementación sobre `shared_preferences` (JSON local, una clave por cuenta).
class SharedPreferencesScheduleRepository implements ScheduleRepository {
  SharedPreferencesScheduleRepository(this._prefs);

  final SharedPreferences _prefs;

  static String _clave(String cuentaId) => 'schedule.v1.$cuentaId';

  static Map<String, Object?> bloqueAMapa(BloqueHorario b) => <String, Object?>{
        'id': b.id,
        'materia': b.materia,
        'diaSemana': b.diaSemana,
        'horaInicio': b.horaInicio,
        'horaFin': b.horaFin,
        'idEdificio': b.idEdificio,
        'codigoSalon': b.codigoSalon,
      };

  /// Reconstruye un bloque; `null` si el mapa está dañado (se descarta, no se rompe).
  static BloqueHorario? bloqueDeMapa(Object? crudo) {
    if (crudo is! Map) return null;
    try {
      final id = crudo['id'];
      final materia = crudo['materia'];
      final dia = crudo['diaSemana'];
      final inicio = crudo['horaInicio'];
      final fin = crudo['horaFin'];
      final edificio = crudo['idEdificio'];
      final salon = crudo['codigoSalon'];
      if (id is! String ||
          materia is! String ||
          dia is! int ||
          inicio is! int ||
          fin is! int ||
          edificio is! String ||
          salon is! String) {
        return null;
      }
      if (id.isEmpty ||
          materia.isEmpty ||
          dia < 1 ||
          dia > 7 ||
          inicio < 0 ||
          inicio >= 1440 ||
          fin <= inicio ||
          fin > 1440 ||
          edificio.isEmpty ||
          salon.isEmpty) {
        return null;
      }
      return BloqueHorario(
        id: id,
        materia: materia,
        diaSemana: dia,
        horaInicio: inicio,
        horaFin: fin,
        idEdificio: edificio,
        codigoSalon: salon,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<BloqueHorario>> cargar(String cuentaId) async {
    final texto = _prefs.getString(_clave(cuentaId));
    if (texto == null) return <BloqueHorario>[];
    try {
      final lista = jsonDecode(texto);
      if (lista is! List) return <BloqueHorario>[];
      return <BloqueHorario>[
        for (final e in lista)
          if (bloqueDeMapa(e) case final BloqueHorario b) b,
      ];
    } on FormatException {
      return <BloqueHorario>[];
    }
  }

  @override
  Future<void> guardar(String cuentaId, List<BloqueHorario> bloques) async {
    await _prefs.setString(
      _clave(cuentaId),
      jsonEncode(<Object?>[for (final b in bloques) bloqueAMapa(b)]),
    );
  }
}

/// Qué está mal en un bloque que se quiere guardar (E2-07).
enum ErrorBloque {
  horaFinNoPosterior('La hora de fin debe ser posterior a la de inicio'),
  edificioInexistente('Elige un edificio del catálogo'),
  salonInexistente('Elige un salón de ese edificio');

  const ErrorBloque(this.mensaje);

  final String mensaje;
}

/// Valida [bloque] contra el catálogo: la hora de fin posterior a la de inicio,
/// el edificio existente y el salón perteneciente a ese edificio (sin texto
/// libre inexistente). `null` si es válido.
ErrorBloque? validarBloque(BloqueHorario bloque, CampusCartography cartografia) {
  if (bloque.horaFin <= bloque.horaInicio) return ErrorBloque.horaFinNoPosterior;
  final edificio = cartografia.edificioPorId(bloque.idEdificio);
  if (edificio == null) return ErrorBloque.edificioInexistente;
  if (edificio.buscarSalon(bloque.codigoSalon) == null) return ErrorBloque.salonInexistente;
  return null;
}

/// Bloques de [existentes] que se solapan con [bloque] el mismo día (E2-08:
/// solo se advierte, se puede guardar). Un bloque no se solapa consigo mismo.
List<BloqueHorario> bloquesSolapados(BloqueHorario bloque, Iterable<BloqueHorario> existentes) {
  return <BloqueHorario>[
    for (final otro in existentes)
      if (otro.id != bloque.id &&
          otro.diaSemana == bloque.diaSemana &&
          otro.horaInicio < bloque.horaFin &&
          bloque.horaInicio < otro.horaFin)
        otro,
  ];
}

/// Horario del usuario actual. Sin cuenta (visitante) no guarda nada, ni local
/// ni en la nube (E2-01).
class ScheduleController extends ChangeNotifier {
  ScheduleController(this._repositorio);

  final ScheduleRepository _repositorio;

  String? _cuentaId;
  List<BloqueHorario> _bloques = const <BloqueHorario>[];

  /// Bloques ordenados por día y hora de inicio.
  List<BloqueHorario> get bloques => _bloques;

  String? get cuentaId => _cuentaId;

  static int _orden(BloqueHorario a, BloqueHorario b) {
    final porDia = a.diaSemana.compareTo(b.diaSemana);
    return porDia != 0 ? porDia : a.horaInicio.compareTo(b.horaInicio);
  }

  /// Cambia de cuenta y carga su horario local. `null` (visitante) deja la lista
  /// vacía: el horario de otra cuenta no se muestra (E2-13).
  Future<void> usarCuenta(String? cuentaId) async {
    _cuentaId = cuentaId;
    if (cuentaId == null) {
      _bloques = const <BloqueHorario>[];
    } else {
      final cargados = await _repositorio.cargar(cuentaId);
      cargados.sort(_orden);
      _bloques = cargados;
    }
    notifyListeners();
  }

  /// Agrega o reemplaza (por `id`) un bloque. Devuelve `false` si no hay cuenta.
  Future<bool> guardar(BloqueHorario bloque) async {
    final cuenta = _cuentaId;
    if (cuenta == null) return false;
    final lista = List<BloqueHorario>.of(_bloques);
    final i = lista.indexWhere((b) => b.id == bloque.id);
    if (i >= 0) {
      lista[i] = bloque;
    } else {
      lista.add(bloque);
    }
    lista.sort(_orden);
    _bloques = lista;
    notifyListeners();
    await _repositorio.guardar(cuenta, lista);
    return true;
  }

  Future<bool> eliminar(String idBloque) async {
    final cuenta = _cuentaId;
    if (cuenta == null) return false;
    _bloques = <BloqueHorario>[
      for (final b in _bloques)
        if (b.id != idBloque) b,
    ];
    notifyListeners();
    await _repositorio.guardar(cuenta, _bloques);
    return true;
  }
}
