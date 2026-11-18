import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:pontimaps_app/core/config/app_config.dart';
import 'package:pontimaps_app/data/admin_repository.dart';
import 'package:pontimaps_app/data/auth_repository.dart';
import 'package:pontimaps_app/data/consent_repository.dart';
import 'package:pontimaps_app/data/firebase_auth_repository.dart';
import 'package:pontimaps_app/data/firestore_repositories.dart';
import 'package:pontimaps_app/data/location_service.dart';
import 'package:pontimaps_app/data/official_alerts_repository.dart';
import 'package:pontimaps_app/data/reports_repository.dart';
import 'package:pontimaps_app/data/schedule_repository.dart';
import 'package:pontimaps_app/models/horario_usuario.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dependencias con las que arranca la app.
///
/// Con `USE_OFFLINE_FALLBACK=true` (por defecto) todo es local y en memoria, sin
/// llamar a Firebase. Con `USE_OFFLINE_FALLBACK=false` y Firebase configurado
/// (`google-services.json` en Android) se usan Firebase Auth y Cloud Firestore; si
/// Firebase no puede iniciar, la app **vuelve al modo sin conexión** en lugar de
/// quedarse bloqueada.
class DependenciasApp {
  const DependenciasApp({
    required this.config,
    required this.consentRepository,
    required this.scheduleRepository,
    required this.locationProvider,
    this.authRepository,
    this.reportsRepository,
    this.adminRepository,
    this.alertsRepository,
    this.firebaseActivo = false,
    this.avisoFirebase,
  });

  /// Configuración efectiva (puede haber vuelto a modo sin conexión).
  final AppConfig config;
  final ConsentRepository consentRepository;
  final ScheduleRepository scheduleRepository;
  final LocationProvider locationProvider;

  /// Los siguientes son `null` en modo sin conexión: la app usa sus versiones en memoria.
  final AuthRepository? authRepository;
  final ReportsRepository? reportsRepository;
  final AdminRepository? adminRepository;
  final OfficialAlertsRepository? alertsRepository;

  final bool firebaseActivo;

  /// Por qué se volvió a modo sin conexión, si pasó.
  final String? avisoFirebase;
}

/// Inicia Firebase. Se puede sustituir en pruebas.
typedef IniciarFirebase = Future<void> Function();

Future<void> _iniciarFirebaseReal() async {
  await Firebase.initializeApp();
}

/// Construye las dependencias según [config]. El horario y el consentimiento son
/// siempre locales (`shared_preferences`); nada del horario va a la nube.
Future<DependenciasApp> construirDependencias({
  required AppConfig config,
  required SharedPreferences prefs,
  IniciarFirebase? iniciarFirebase,
  FirebaseFirestore? firestore,
}) async {
  final consentimiento = SharedPreferencesConsentRepository(prefs);
  final horario = SharedPreferencesScheduleRepository(prefs);
  final ubicacion = config.simularUbicacion ? SimulatedLocationProvider() : GpsLocationProvider();

  if (!config.useFirebase) {
    return DependenciasApp(
      config: config,
      consentRepository: consentimiento,
      scheduleRepository: horario,
      locationProvider: ubicacion,
    );
  }

  try {
    await (iniciarFirebase ?? _iniciarFirebaseReal)();
    final db = firestore ?? FirebaseFirestore.instance;
    final auth = FirebaseAuthRepository(firestore: db);
    String? uid() => auth.actual?.uid;
    bool esAdmin() {
      final cuenta = auth.actual;
      return cuenta != null &&
          cuenta.rol == RolUsuario.admin &&
          cuenta.emailVerified &&
          cuenta.estado == EstadoCuenta.activo;
    }

    return DependenciasApp(
      config: config,
      consentRepository: consentimiento,
      scheduleRepository: horario,
      locationProvider: ubicacion,
      authRepository: auth,
      reportsRepository: FirestoreReportsRepository(firestore: db, uidActual: uid),
      adminRepository: FirestoreAdminRepository(firestore: db, uidActual: uid, esAdmin: esAdmin),
      alertsRepository: FirestoreOfficialAlertsRepository(firestore: db),
      firebaseActivo: true,
    );
  } catch (e) {
    debugPrint('Firebase no está disponible, se usa el modo sin conexión: $e');
    return DependenciasApp(
      config: config.copyWith(useOfflineFallback: true),
      consentRepository: consentimiento,
      scheduleRepository: horario,
      locationProvider: ubicacion,
      avisoFirebase: 'Firebase no está configurado; la app funciona sin conexión.',
    );
  }
}
