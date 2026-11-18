import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/config/app_config.dart';
import 'package:pontimaps_app/core/providers.dart';
import 'package:pontimaps_app/core/routing/app_router.dart';
import 'package:pontimaps_app/core/theme/pontimaps_theme.dart';
import 'package:pontimaps_app/data/admin_repository.dart';
import 'package:pontimaps_app/data/app_session.dart';
import 'package:pontimaps_app/data/auth_repository.dart';
import 'package:pontimaps_app/data/campus_cartography.dart';
import 'package:pontimaps_app/data/consent_repository.dart';
import 'package:pontimaps_app/data/location_service.dart';
import 'package:pontimaps_app/data/notification_scheduler.dart';
import 'package:pontimaps_app/data/official_alerts_repository.dart';
import 'package:pontimaps_app/data/reports_repository.dart';
import 'package:pontimaps_app/data/schedule_repository.dart';
import 'package:pontimaps_app/presentation/shell_controller.dart';

/// Raíz de la aplicación PontiMaps.
///
/// Recibe sus dependencias por constructor para poder probarla sin red ni
/// plataforma: el catálogo local [cartography], la [config] de `--dart-define`,
/// el [consentRepository] (por defecto en memoria), la fuente de posiciones
/// [locationProvider] (por defecto simulada en la Plazoleta Central) y, solo en
/// pruebas, un [tileProvider] sin red. El flujo es Splash → consentimiento
/// (Ley 1581) → mapa; [initialLocation] permite abrir otra ruta (p. ej. `/estado`).
class PontiMapsApp extends StatefulWidget {
  PontiMapsApp({
    super.key,
    required this.cartography,
    this.config = const AppConfig(),
    ConsentRepository? consentRepository,
    LocationProvider? locationProvider,
    this.tileProvider,
    this.initialLocation = Rutas.splash,
    this.initialProfile = PerfilDemo.visitante,
    this.clock,
    this.reportsRepository,
    ScheduleRepository? scheduleRepository,
    NotificationScheduler? notificationScheduler,
    this.authRepository,
    this.adminRepository,
    this.alertsRepository,
  })  : consentRepository = consentRepository ?? MemoryConsentRepository(),
        locationProvider = locationProvider ?? SimulatedLocationProvider(),
        scheduleRepository = scheduleRepository ?? MemoryScheduleRepository(),
        notificationScheduler = notificationScheduler ?? InAppNotificationScheduler();

  final CampusCartography cartography;
  final AppConfig config;
  final ConsentRepository consentRepository;
  final LocationProvider locationProvider;
  final TileProvider? tileProvider;
  final String initialLocation;

  /// Perfil de demostración con el que arranca (por defecto, Visitante).
  final PerfilDemo initialProfile;

  /// Reloj inyectable (pruebas de tiempo exacto); por defecto, la hora real.
  final Reloj? clock;

  /// Reportes; por defecto en memoria (modo demostración sin Firebase).
  final ReportsRepository? reportsRepository;

  /// Horario académico; siempre local, nunca en la nube.
  final ScheduleRepository scheduleRepository;

  /// Alertas de hora de salida; por defecto, aviso dentro de la app.
  final NotificationScheduler notificationScheduler;

  /// Autenticación; por defecto cuentas en memoria (modo demostración). Con
  /// Firebase configurado llega un `FirebaseAuthRepository`.
  final AuthRepository? authRepository;

  /// Moderación del administrador; por defecto en memoria, sobre los reportes en memoria.
  final AdminRepository? adminRepository;

  /// Alertas oficiales; por defecto en memoria.
  final OfficialAlertsRepository? alertsRepository;

  @override
  State<PontiMapsApp> createState() => _PontiMapsAppState();
}

class _PontiMapsAppState extends State<PontiMapsApp> {
  late final ConsentController _consentimiento;
  late final GoRouter _router;
  late final AppSession _sesion;
  late final ScheduleController _horario;
  late final ShellController _shell;
  late final ReportsRepository _reportes;
  late final Reloj _reloj;
  late final AuthRepository _auth;
  late final AdminRepository _admin;
  late final OfficialAlertsRepository _alertas;
  StreamSubscription<CuentaAuth?>? _suscripcionAuth;

  @override
  void initState() {
    super.initState();
    _reloj = widget.clock ?? DateTime.now;
    _reportes = widget.reportsRepository ?? InMemoryReportsRepository(reloj: _reloj);
    _consentimiento = ConsentController(widget.consentRepository);
    _sesion = AppSession(widget.initialProfile);
    _horario = ScheduleController(widget.scheduleRepository);
    _shell = ShellController();
    _auth = widget.authRepository ?? InMemoryAuthRepository();
    _alertas = widget.alertsRepository ?? InMemoryOfficialAlertsRepository(reloj: _reloj);
    final reportesEnMemoria = _reportes;
    _admin = widget.adminRepository ??
        InMemoryAdminRepository(
          // La moderación en memoria solo existe sobre reportes en memoria.
          reportes: reportesEnMemoria is InMemoryReportsRepository
              ? reportesEnMemoria
              : InMemoryReportsRepository(reloj: _reloj),
          esAdmin: () => _sesion.perfil.esAdministrador,
          alBloquearHash: (hash) => _sesion.bloquearHash(hash),
        );
    _sesion.usarCuenta(_auth.actual);
    _suscripcionAuth = _auth.cambios().listen(_sesion.usarCuenta);
    _sesion.addListener(_alCambiarPerfil);
    _alCambiarPerfil();
    _router = crearRouter(
      consentimiento: _consentimiento,
      sesion: _sesion,
      // Con Firebase se pasa por la puerta de entrada (S02) antes del mapa.
      exigirAcceso: widget.config.useFirebase,
      initialLocation: widget.initialLocation,
    );
  }

  /// El horario es de cada cuenta: al cambiar de perfil se carga el suyo (el
  /// visitante no tiene ninguno).
  void _alCambiarPerfil() => _horario.usarCuenta(_sesion.perfil.uid);

  @override
  void dispose() {
    _suscripcionAuth?.cancel();
    _sesion.removeListener(_alCambiarPerfil);
    _sesion.dispose();
    _horario.dispose();
    _shell.dispose();
    _router.dispose();
    _consentimiento.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(widget.config),
        cartographyProvider.overrideWithValue(widget.cartography),
        consentControllerProvider.overrideWithValue(_consentimiento),
        locationProviderProvider.overrideWithValue(widget.locationProvider),
        tileProviderProvider.overrideWithValue(widget.tileProvider),
        clockProvider.overrideWithValue(_reloj),
        reportsRepositoryProvider.overrideWithValue(_reportes),
        scheduleControllerProvider.overrideWithValue(_horario),
        sessionProvider.overrideWithValue(_sesion),
        authRepositoryProvider.overrideWithValue(_auth),
        adminRepositoryProvider.overrideWithValue(_admin),
        alertsRepositoryProvider.overrideWithValue(_alertas),
        shellControllerProvider.overrideWithValue(_shell),
        notificationSchedulerProvider.overrideWithValue(widget.notificationScheduler),
      ],
      child: MaterialApp.router(
        title: 'PontiMaps',
        debugShowCheckedModeBanner: false,
        theme: PontiMapsTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
