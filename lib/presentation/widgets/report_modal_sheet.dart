import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/theme/pontimaps_theme.dart';
import 'package:pontimaps_app/models/reporte_comunidad.dart';

/// Etiqueta de texto e icono de cada tipo de reporte. Los iconos **siempre** van
/// acompañados de su etiqueta visible; no hay texto libre.
extension TipoReporteUi on TipoReporte {
  String get etiqueta {
    switch (this) {
      case TipoReporte.cierre:
        return 'Cierre de paso';
      case TipoReporte.fila:
        return 'Fila larga';
      case TipoReporte.altaAfluencia:
        return 'Alta afluencia';
    }
  }

  IconData get icono {
    switch (this) {
      case TipoReporte.cierre:
        return Icons.block;
      case TipoReporte.fila:
        return Icons.format_list_numbered;
      case TipoReporte.altaAfluencia:
        return Icons.groups;
    }
  }

  /// Color del pin en el mapa (con su icono, nunca solo color).
  Color get colorFondo {
    switch (this) {
      case TipoReporte.cierre:
        return PontiMapsTheme.error;
      case TipoReporte.fila:
        return PontiMapsTheme.accent;
      case TipoReporte.altaAfluencia:
        return PontiMapsTheme.warningText;
    }
  }

  Color get colorIcono =>
      this == TipoReporte.fila ? PontiMapsTheme.onAccent : PontiMapsTheme.onPrimary;
}

/// Modal de reporte (S18): exactamente tres opciones, cada una con icono y
/// etiqueta, de 48 dp o más. Sin campo de texto libre (RF-REP-12).
///
/// Sin [preseleccionado], tocar una opción publica de inmediato (toque 2 del
/// flujo). Con una opción preseleccionada (p. ej. «Fila larga» desde la ficha de
/// un lugar) se confirma con el botón «Publicar reporte».
///
/// Devuelve el [TipoReporte] elegido, o `null` si se cierra sin elegir.
Future<TipoReporte?> mostrarReporteModal(
  BuildContext context, {
  TipoReporte? preseleccionado,
}) {
  return showModalBottomSheet<TipoReporte>(
    context: context,
    isScrollControlled: true,
    backgroundColor: PontiMapsTheme.surface,
    builder: (_) => ReportModalSheet(preseleccionado: preseleccionado),
  );
}

class ReportModalSheet extends StatefulWidget {
  const ReportModalSheet({super.key, this.preseleccionado});

  final TipoReporte? preseleccionado;

  @override
  State<ReportModalSheet> createState() => _ReportModalSheetState();
}

class _ReportModalSheetState extends State<ReportModalSheet> {
  TipoReporte? _elegido;

  @override
  void initState() {
    super.initState();
    _elegido = widget.preseleccionado;
  }

  void _tocar(TipoReporte tipo) {
    if (widget.preseleccionado == null) {
      Navigator.of(context).pop(tipo);
    } else {
      setState(() => _elegido = tipo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final confirmar = widget.preseleccionado != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(LayoutMetrics.screenMargin),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Reportar una novedad', style: textTheme.titleLarge),
              const SizedBox(height: LayoutMetrics.space8),
              Text(
                'Es anónimo: nadie verá quién lo publicó. Dura 60 minutos si nadie lo confirma.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: LayoutMetrics.space16),
              for (final tipo in TipoReporte.values) ...<Widget>[
                _OpcionReporte(
                  tipo: tipo,
                  seleccionada: _elegido == tipo,
                  onTap: () => _tocar(tipo),
                ),
                const SizedBox(height: LayoutMetrics.space8),
              ],
              if (confirmar)
                FilledButton(
                  onPressed: _elegido == null ? null : () => Navigator.of(context).pop(_elegido),
                  child: const Text('Publicar reporte'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpcionReporte extends StatelessWidget {
  const _OpcionReporte({
    required this.tipo,
    required this.seleccionada,
    required this.onTap,
  });

  final TipoReporte tipo;
  final bool seleccionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: seleccionada,
      child: Material(
        color: seleccionada ? PontiMapsTheme.accentContainer : PontiMapsTheme.background,
        borderRadius: BorderRadius.circular(LayoutMetrics.radiusCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(LayoutMetrics.radiusCard),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: LayoutMetrics.space48 + 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LayoutMetrics.space16,
                vertical: LayoutMetrics.space8,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: LayoutMetrics.space48,
                    height: LayoutMetrics.space48,
                    decoration: BoxDecoration(
                      color: tipo.colorFondo,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(tipo.icono, color: tipo.colorIcono),
                  ),
                  const SizedBox(width: LayoutMetrics.space16),
                  Expanded(child: Text(tipo.etiqueta, style: textTheme.titleMedium)),
                  if (seleccionada)
                    const Icon(Icons.check_circle, color: PontiMapsTheme.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
