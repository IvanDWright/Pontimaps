import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/theme/pontimaps_theme.dart';

/// Chip «Mi próxima clase» del mapa: acceso de **1 toque** (RF-HOR-04). Con
/// [bloqueado] (visitante o cuenta sin verificar) muestra un candado y, al
/// tocarlo, el Auth Guard abre el modal bloqueante.
class NextClassChip extends StatelessWidget {
  const NextClassChip({
    super.key,
    required this.bloqueado,
    required this.onTap,
    this.compacto = false,
    this.hora,
  });

  final bool bloqueado;
  final VoidCallback onTap;

  /// Con texto muy grande (> 130 %) muestra solo icono, «Próx. clase» y la hora,
  /// para dejar libre el mapa.
  final bool compacto;

  /// Hora de inicio de la próxima clase (`HH:mm`), si se conoce.
  final String? hora;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: LayoutMetrics.minTouchTarget),
      child: ActionChip(
        onPressed: onTap,
        avatar: Icon(
          bloqueado ? Icons.lock_outline : Icons.schedule,
          size: 24,
          color: PontiMapsTheme.primary,
        ),
        label: Text(compacto ? 'Próx. clase${hora == null ? '' : ' $hora'}' : 'Mi próxima clase'),
        backgroundColor: PontiMapsTheme.accentContainer,
        side: const BorderSide(color: PontiMapsTheme.accent),
      ),
    );
  }
}
