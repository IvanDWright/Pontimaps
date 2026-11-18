import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontimaps_app/core/config/app_config.dart';
import 'package:pontimaps_app/data/admin_repository.dart';
import 'package:pontimaps_app/data/auth_repository.dart';
import 'package:pontimaps_app/data/campus_cartography.dart';
import 'package:pontimaps_app/data/consent_repository.dart';
import 'package:pontimaps_app/data/app_session.dart';
import 'package:pontimaps_app/data/location_service.dart';
import 'package:pontimaps_app/data/notification_scheduler.dart';
import 'package:pontimaps_app/data/official_alerts_repository.dart';
import 'package:pontimaps_app/data/places_repository.dart';
import 'package:pontimaps_app/data/reports_repository.dart';
import 'package:pontimaps_app/data/schedule_repository.dart';
import 'package:pontimaps_app/presentation/shell_controller.dart';

/// Dependencias de la app. Se sobrescriben en `PontiMapsApp` (y en las pruebas)
/// para que la UI nunca dependa de `geolocator`, `shared_preferences` ni de la
/// red directamente.
final Provider<AppConfig> appConfigProvider =
    Provider<AppConfig>((ref) => throw UnimplementedError('appConfigProvider'));

final Provider<CampusCartography> cartographyProvider = Provider<CampusCartography>(
  (ref) => throw UnimplementedError('cartographyProvider'),
);

final Provider<ConsentController> consentControllerProvider = Provider<ConsentController>(
  (ref) => throw UnimplementedError('consentControllerProvider'),
);

final Provider<LocationProvider> locationProviderProvider = Provider<LocationProvider>(
  (ref) => throw UnimplementedError('locationProviderProvider'),
);

/// Proveedor de teselas del mapa; `null` usa la red (OpenStreetMap). Las pruebas
/// inyectan uno sin red.
final Provider<TileProvider?> tileProviderProvider = Provider<TileProvider?>((ref) => null);

/// Reloj de la app (inyectable para pruebas de tiempo exacto).
final Provider<Reloj> clockProvider = Provider<Reloj>((ref) => DateTime.now);

final Provider<ReportsRepository> reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => throw UnimplementedError('reportsRepositoryProvider'),
);

final Provider<ScheduleController> scheduleControllerProvider = Provider<ScheduleController>(
  (ref) => throw UnimplementedError('scheduleControllerProvider'),
);

final Provider<AppSession> sessionProvider = Provider<AppSession>(
  (ref) => throw UnimplementedError('sessionProvider'),
);

final Provider<ShellController> shellControllerProvider = Provider<ShellController>(
  (ref) => throw UnimplementedError('shellControllerProvider'),
);

/// Lugares del directorio (semilla local); se deriva del catálogo.
final Provider<PlacesRepository> placesRepositoryProvider = Provider<PlacesRepository>(
  (ref) => SeedPlacesRepository(ref.watch(cartographyProvider)),
);

/// Programador de alertas de hora de salida (aviso dentro de la app por defecto).
final Provider<NotificationScheduler> notificationSchedulerProvider =
    Provider<NotificationScheduler>(
  (ref) => throw UnimplementedError('notificationSchedulerProvider'),
);

/// Autenticación institucional (Firebase Auth o cuentas en memoria).
final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError('authRepositoryProvider'),
);

/// Moderación del administrador (reportes y autores).
final Provider<AdminRepository> adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => throw UnimplementedError('adminRepositoryProvider'),
);

/// Alertas oficiales fijas (lectura pública).
final Provider<OfficialAlertsRepository> alertsRepositoryProvider =
    Provider<OfficialAlertsRepository>(
  (ref) => throw UnimplementedError('alertsRepositoryProvider'),
);
