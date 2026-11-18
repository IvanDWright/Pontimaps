import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/providers.dart';
import 'package:pontimaps_app/core/theme/pontimaps_theme.dart';
import 'package:pontimaps_app/data/admin_repository.dart';
import 'package:pontimaps_app/data/official_alerts_repository.dart';
import 'package:pontimaps_app/domain/services/moderation_service.dart';
import 'package:pontimaps_app/models/reporte_comunidad.dart';
import 'package:pontimaps_app/presentation/widgets/report_detail_sheet.dart';
import 'package:pontimaps_app/presentation/widgets/report_modal_sheet.dart';

/// Panel de moderación (solo `rol == 'admin'`):
///
/// 1. lista en tiempo real de los reportes activos con **«Eliminar reporte»** y
///    **«Bloquear autor»** (la cuenta queda como Visitante en solo lectura);
/// 2. formulario para publicar **alertas oficiales** fijas, que no expiran hasta
///    que el administrador las cierra.
///
/// La pantalla **nunca** muestra el `authorHash` ni la identidad de nadie. Que
/// solo un administrador pueda hacer estas acciones lo garantizan las reglas de
/// Firestore; ocultar el panel a los demás es solo comodidad.
class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> {
  final TextEditingController _mensaje = TextEditingController();
  String? _idEdificio;

  @override
  void dispose() {
    _mensaje.dispose();
    super.dispose();
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  static String _textoResultado(ResultadoModeracion r, {required String exito}) {
    switch (r) {
      case ResultadoModeracion.hecho:
        return exito;
      case ResultadoModeracion.noEncontrado:
        return 'Ese reporte ya no existe.';
      case ResultadoModeracion.autorNoEncontrado:
        return 'No se encontró la cuenta del autor.';
      case ResultadoModeracion.sinPermiso:
        return 'Solo un administrador puede hacer esto.';
    }
  }

  Future<bool> _confirmar(String titulo, String texto, String boton) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogo).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(dialogo).pop(true), child: Text(boton)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _eliminar(ReporteComunidad reporte) async {
    if (!await _confirmar(
      'Eliminar reporte',
      'Desaparecerá de todos los mapas al instante.',
      'Eliminar reporte',
    )) {
      return;
    }
    final r = await ref.read(adminRepositoryProvider).eliminarReporte(reporte.id);
    if (mounted) _avisar(_textoResultado(r, exito: 'Reporte eliminado.'));
  }

  Future<void> _bloquear(ReporteComunidad reporte) async {
    if (!await _confirmar(
      'Bloquear autor',
      'La cuenta que hizo este reporte quedará como Visitante, en solo lectura. '
          'No verás quién es.',
      'Bloquear autor',
    )) {
      return;
    }
    final r = await ref.read(adminRepositoryProvider).bloquearAutor(reporte.id);
    if (mounted) _avisar(_textoResultado(r, exito: 'Autor bloqueado: pasa a modo Visitante.'));
  }

