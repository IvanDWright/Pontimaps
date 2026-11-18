import 'package:flutter/widgets.dart';
import 'package:pontimaps_app/app.dart';
import 'package:pontimaps_app/core/bootstrap.dart';
import 'package:pontimaps_app/core/config/app_config.dart';
import 'package:pontimaps_app/data/campus_cartography.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // Por defecto (USE_OFFLINE_FALLBACK=true) no se toca Firebase. Con
  // USE_OFFLINE_FALLBACK=false y google-services.json se usan Firebase Auth y
  // Firestore; si Firebase no inicia, la app sigue en modo sin conexión.
  final dependencias = await construirDependencias(
    config: AppConfig.fromEnvironment(),
    prefs: prefs,
  );
  runApp(
    PontiMapsApp(
      config: dependencias.config,
      cartography: CampusCartography.seed(),
      consentRepository: dependencias.consentRepository,
      scheduleRepository: dependencias.scheduleRepository,
      locationProvider: dependencias.locationProvider,
      authRepository: dependencias.authRepository,
      reportsRepository: dependencias.reportsRepository,
      adminRepository: dependencias.adminRepository,
      alertsRepository: dependencias.alertsRepository,
    ),
  );
}
