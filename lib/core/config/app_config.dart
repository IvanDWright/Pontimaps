/// Configuración de ejecución leída de `--dart-define` (sin llaves en el código).
/// Ejemplo:
///
/// ```text
/// flutter run --dart-define=USE_OFFLINE_FALLBACK=false --dart-define=FIREBASE_PROJECT_ID=pontimaps-puj
/// flutter run --dart-define-from-file=dart_defines.json
/// ```
class AppConfig {
  const AppConfig({
    this.useOfflineFallback = defaultUseOfflineFallback,
    this.firebaseProjectId = defaultFirebaseProjectId,
    this.velocidadPeatonalMetrosPorSegundo = defaultVelocidadPeatonal,
    this.simularUbicacion = false,
  }) : assert(
          velocidadPeatonalMetrosPorSegundo > 0,
          'La velocidad peatonal debe ser positiva',
        );

  /// Lee los valores de `--dart-define`; los que falten usan su valor por defecto.
  factory AppConfig.fromEnvironment() {
    // Dart no tiene `double.fromEnvironment`: se lee como texto y se valida.
    final velocidad = double.tryParse(const String.fromEnvironment('WALKING_SPEED_MPS'));
    return AppConfig(
      useOfflineFallback: const bool.fromEnvironment(
        'USE_OFFLINE_FALLBACK',
        defaultValue: defaultUseOfflineFallback,
      ),
      firebaseProjectId: const String.fromEnvironment(
        'FIREBASE_PROJECT_ID',
        defaultValue: defaultFirebaseProjectId,
      ),
      velocidadPeatonalMetrosPorSegundo:
          velocidad != null && velocidad > 0 ? velocidad : defaultVelocidadPeatonal,
      simularUbicacion: const bool.fromEnvironment('SIMULATE_LOCATION'),
    );
  }

  /// Por defecto la app corre en modo demostración sin red (Regla 5).
  static const bool defaultUseOfflineFallback = true;
  static const String defaultFirebaseProjectId = 'pontimaps-puj';

  /// Velocidad peatonal base (1,25 m/s ≈ 4,5 km/h); a calibrar en campo para
  /// cumplir el error de ±1 min del tiempo estimado (RF-NAV-04).
  static const double defaultVelocidadPeatonal = 1.25;

  /// `true`: repositorios en memoria y catálogo local, sin llamar a Firebase.
  final bool useOfflineFallback;

  /// ID del proyecto de Firebase (no es un secreto).
  final String firebaseProjectId;

  /// Velocidad con la que se convierte la distancia de la ruta en minutos.
  /// Se cambia con `--dart-define=WALKING_SPEED_MPS=1.1`.
  final double velocidadPeatonalMetrosPorSegundo;

  /// `true`: la ubicación sale de un punto fijo del campus (Plazoleta Central)
  /// y no del GPS; útil en demos y emuladores. `--dart-define=SIMULATE_LOCATION=true`.
  final bool simularUbicacion;

  /// `true` si el proyecto de Firebase puede usarse (modo en línea).
  bool get useFirebase => !useOfflineFallback;

  AppConfig copyWith({
    bool? useOfflineFallback,
    String? firebaseProjectId,
    double? velocidadPeatonalMetrosPorSegundo,
    bool? simularUbicacion,
  }) {
    return AppConfig(
      useOfflineFallback: useOfflineFallback ?? this.useOfflineFallback,
      firebaseProjectId: firebaseProjectId ?? this.firebaseProjectId,
      velocidadPeatonalMetrosPorSegundo: velocidadPeatonalMetrosPorSegundo ??
          this.velocidadPeatonalMetrosPorSegundo,
      simularUbicacion: simularUbicacion ?? this.simularUbicacion,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppConfig &&
          other.useOfflineFallback == useOfflineFallback &&
          other.firebaseProjectId == firebaseProjectId &&
          other.velocidadPeatonalMetrosPorSegundo ==
              velocidadPeatonalMetrosPorSegundo &&
          other.simularUbicacion == simularUbicacion;

  @override
  int get hashCode => Object.hash(
        useOfflineFallback,
        firebaseProjectId,
        velocidadPeatonalMetrosPorSegundo,
        simularUbicacion,
      );

  @override
  String toString() =>
      'AppConfig(offline: $useOfflineFallback, proyecto: $firebaseProjectId)';
}
