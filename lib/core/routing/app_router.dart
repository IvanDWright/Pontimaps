import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontimaps_app/core/providers.dart';
import 'package:pontimaps_app/core/routing/rutas.dart';
import 'package:pontimaps_app/data/app_session.dart';
import 'package:pontimaps_app/data/consent_repository.dart';
import 'package:pontimaps_app/presentation/screens/admin_panel_screen.dart';
import 'package:pontimaps_app/presentation/screens/auth_screens.dart';
import 'package:pontimaps_app/presentation/screens/cartography_status_screen.dart';
import 'package:pontimaps_app/presentation/screens/home_shell.dart';
import 'package:pontimaps_app/presentation/screens/permission_screen.dart';
import 'package:pontimaps_app/presentation/screens/schedule_screen.dart';
import 'package:pontimaps_app/presentation/screens/splash_screen.dart';

export 'package:pontimaps_app/core/routing/rutas.dart';

/// Enrutador con guardia de consentimiento (Regla 4): hasta que el usuario
/// responda el consentimiento de ubicación no se llega al mapa, y nada pide el
/// permiso del sistema antes de `PermissionScreen`.
///
/// Se reevalúa cada vez que cambia [consentimiento] (`refreshListenable`).
GoRouter crearRouter({
  required ConsentController consentimiento,
  required AppSession sesion,
  bool exigirAcceso = false,
  String initialLocation = Rutas.splash,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: Listenable.merge(<Listenable>[consentimiento, sesion]),
    redirect: (context, state) {
      final destino = state.matchedLocation;
      if (destino == Rutas.estado) return null;
      if (!consentimiento.cargado) {
        return destino == Rutas.splash ? null : Rutas.splash;
      }
      if (destino == Rutas.mapa && !consentimiento.estado.resuelto) {
        return Rutas.permiso;
      }
      // Con Firebase, antes del mapa se elige: iniciar sesión, registrarse o
      // continuar como Visitante (que no crea ninguna sesión).
      if (exigirAcceso &&
          destino == Rutas.mapa &&
          sesion.cuenta == null &&
          !consentimiento.estado.visitanteElegido) {
        return Rutas.acceso;
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: Rutas.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Rutas.permiso,
        builder: (context, state) => const PermissionScreen(),
      ),
      GoRoute(
        path: Rutas.mapa,
        builder: (context, state) => const HomeShell(),
      ),
      GoRoute(
        path: Rutas.horario,
        builder: (context, state) => const ScheduleScreen(),
      ),
      GoRoute(
        path: Rutas.acceso,
        builder: (context, state) => const AuthGateScreen(),
      ),
      GoRoute(
        path: Rutas.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Rutas.registro,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: Rutas.verificar,
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: Rutas.admin,
        builder: (context, state) => const AdminPanelScreen(),
      ),
      GoRoute(
        path: Rutas.estado,
        builder: (context, state) => Consumer(
          builder: (context, ref, _) => CartographyStatusScreen(
            cartography: ref.watch(cartographyProvider),
            config: ref.watch(appConfigProvider),
          ),
        ),
      ),
    ],
  );
}
