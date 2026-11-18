import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/providers.dart';
import 'package:pontimaps_app/domain/services/auth_guard.dart';
import 'package:pontimaps_app/domain/services/moderation_service.dart';
import 'package:pontimaps_app/models/negocio_servicio.dart';
import 'package:pontimaps_app/models/reporte_comunidad.dart';
import 'package:pontimaps_app/presentation/widgets/report_modal_sheet.dart';
import 'package:pontimaps_app/presentation/widgets/restricted_action_dialog.dart';

void _aviso(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

String _mensajeVoto(ResultadoVoto resultado, VotoReporte voto) {
  switch (resultado) {
    case ResultadoVoto.registrado:
      return voto == VotoReporte.sigueAhi
          ? 'Gracias. El reporte seguirá visible más tiempo.'
          : 'Gracias. Registramos que ya no está.';
    case ResultadoVoto.noVigente:
      return 'Este reporte ya no está activo.';
    case ResultadoVoto.esAutor:
      return 'No puedes calificar tu propio reporte.';
    case ResultadoVoto.yaVoto:
      return 'Ya calificaste este reporte.';
  }
}

/// Califica [reporte] con [voto]: pasa por el Auth Guard (un visitante ve el
/// modal bloqueante) y luego por el repositorio (un voto por cuenta y reporte; el
/// autor no vota el suyo). Devuelve `true` si el voto quedó registrado.
Future<bool> votarReporte(
  BuildContext context,
  WidgetRef ref, {
  required ReporteComunidad reporte,
  required VotoReporte voto,
}) async {
  if (!await verificarAccion(context, ref, AccionProtegida.calificarReporte)) return false;
  final hash = ref.read(sessionProvider).perfil.authorHash;
  if (hash == null || !context.mounted) return false;
  final resultado = await ref.read(reportsRepositoryProvider).calificar(
        idReporte: reporte.id,
        votanteHash: hash,
        voto: voto,
      );
  if (context.mounted) _aviso(context, _mensajeVoto(resultado, voto));
  return resultado == ResultadoVoto.registrado;
}

/// Flujo de publicar un reporte (Path 3).
///
/// 1. Auth Guard: un visitante ve el modal bloqueante (S10) y no se envía nada.
/// 2. Modal con las tres opciones (icono + etiqueta); con [lugar] la opción
///    «Fila larga» llega preseleccionada (Path 4, «Reportar fila»).
/// 3. El punto se ajusta **en el dispositivo** a la arista más cercana
///    (`aristaMasCercana`, ≤ 30 m): se guarda el centro del tramo, no la posición
///    del usuario, y nada queda ligado a su identidad.
/// 4. Si ya hay un reporte igual en el tramo o lugar, se ofrece confirmarlo.
///
/// [origenAproximado] es la posición (GPS u origen manual) con la que se ubica el
/// tramo cuando el reporte no es de un [lugar].
Future<void> iniciarFlujoReporte(
  BuildContext context,
  WidgetRef ref, {
  LatLng? origenAproximado,
  NegocioServicio? lugar,
}) async {
  final accion = lugar == null ? AccionProtegida.crearReporte : AccionProtegida.reportarFila;
  if (!await verificarAccion(context, ref, accion)) return;
  if (!context.mounted) return;

  final tipo = await mostrarReporteModal(
    context,
    preseleccionado: lugar == null ? null : TipoReporte.fila,
  );
  if (tipo == null || !context.mounted) return;

  final grafo = ref.read(cartographyProvider).grafo;
  final LatLng punto;
  final String? idArista;
  if (lugar != null) {
    punto = lugar.ubicacion;
    idArista = grafo.aristaMasCercana(punto)?.id;
  } else {
    if (origenAproximado == null) {
      _aviso(
        context,
        'Sin ubicación: mantén pulsado el mapa sobre el tramo y vuelve a reportar.',
      );
      return;
    }
    final arista = grafo.aristaMasCercana(origenAproximado);
    final a = arista == null ? null : grafo.nodoPorId(arista.origenId);
    final b = arista == null ? null : grafo.nodoPorId(arista.destinoId);
    if (arista == null || a == null || b == null) {
      _aviso(context, 'Acércate a un sendero para reportar.');
      return;
    }
    idArista = arista.id;
    punto = LatLng(
      (a.ubicacion.latitude + b.ubicacion.latitude) / 2,
      (a.ubicacion.longitude + b.ubicacion.longitude) / 2,
    );
  }

  final hash = ref.read(sessionProvider).perfil.authorHash;
  if (hash == null) return;
  final resultado = await ref.read(reportsRepositoryProvider).publicar(
        tipo: tipo,
        ubicacion: punto,
        autorHash: hash,
        idArista: idArista,
        idLugar: lugar?.id,
      );
  if (!context.mounted) return;

  switch (resultado.resultado) {
    case ResultadoPublicacion.publicado:
      _aviso(context, 'Reporte publicado: ${tipo.etiqueta}.');
    case ResultadoPublicacion.demasiadoPronto:
      _aviso(context, 'Espera un momento antes de reportar de nuevo.');
    case ResultadoPublicacion.duplicado:
      final existente = resultado.duplicado;
      if (existente == null) return;
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (dialogo) => AlertDialog(
          title: const Text('Ya estaba reportado'),
          content: Text('Hay un reporte de «${tipo.etiqueta}» en este tramo. ¿Quieres confirmarlo?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogo).pop(false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogo).pop(true),
              child: const Text('Sigue ahí'),
            ),
          ],
        ),
      );
      if (confirmar == true && context.mounted) {
        final voto = await ref.read(reportsRepositoryProvider).calificar(
              idReporte: existente.id,
              votanteHash: hash,
              voto: VotoReporte.sigueAhi,
            );
        if (context.mounted) _aviso(context, _mensajeVoto(voto, VotoReporte.sigueAhi));
      }
  }
}
