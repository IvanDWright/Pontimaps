import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/theme/pontimaps_theme.dart';

/// Marca gráfica de PontiMaps (logo del mockup): cuadrado dorado con el mapa.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = LayoutMetrics.heroMarkSize});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: PontiMapsTheme.accent,
          borderRadius: BorderRadius.circular(size / 3),
        ),
        child: Icon(
          Icons.map_outlined,
          size: size / 2,
          color: PontiMapsTheme.onAccent,
        ),
      ),
    );
  }
}
