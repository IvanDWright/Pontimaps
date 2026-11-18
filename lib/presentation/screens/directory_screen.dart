import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/providers.dart';
import 'package:pontimaps_app/core/theme/pontimaps_theme.dart';
import 'package:pontimaps_app/data/places_repository.dart';
import 'package:pontimaps_app/domain/services/auth_guard.dart';
import 'package:pontimaps_app/domain/services/opening_hours.dart';
import 'package:pontimaps_app/models/negocio_servicio.dart';
import 'package:pontimaps_app/models/reporte_comunidad.dart';
import 'package:pontimaps_app/presentation/report_flow.dart';
import 'package:pontimaps_app/presentation/widgets/building_detail_sheet.dart';
import 'package:pontimaps_app/presentation/widgets/restricted_action_dialog.dart';

/// Texto de cada categoría del catálogo.
String etiquetaCategoria(CategoriaServicio categoria) {
  switch (categoria) {
    case CategoriaServicio.cafeteria:
      return 'Cafetería';
    case CategoriaServicio.papeleria:
      return 'Papelería';
    case CategoriaServicio.atencionEstudiante:
      return 'Atención al estudiante';
    case CategoriaServicio.bienestar:
      return 'Bienestar';
    case CategoriaServicio.comercioAliado:
      return 'Comercio aliado';
    case CategoriaServicio.biblioteca:
      return 'Biblioteca';
    case CategoriaServicio.salud:
      return 'Salud';
  }
}

/// Directorio de servicios del campus (S21): cafeterías, papelerías, atención,
/// bienestar y comercios aliados, con su estado de apertura (texto + color,
/// WCAG 1.4.1), el nivel de fila vigente y los botones «Ir» y «Reportar fila».
///
/// Funciona sin red: los lugares salen del catálogo local y el estado de
/// apertura se calcula en hora de Colombia.
class DirectoryScreen extends ConsumerStatefulWidget {
  const DirectoryScreen({super.key});

  @override
  ConsumerState<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends ConsumerState<DirectoryScreen> {
  FiltroDirectorio _filtro = FiltroDirectorio.todos;
  List<ReporteComunidad> _reportes = const <ReporteComunidad>[];
  StreamSubscription<List<ReporteComunidad>>? _suscripcion;
  Timer? _temporizador;

  @override
  void initState() {
    super.initState();
    final repositorio = ref.read(reportsRepositoryProvider);
    _reportes = repositorio.vigentes();
    _suscripcion = repositorio.observar().listen((lista) {
      if (mounted) setState(() => _reportes = lista);
    });
    // El estado de apertura cambia con el reloj: se reevalúa cada 30 s.
    _temporizador = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    _suscripcion?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cartografia = ref.watch(cartographyProvider);
    final lugares = ref.watch(placesRepositoryProvider).lugares(
          filtro: _filtro,
          ahora: ref.watch(clockProvider)(),
          reportes: _reportes,
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Directorio')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(LayoutMetrics.screenMargin),
              child: Wrap(
                spacing: LayoutMetrics.space8,
                runSpacing: LayoutMetrics.space8,
                children: <Widget>[
                  for (final filtro in FiltroDirectorio.values)
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: LayoutMetrics.minTouchTarget),
                      child: ChoiceChip(
                        label: Text(filtro.etiqueta),
                        selected: _filtro == filtro,
                        onSelected: (_) => setState(() => _filtro = filtro),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: lugares.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(LayoutMetrics.screenMargin),
                      child: Text(
                        'Aún no hay lugares de esta categoría en el catálogo local.',
                        style: textTheme.bodyMedium,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        LayoutMetrics.screenMargin,
                        0,
                        LayoutMetrics.screenMargin,
                        LayoutMetrics.screenMargin,
                      ),
                      itemCount: lugares.length,
                      separatorBuilder: (_, _) => const SizedBox(height: LayoutMetrics.space8),
                      itemBuilder: (context, i) => _TarjetaLugar(
                        lugar: lugares[i],
                        bloqueadoReportar: accionBloqueada(ref, AccionProtegida.reportarFila),
                        onIr: () => ref
                            .read(shellControllerProvider)
                            .irAlMapaCon(DestinoSeleccionado.deNegocio(lugares[i].negocio, cartografia)),
                        onReportarFila: () =>
                            iniciarFlujoReporte(context, ref, lugar: lugares[i].negocio),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaLugar extends StatelessWidget {
  const _TarjetaLugar({
    required this.lugar,
    required this.bloqueadoReportar,
    required this.onIr,
    required this.onReportarFila,
  });

  final LugarDirectorio lugar;
  final bool bloqueadoReportar;
  final VoidCallback onIr;
  final VoidCallback onReportarFila;

  static Color _color(EstadoApertura estado) {
    switch (estado) {
      case EstadoApertura.abierto:
        return PontiMapsTheme.success;
      case EstadoApertura.cierraPronto:
        return PontiMapsTheme.warningText;
      case EstadoApertura.cerrado:
        return PontiMapsTheme.error;
    }
  }

  static IconData _icono(EstadoApertura estado) {
    switch (estado) {
      case EstadoApertura.abierto:
        return Icons.check_circle_outline;
      case EstadoApertura.cierraPronto:
        return Icons.schedule;
      case EstadoApertura.cerrado:
        return Icons.cancel_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final negocio = lugar.negocio;
    final horario = lugar.horario;
    final color = _color(horario.estado);
    return Card(
      color: PontiMapsTheme.surface,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(LayoutMetrics.screenMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(negocio.nombre, style: textTheme.titleMedium),
            Text(
              '${etiquetaCategoria(negocio.categoria)} · ${lugar.ubicacionEtiqueta}',
              style: textTheme.bodyMedium,
            ),
            if (lugar.esAliado)
              Text(
                'Aliado',
                style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            const SizedBox(height: LayoutMetrics.space8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(_icono(horario.estado), size: 24, color: color),
                const SizedBox(width: LayoutMetrics.space8),
                Expanded(
                  child: Text(
                    '${horario.etiqueta} · ${horario.detalle}',
                    style: textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            if (!negocio.horarioConfirmado)
              Text('Horario sin confirmar', style: textTheme.bodySmall),
            const SizedBox(height: LayoutMetrics.space8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(
                  Icons.format_list_numbered,
                  size: 24,
                  color: PontiMapsTheme.textSecondary,
                ),
                const SizedBox(width: LayoutMetrics.space8),
                Expanded(child: Text(lugar.etiquetaFila, style: textTheme.bodyMedium)),
              ],
            ),
            const SizedBox(height: LayoutMetrics.space8),
            Wrap(
              spacing: LayoutMetrics.space8,
              runSpacing: LayoutMetrics.space8,
              children: <Widget>[
                FilledButton(onPressed: onIr, child: const Text('Ir')),
                OutlinedButton.icon(
                  onPressed: onReportarFila,
                  icon: Icon(bloqueadoReportar ? Icons.lock_outline : Icons.campaign_outlined),
                  label: const Text('Reportar fila'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
