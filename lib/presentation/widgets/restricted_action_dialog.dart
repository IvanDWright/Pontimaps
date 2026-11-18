import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/providers.dart';
import 'package:pontimaps_app/core/routing/rutas.dart';
import 'package:pontimaps_app/domain/services/auth_guard.dart';

/// Qué explica el modal según la acción bloqueada.
String _explicacion(AccionProtegida accion) {
  switch (accion) {
    case AccionProtegida.crearReporte:
      return 'Para reportar un cierre, una fila o alta afluencia.';
    case AccionProtegida.calificarReporte:
      return 'Para confirmar o desmentir un reporte de la comunidad.';
    case AccionProtegida.reportarFila:
      return 'Para reportar la fila de este lugar.';
    case AccionProtegida.guardarHorario:
      return 'Para guardar tu horario de clases en este dispositivo.';
    case AccionProtegida.miProximaClase:
      return 'Para ver tu próxima clase y llegar a ella con un toque.';
  }
}

/// Modal bloqueante del Auth Guard: S10 «Necesitas una cuenta institucional
/// verificada» (visitante, sin sesión o bloqueado) o S07 «Verifica tu correo
/// para continuar» (cuenta sin verificar). No se envía nada a ningún servidor.
Future<void> mostrarModalRestriccion(
  BuildContext context,
  WidgetRef ref, {
  required AccionProtegida accion,
  required ResultadoGuard motivo,
}) {
  final enDemo = ref.read(appConfigProvider).useOfflineFallback;
  final verificacion = motivo == ResultadoGuard.requiereVerificacion;
  return showDialog<void>(
    context: context,
    builder: (dialogo) {
      final textTheme = Theme.of(dialogo).textTheme;
      return AlertDialog(
        icon: const Icon(Icons.lock_outline),
        title: Text(
          verificacion
              ? 'Verifica tu correo para continuar'
              : 'Necesitas una cuenta institucional verificada',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(_explicacion(accion), style: textTheme.bodyMedium),
              if (enDemo && !verificacion) ...<Widget>[
                const SizedBox(height: LayoutMetrics.space16),
                Text(
                  'También puedes cambiar el perfil de demostración en Más.',
                  style: textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogo).pop();
              // Visitante o sin sesión: a la puerta de entrada (iniciar sesión o registrarse).
              if (!verificacion) context.push(Rutas.acceso);
            },
            child: Text(verificacion ? 'Entendido' : 'Iniciar sesión / Registrarme'),
          ),
        ],
      );
    },
  );
}

/// Aplica el Auth Guard a [accion] para el perfil actual. Devuelve `true` si la
/// acción puede continuar; si no, muestra el modal bloqueante y devuelve `false`.
Future<bool> verificarAccion(
  BuildContext context,
  WidgetRef ref,
  AccionProtegida accion,
) async {
  final motivo = evaluarAccionDePerfil(ref.read(sessionProvider).perfil, accion);
  if (motivo == ResultadoGuard.permitido) return true;
  await mostrarModalRestriccion(context, ref, accion: accion, motivo: motivo);
  return false;
}

/// `true` si la acción está bloqueada para el perfil actual (se dibuja un candado).
bool accionBloqueada(WidgetRef ref, AccionProtegida accion) =>
    evaluarAccionDePerfil(ref.read(sessionProvider).perfil, accion) !=
    ResultadoGuard.permitido;
