import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Versión vigente del texto de consentimiento (RF-PER-02). Si cambia, se
/// vuelve a pedir la aceptación aunque el usuario ya hubiera respondido.
const String kConsentVersion = '2026-11-v1';

/// Respuesta del usuario al consentimiento de ubicación (Ley 1581 de 2012).
enum DecisionGps { pendiente, aceptado, rechazado }

/// Estado del consentimiento, guardado **solo en el dispositivo**.
///
/// Privacidad: contiene únicamente la decisión, la versión del texto que se
/// mostró y si el GPS está pausado. Nunca coordenadas, recorridos ni
/// identificadores.
@immutable
class ConsentState {
  const ConsentState({
    this.decision = DecisionGps.pendiente,
    this.version = kConsentVersion,
    this.gpsPausado = false,
    this.modoVisitante = true,
    this.visitanteElegido = false,
  });

  final DecisionGps decision;

  /// Versión del texto de consentimiento que el usuario respondió.
  final String version;

  /// `true` si el usuario apagó el GPS desde el mapa (la decisión se conserva).
  final bool gpsPausado;

  /// Modo visitante: solo lectura, sin cuenta ni sesión en la nube (Path 0B).
  final bool modoVisitante;

  /// `true` si la persona tocó «Continuar como Visitante» en la puerta de entrada.
  /// Se guarda **solo en el dispositivo**; no crea usuario ni sesión en Firebase.
  final bool visitanteElegido;

  /// `true` si la pantalla de consentimiento ya no debe mostrarse.
  bool get resuelto => decision != DecisionGps.pendiente && version == kConsentVersion;

  /// `true` si se puede leer el GPS ahora (aceptado, vigente y no pausado).
  bool get gpsActivo =>
      decision == DecisionGps.aceptado && version == kConsentVersion && !gpsPausado;

  ConsentState copyWith({
    DecisionGps? decision,
    String? version,
    bool? gpsPausado,
    bool? modoVisitante,
    bool? visitanteElegido,
  }) {
    return ConsentState(
      decision: decision ?? this.decision,
      version: version ?? this.version,
      gpsPausado: gpsPausado ?? this.gpsPausado,
      modoVisitante: modoVisitante ?? this.modoVisitante,
      visitanteElegido: visitanteElegido ?? this.visitanteElegido,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsentState &&
          other.decision == decision &&
          other.version == version &&
          other.gpsPausado == gpsPausado &&
          other.modoVisitante == modoVisitante &&
          other.visitanteElegido == visitanteElegido;

  @override
  int get hashCode => Object.hash(decision, version, gpsPausado, modoVisitante, visitanteElegido);

  @override
  String toString() =>
      'ConsentState(${decision.name}, v$version, pausado: $gpsPausado, visitante: $modoVisitante)';
}

/// Persistencia del consentimiento. La UI no depende de `shared_preferences`.
abstract class ConsentRepository {
  Future<ConsentState> cargar();
  Future<void> guardar(ConsentState estado);
}

/// Implementación en memoria (pruebas y modo sin almacenamiento).
class MemoryConsentRepository implements ConsentRepository {
  MemoryConsentRepository([ConsentState inicial = const ConsentState()]) : _estado = inicial;

  ConsentState _estado;

  @override
  Future<ConsentState> cargar() async => _estado;

  @override
  Future<void> guardar(ConsentState estado) async => _estado = estado;
}

/// Implementación sobre `shared_preferences`: solo preferencias locales.
class SharedPreferencesConsentRepository implements ConsentRepository {
  SharedPreferencesConsentRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _kDecision = 'consent.gps.decision';
  static const String _kVersion = 'consent.gps.version';
  static const String _kPausado = 'consent.gps.pausado';
  static const String _kVisitante = 'consent.modo_visitante';
  static const String _kVisitanteElegido = 'consent.visitante_elegido';

  @override
  Future<ConsentState> cargar() async {
    final decision = DecisionGps.values.asNameMap()[_prefs.getString(_kDecision)] ??
        DecisionGps.pendiente;
    return ConsentState(
      decision: decision,
      version: _prefs.getString(_kVersion) ?? '',
      gpsPausado: _prefs.getBool(_kPausado) ?? false,
      modoVisitante: _prefs.getBool(_kVisitante) ?? true,
      visitanteElegido: _prefs.getBool(_kVisitanteElegido) ?? false,
    );
  }

  @override
  Future<void> guardar(ConsentState estado) async {
    await _prefs.setString(_kDecision, estado.decision.name);
    await _prefs.setString(_kVersion, estado.version);
    await _prefs.setBool(_kPausado, estado.gpsPausado);
    await _prefs.setBool(_kVisitante, estado.modoVisitante);
    await _prefs.setBool(_kVisitanteElegido, estado.visitanteElegido);
  }
}

/// Estado observable del consentimiento para la UI y el enrutador.
///
/// Es la única fuente de verdad: `go_router` la escucha (`refreshListenable`)
/// para decidir si muestra `PermissionScreen` o el mapa.
class ConsentController extends ChangeNotifier {
  ConsentController(this._repositorio);

  final ConsentRepository _repositorio;

  ConsentState _estado = const ConsentState();
  bool _cargado = false;

  ConsentState get estado => _estado;

  /// `false` hasta que termina la primera lectura del almacenamiento.
  bool get cargado => _cargado;

  /// Lee el estado guardado. Un texto de otra versión cuenta como pendiente.
  Future<void> cargar() async {
    final leido = await _repositorio.cargar();
    _estado = leido.version == kConsentVersion
        ? leido
        : leido.copyWith(decision: DecisionGps.pendiente, version: kConsentVersion);
    _cargado = true;
    notifyListeners();
  }

  Future<void> _actualizar(ConsentState nuevo) async {
    _estado = nuevo;
    notifyListeners();
    await _repositorio.guardar(nuevo);
  }

  /// El usuario aceptó el uso del GPS en `PermissionScreen`.
  Future<void> aceptarGps() => _actualizar(
        _estado.copyWith(
          decision: DecisionGps.aceptado,
          version: kConsentVersion,
          gpsPausado: false,
        ),
      );

  /// El usuario no aceptó: la app sigue con origen manual (RF-PER-05).
  Future<void> rechazarGps() => _actualizar(
        _estado.copyWith(
          decision: DecisionGps.rechazado,
          version: kConsentVersion,
          gpsPausado: false,
        ),
      );

  /// La persona eligió «Continuar como Visitante» (Path 0B): se recuerda solo
  /// en el dispositivo, sin crear usuario ni sesión.
  Future<void> elegirVisitante() => _actualizar(_estado.copyWith(visitanteElegido: true));

  /// Pausa o reanuda la lectura del GPS sin perder la decisión (RF-PER-04).
  Future<void> pausarGps(bool pausado) =>
      _actualizar(_estado.copyWith(gpsPausado: pausado));
}
