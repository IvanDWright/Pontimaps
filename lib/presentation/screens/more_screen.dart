import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/providers.dart';
import 'package:pontimaps_app/core/routing/rutas.dart';
import 'package:pontimaps_app/data/campus_cartography.dart';
import 'package:pontimaps_app/data/consent_repository.dart';
import 'package:pontimaps_app/data/app_session.dart';
import 'package:pontimaps_app/domain/services/auth_guard.dart';
import 'package:pontimaps_app/presentation/widgets/restricted_action_dialog.dart';

/// Pestaña «Más / Ajustes» (S26): perfil de demostración, horario, interruptor del
/// GPS y datos de la app.
///
/// El selector de perfil solo existe en el modo demostración sin Firebase;
/// con Firebase configurado lo reemplaza el inicio de
/// sesión real y el botón de depuración desaparece.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  Future<void> _alternarGps(BuildContext context, WidgetRef ref, bool encendido) async {
    final consentimiento = ref.read(consentControllerProvider);
    if (!encendido) {
      await consentimiento.pausarGps(true);
    } else if (consentimiento.estado.decision == DecisionGps.aceptado) {
      await consentimiento.pausarGps(false);
    } else if (context.mounted) {
      // Aún no aceptó el consentimiento: se vuelve a la pantalla que lo pide.
      context.push('/permiso');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final sesion = ref.watch(sessionProvider);
    final consentimiento = ref.watch(consentControllerProvider);
    final enDemo = ref.watch(appConfigProvider).useOfflineFallback;
    return Scaffold(
      appBar: AppBar(title: const Text('Más / Ajustes')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[sesion, consentimiento]),
          builder: (context, _) {
            final bloqueadoHorario = accionBloqueada(ref, AccionProtegida.guardarHorario);
            return ListView(
              padding: const EdgeInsets.all(LayoutMetrics.screenMargin),
              children: <Widget>[
                if (enDemo) ...<Widget>[
                  Text('Perfil de demostración', style: textTheme.titleMedium),
                  const SizedBox(height: LayoutMetrics.space8),
                  Text(
                    'Sin Firebase la app usa cuentas de prueba en memoria. Cambia de perfil '
                    'para ver qué puede hacer cada uno.',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: LayoutMetrics.space8),
                  Wrap(
                    spacing: LayoutMetrics.space8,
                    runSpacing: LayoutMetrics.space8,
                    children: <Widget>[
                      for (final perfil in PerfilDemo.values)
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: LayoutMetrics.minTouchTarget),
                          child: ChoiceChip(
                            label: Text(perfil.etiqueta),
                            selected: sesion.perfilDemo == perfil,
                            onSelected: (_) => sesion.elegir(perfil),
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: LayoutMetrics.space32),
                ],
                if (sesion.perfil.esAdministrador)
                  ListTile(
                    minTileHeight: LayoutMetrics.minTouchTarget,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: const Text('Panel de moderación'),
                    subtitle: const Text('Reportes activos, bloquear autores y alertas oficiales'),
                    onTap: () => context.push(Rutas.admin),
                  ),
                if (sesion.cuenta != null)
                  ListTile(
                    minTileHeight: LayoutMetrics.minTouchTarget,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.logout),
                    title: const Text('Cerrar sesión'),
                    subtitle: Text(sesion.cuenta!.correoEnmascarado),
                    onTap: () async {
                      await ref.read(authRepositoryProvider).cerrarSesion();
                      if (context.mounted) context.go(Rutas.mapa);
                    },
                  )
                else if (sesion.perfil.esInvitado)
                  ListTile(
                    minTileHeight: LayoutMetrics.minTouchTarget,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.login),
                    title: const Text('Iniciar sesión / Registrarme'),
                    subtitle: const Text('Con tu cuenta institucional puedes reportar y guardar tu horario'),
                    onTap: () => context.push(Rutas.acceso),
                  ),
                ListTile(
                  minTileHeight: LayoutMetrics.minTouchTarget,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Mi horario'),
                  subtitle: const Text('Se guarda solo en este dispositivo'),
                  trailing: bloqueadoHorario ? const Icon(Icons.lock_outline) : null,
                  onTap: () async {
                    if (await verificarAccion(context, ref, AccionProtegida.guardarHorario) &&
                        context.mounted) {
                      context.push('/horario');
                    }
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.my_location),
                  title: const Text('Ubicación (GPS)'),
                  subtitle: const Text('Pausa o revoca el uso de tu ubicación cuando quieras'),
                  value: consentimiento.estado.gpsActivo,
                  onChanged: (valor) => _alternarGps(context, ref, valor),
                ),
                const Divider(height: LayoutMetrics.space32),
                Text('PontiMaps · La Pontimaps', style: textTheme.titleMedium),
                const SizedBox(height: LayoutMetrics.space8),
                Text(
                  enDemo ? 'Modo demostración sin conexión.' : 'Conectado a Firebase.',
                  style: textTheme.bodyMedium,
                ),
                Text(CampusCartography.atribucion, style: textTheme.bodySmall),
              ],
            );
          },
        ),
      ),
    );
  }
}