  Future<void> _publicar() async {
    final cartografia = ref.read(cartographyProvider);
    final edificio = _idEdificio == null ? null : cartografia.edificioPorId(_idEdificio!);
    if (edificio == null || _mensaje.text.trim().isEmpty) return;
    try {
      await ref.read(alertsRepositoryProvider).publicar(
            mensaje: _mensaje.text,
            ubicacion: edificio.ubicacion,
          );
      _mensaje.clear();
      if (mounted) {
        setState(() => _idEdificio = null);
        _avisar('Alerta oficial publicada.');
      }
    } catch (_) {
      if (mounted) _avisar('No se pudo publicar la alerta. Inténtalo de nuevo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final sesion = ref.watch(sessionProvider);
    final cartografia = ref.watch(cartographyProvider);
    final reloj = ref.watch(clockProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Panel de moderación')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: sesion,
          builder: (context, _) {
            if (!sesion.perfil.esAdministrador) {
              return Padding(
                padding: const EdgeInsets.all(LayoutMetrics.screenMargin),
                child: Text('Este panel es solo para administradores.', style: textTheme.bodyMedium),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(LayoutMetrics.screenMargin),
              children: <Widget>[
                Text('Reportes activos', style: textTheme.titleLarge),
                const SizedBox(height: LayoutMetrics.space8),
                StreamBuilder<List<ReporteComunidad>>(
                  stream: ref.watch(adminRepositoryProvider).reportesActivos(),
                  builder: (context, instantanea) {
                    final ahora = reloj();
                    final lista = <ReporteComunidad>[
                      for (final r in instantanea.data ?? const <ReporteComunidad>[])
                        if (r.estaVigente(ahora)) r,
                    ];
                    if (lista.isEmpty) {
                      return Text('No hay reportes activos.', style: textTheme.bodyMedium);
                    }
                    return Column(
                      children: <Widget>[
                        for (final r in lista)
                          _TarjetaReporte(
                            reporte: r,
                            ahora: ahora,
                            onEliminar: () => _eliminar(r),
                            onBloquear: () => _bloquear(r),
                          ),
                      ],
                    );
                  },
                ),
                const Divider(height: LayoutMetrics.space32),
                Text('Alertas oficiales', style: textTheme.titleLarge),
                const SizedBox(height: LayoutMetrics.space8),
                Text(
                  'Quedan fijas en el mapa hasta que las cierres.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: LayoutMetrics.space16),
                TextField(
                  controller: _mensaje,
                  maxLength: AlertaOficial.maxLongitudMensaje,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Mensaje de la alerta'),
                ),
                const SizedBox(height: LayoutMetrics.space8),
                DropdownButtonFormField<String>(
                  initialValue: _idEdificio,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Zona (edificio)'),
                  items: <DropdownMenuItem<String>>[
                    for (final e in cartografia.edificios)
                      DropdownMenuItem<String>(
                        value: e.id,
                        child: Text('${e.etiqueta} · ${e.nombre}', overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _idEdificio = v),
                ),
                const SizedBox(height: LayoutMetrics.space16),
                FilledButton(
                  onPressed: _idEdificio != null && _mensaje.text.trim().isNotEmpty ? _publicar : null,
                  child: const Text('Publicar alerta oficial'),
                ),
                const SizedBox(height: LayoutMetrics.space16),
                StreamBuilder<List<AlertaOficial>>(
                  stream: ref.watch(alertsRepositoryProvider).observar(),
                  builder: (context, instantanea) {
                    final lista = instantanea.data ?? const <AlertaOficial>[];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (final a in lista)
                          Card(
                            margin: const EdgeInsets.only(bottom: LayoutMetrics.space8),
                            child: Padding(
                              padding: const EdgeInsets.all(LayoutMetrics.space16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(a.mensaje, style: textTheme.titleMedium),
                                  const SizedBox(height: LayoutMetrics.space8),
                                  OutlinedButton(
                                    onPressed: () => ref.read(alertsRepositoryProvider).cerrar(a.id),
                                    child: const Text('Cerrar alerta'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TarjetaReporte extends StatelessWidget {
  const _TarjetaReporte({
    required this.reporte,
    required this.ahora,
    required this.onEliminar,
    required this.onBloquear,
  });

  final ReporteComunidad reporte;
  final DateTime ahora;
  final VoidCallback onEliminar;
  final VoidCallback onBloquear;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      color: PontiMapsTheme.surface,
      margin: const EdgeInsets.only(bottom: LayoutMetrics.space8),
      child: Padding(
        padding: const EdgeInsets.all(LayoutMetrics.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(reporte.tipo.icono, color: PontiMapsTheme.primary),
                const SizedBox(width: LayoutMetrics.space8),
                Expanded(child: Text(reporte.tipo.etiqueta, style: textTheme.titleMedium)),
              ],
            ),
            Text(
              'Hace ${formatoDuracion(ahora.difference(reporte.creadoEn))} · '
              'vence en ${formatoDuracion(ModerationService.tiempoRestante(reporte, ahora))}',
              style: textTheme.bodyMedium,
            ),
            Text(
              '${reporte.confirmaciones} confirmaciones · ${reporte.reportesNegativos} votos «Falso»',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: LayoutMetrics.space8),
            Wrap(
              spacing: LayoutMetrics.space8,
              runSpacing: LayoutMetrics.space8,
              children: <Widget>[
                OutlinedButton(onPressed: onEliminar, child: const Text('Eliminar reporte')),
                OutlinedButton(onPressed: onBloquear, child: const Text('Bloquear autor')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
