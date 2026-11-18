import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/theme/pontimaps_theme.dart';
import 'package:pontimaps_app/data/map_sdk_adapter.dart';
import 'package:pontimaps_app/domain/services/congestion_service.dart';
import 'package:pontimaps_app/models/negocio_servicio.dart';

/// Leyenda de la capa de congestión: Baja · Media · Alta (color **más** texto,
/// WCAG 1.4.1) y el nivel de cada zona. Sin datos, dice «Sin datos recientes».
class CongestionLegend extends StatelessWidget {
  const CongestionLegend({super.key, required this.zonas});

  final List<CongestionZona> zonas;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final altoMaximo = MediaQuery.sizeOf(context).height * 0.3;
    return Material(
      color: PontiMapsTheme.surface,
      elevation: 4,
      borderRadius: BorderRadius.circular(LayoutMetrics.radiusCard),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: altoMaximo),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(LayoutMetrics.space16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Congestión por zonas', style: textTheme.titleMedium),
              const SizedBox(height: LayoutMetrics.space8),
              Wrap(
                spacing: LayoutMetrics.space16,
                runSpacing: LayoutMetrics.space8,
                children: <Widget>[
                  for (final nivel in NivelCongestion.values)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: LayoutMetrics.space16,
                          height: LayoutMetrics.space16,
                          decoration: BoxDecoration(
                            color: CampusMapView.colorNivel(nivel).withValues(alpha: 0.28),
                            border: Border.all(color: CampusMapView.colorNivel(nivel), width: 2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: LayoutMetrics.space8),
                        Text(CongestionService.etiquetaNivel(nivel), style: textTheme.bodyMedium),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: LayoutMetrics.space8),
              for (final z in zonas)
                Text('${z.zona.nombre}: ${z.etiqueta}', style: textTheme.bodySmall),
              const SizedBox(height: LayoutMetrics.space8),
              Text(
                'Calculada solo con reportes anónimos vigentes.',
                style: textTheme.bodySmall?.copyWith(color: PontiMapsTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
