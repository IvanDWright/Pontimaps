import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/theme/pontimaps_theme.dart';
import 'package:pontimaps_app/data/official_alerts_repository.dart';

/// Detalle de una alerta oficial: un aviso fijo del equipo de la Universidad.
class OfficialAlertSheet extends StatelessWidget {
  const OfficialAlertSheet({super.key, required this.alerta, required this.onCerrar});

  final AlertaOficial alerta;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final altoMaximo = MediaQuery.sizeOf(context).height * 0.4;
    return Material(
      color: PontiMapsTheme.surface,
      elevation: 8,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(LayoutMetrics.radiusSheet),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: altoMaximo),
        child: Padding(
          padding: const EdgeInsets.all(LayoutMetrics.screenMargin),
          child: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.campaign, color: PontiMapsTheme.primary),
                const SizedBox(width: LayoutMetrics.space8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Alerta oficial', style: textTheme.titleLarge),
                      Text(alerta.mensaje, style: textTheme.bodyMedium),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close),
                  onPressed: onCerrar,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
