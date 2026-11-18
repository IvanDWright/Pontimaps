import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/theme/pontimaps_theme.dart';
import 'package:pontimaps_app/domain/services/moderation_service.dart';
import 'package:pontimaps_app/models/reporte_comunidad.dart';
import 'package:pontimaps_app/presentation/widgets/report_modal_sheet.dart';

/// Minutos redondeados hacia arriba: `3 min`, o `menos de 1 min`.
String formatoDuracion(Duration duracion) {
  if (duracion <= Duration.zero) return 'menos de 1 min';
  final minutos = (duracion.inSeconds / 60).ceil();
  return '$minutos min';
}

/// Detalle de un reporte (S19), **100 % anónimo**: tipo, hace cuánto se creó,
/// tiempo restante y los botones «Sigue ahí» y «Falso / Ya no está». No muestra
/// nombre, correo, `uid` ni `authorHash`.
///
/// Cualquiera puede ver el detalle; calificar exige cuenta verificada, y quien no
/// la tiene ve los botones con un candado (el modal lo explica al tocarlos).
class ReportDetailSheet extends StatelessWidget {
  const ReportDetailSheet({
    super.key,
    required this.reporte,
    required this.ahora,
    required this.bloqueado,
    required this.onSigueAhi,
    required this.onFalso,
    required this.onCerrar,
  });

  final ReporteComunidad reporte;
  final DateTime ahora;

  /// `true` si el perfil actual no puede calificar (se dibuja un candado).
  final bool bloqueado;
  final VoidCallback onSigueAhi;
  final VoidCallback onFalso;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hace = ahora.difference(reporte.creadoEn);
    final restante = ModerationService.tiempoRestante(reporte, ahora);
    final altoMaximo = MediaQuery.sizeOf(context).height * 0.5;
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: LayoutMetrics.space32,
                            height: LayoutMetrics.space32,
                            decoration: BoxDecoration(
                              color: reporte.tipo.colorFondo,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              reporte.tipo.icono,
                              size: 16,
                              color: reporte.tipo.colorIcono,
                            ),
                          ),
                          const SizedBox(width: LayoutMetrics.space8),
                          Expanded(
                            child: Text(reporte.tipo.etiqueta, style: textTheme.titleLarge),
                          ),
                          IconButton(
                            tooltip: 'Cerrar',
                            icon: const Icon(Icons.close),
                            onPressed: onCerrar,
                          ),
                        ],
                      ),
                      const SizedBox(height: LayoutMetrics.space8),
                      Text(
                        'Reportado hace ${formatoDuracion(hace < Duration.zero ? Duration.zero : hace)}',
                        style: textTheme.bodyMedium,
                      ),
                      Text('Vence en ${formatoDuracion(restante)}', style: textTheme.titleMedium),
                      const SizedBox(height: LayoutMetrics.space8),
                      Text(
                        '${reporte.confirmaciones} confirmaciones · '
                        '${reporte.reportesNegativos} votos «Falso»',
                        style: textTheme.bodySmall,
                      ),
                      Text('Reporte anónimo de la comunidad.', style: textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: LayoutMetrics.space8),
              FilledButton.icon(
                onPressed: onSigueAhi,
                icon: Icon(bloqueado ? Icons.lock_outline : Icons.check),
                label: const Text('Sigue ahí'),
              ),
              const SizedBox(height: LayoutMetrics.space8),
              OutlinedButton.icon(
                onPressed: onFalso,
                icon: Icon(bloqueado ? Icons.lock_outline : Icons.close),
                label: const Text('Falso / Ya no está'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
