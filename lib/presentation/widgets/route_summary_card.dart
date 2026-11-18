import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/theme/pontimaps_theme.dart';
import 'package:pontimaps_app/models/ruta_calculada.dart';
import 'package:pontimaps_app/presentation/widgets/building_detail_sheet.dart';

/// Tarjeta inferior de la ruta en curso (RF-NAV-03): muestra a la vez la
/// **distancia (m)**, el **tiempo estimado (min)**, el **siguiente tramo** y el
/// botón para detener la ruta. Si el destino solo se alcanza por escaleras y
/// «Evitar escaleras» está activo, muestra la advertencia de accesibilidad.
class RouteSummaryCard extends StatelessWidget {
  const RouteSummaryCard({
    super.key,
    required this.ruta,
    required this.destino,
    required this.siguienteTramo,
    required this.onDetener,
    this.senalDebil = false,
    this.avisoRuta,
  });

  final RutaCalculada ruta;
  final DestinoSeleccionado destino;

  /// Texto de la instrucción que toca recorrer ahora.
  final String siguienteTramo;
  final VoidCallback onDetener;

  /// `true` si la precisión del GPS es peor que 5 m.
  final bool senalDebil;

  /// Aviso cuando un reporte nuevo bloquea el camino y no hay alternativa.
  final String? avisoRuta;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final advertencia = ruta.accesoVertical?.advertencia;
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
                      Text(destino.titulo, style: textTheme.titleMedium),
                      if (destino.detalle != null)
                        Text(destino.detalle!, style: textTheme.bodyMedium),
                      Text(destino.ubicacionEtiqueta, style: textTheme.bodyMedium),
                      const SizedBox(height: LayoutMetrics.space8),
                      Wrap(
                        spacing: LayoutMetrics.space24,
                        runSpacing: LayoutMetrics.space8,
                        children: <Widget>[
                          _Dato(
                            etiqueta: 'Distancia',
                            valor: '${ruta.distanciaMetros.round()} m',
                          ),
                          _Dato(
                            etiqueta: 'Tiempo estimado',
                            valor: formatoMinutos(ruta.tiempoEstimadoMinutos),
                          ),
                        ],
                      ),
                      const SizedBox(height: LayoutMetrics.space8),
                      Text('Siguiente tramo', style: textTheme.bodySmall),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(Icons.turn_right, color: PontiMapsTheme.primary),
                          const SizedBox(width: LayoutMetrics.space8),
                          Expanded(child: Text(siguienteTramo, style: textTheme.titleMedium)),
                        ],
                      ),
                      if (advertencia != null)
                        _Nota(icono: Icons.info_outline, texto: advertencia),
                      if (ruta.tieneDesvioPorReporte)
                        const _Nota(
                          icono: Icons.alt_route,
                          texto: 'Ruta ajustada por un cierre o fila reportados',
                        ),
                      if (avisoRuta != null)
                        _Nota(icono: Icons.warning_amber, texto: avisoRuta!),
                      if (senalDebil)
                        const _Nota(icono: Icons.gps_not_fixed, texto: 'Señal GPS débil'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: LayoutMetrics.space8),
              OutlinedButton(onPressed: onDetener, child: const Text('Detener ruta')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirmación de llegada (S17): recuerda `Edificio X · Piso Y` y el salón.
class ArrivalCard extends StatelessWidget {
  const ArrivalCard({super.key, required this.destino, required this.onListo});

  final DestinoSeleccionado destino;
  final VoidCallback onListo;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: PontiMapsTheme.surface,
      elevation: 8,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(LayoutMetrics.radiusSheet),
      ),
      child: Padding(
        padding: const EdgeInsets.all(LayoutMetrics.screenMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.check_circle, color: PontiMapsTheme.success),
                const SizedBox(width: LayoutMetrics.space8),
                Expanded(child: Text('Llegaste', style: textTheme.titleLarge)),
              ],
            ),
            const SizedBox(height: LayoutMetrics.space8),
            Text(destino.ubicacionEtiqueta, style: textTheme.titleMedium),
            Text(destino.titulo, style: textTheme.bodyMedium),
            const SizedBox(height: LayoutMetrics.space16),
            FilledButton(onPressed: onListo, child: const Text('Listo')),
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(valor, style: textTheme.titleLarge),
        Text(etiqueta, style: textTheme.bodySmall),
      ],
    );
  }
}

class _Nota extends StatelessWidget {
  const _Nota({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: LayoutMetrics.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icono, size: 24, color: PontiMapsTheme.warningText),
          const SizedBox(width: LayoutMetrics.space8),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: PontiMapsTheme.warningText,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
