import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/theme/pontimaps_theme.dart';
import 'package:pontimaps_app/domain/services/departure_planner.dart';
import 'package:pontimaps_app/models/horario_usuario.dart';

/// Aviso de hora de salida (RF-HOR-05): «Sal en 4 min hacia Edificio 67 · Piso 2»
/// con el botón **«Iniciar ruta»**. Es el respaldo dentro de la app cuando no hay
/// notificaciones del sistema.
class DepartureAlertBanner extends StatelessWidget {
  const DepartureAlertBanner({
    super.key,
    required this.alerta,
    required this.ahora,
    required this.onIniciarRuta,
    required this.onCerrar,
  });

  final AlertaSalida alerta;

  /// «Ahora» en hora de Bogotá.
  final DateTime ahora;
  final VoidCallback onIniciarRuta;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final clase = alerta.proxima.bloque;
    final altoMaximo = MediaQuery.sizeOf(context).height * 0.4;
    return Material(
      color: PontiMapsTheme.accentContainer,
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.directions_walk, color: PontiMapsTheme.primary),
                      const SizedBox(width: LayoutMetrics.space8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(alerta.texto(ahora), style: textTheme.titleMedium),
                            Text(
                              '${clase.materia} · ${BloqueHorario.formatoHora(clase.horaInicio)} · '
                              'ruta ${alerta.duracionRuta.inMinutes} min + '
                              '${alerta.margen.inMinutes} min de margen',
                              style: textTheme.bodyMedium,
                            ),
                            Text(alerta.proxima.estado, style: textTheme.bodySmall),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar aviso',
                        icon: const Icon(Icons.close),
                        onPressed: onCerrar,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: LayoutMetrics.space8),
              FilledButton(onPressed: onIniciarRuta, child: const Text('Iniciar ruta')),
            ],
          ),
        ),
      ),
    );
  }
}
