import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/theme/pontimaps_theme.dart';
import 'package:pontimaps_app/data/campus_cartography.dart';
import 'package:pontimaps_app/domain/search/campus_search.dart';
import 'package:pontimaps_app/models/edificio.dart';
import 'package:pontimaps_app/models/negocio_servicio.dart';
import 'package:pontimaps_app/models/ruta_calculada.dart';
import 'package:pontimaps_app/models/salon.dart';

/// Lugar elegido como destino: un edificio, un salón o un servicio.
class DestinoSeleccionado {
  const DestinoSeleccionado({
    required this.idRuta,
    required this.titulo,
    required this.ubicacionEtiqueta,
    required this.punto,
    this.edificio,
    this.salon,
    this.negocio,
    this.piso,
    this.detalle,
  });

  /// Edificio de un salón: `Edificio X · Piso Y` (sótano explícito si `piso < 0`).
  /// [detalle] añade contexto, p. ej. la materia y la hora de «Mi próxima clase».
  factory DestinoSeleccionado.deSalon(Salon salon, Edificio edificio, {String? detalle}) {
    return DestinoSeleccionado(
      idRuta: edificio.id,
      titulo: 'Salón ${salon.codigo}',
      ubicacionEtiqueta: etiquetaSalon(salon),
      punto: edificio.ubicacion,
      edificio: edificio,
      salon: salon,
      piso: salon.piso,
      detalle: detalle,
    );
  }

  factory DestinoSeleccionado.deEdificio(Edificio edificio) {
    return DestinoSeleccionado(
      idRuta: edificio.id,
      titulo: edificio.nombre,
      ubicacionEtiqueta: edificio.etiqueta,
      punto: edificio.ubicacion,
      edificio: edificio,
    );
  }

  factory DestinoSeleccionado.deNegocio(
    NegocioServicio negocio,
    CampusCartography cartografia,
  ) {
    return DestinoSeleccionado(
      idRuta: cartografia.idDestinoRuta(negocio),
      titulo: negocio.nombre,
      ubicacionEtiqueta: cartografia.etiquetaUbicacion(negocio),
      punto: negocio.ubicacion,
      edificio: negocio.dentroDeEdificio
          ? cartografia.edificioPorId(negocio.idEdificioCercano)
          : null,
      negocio: negocio,
      piso: negocio.dentroDeEdificio ? negocio.piso : null,
    );
  }

  /// Id con el que se pide la ruta (un edificio o un servicio independiente).
  final String idRuta;
  final String titulo;

  /// `Edificio X · Piso Y` para un salón; `Edificio X` para un edificio.
  final String ubicacionEtiqueta;
  final LatLng punto;
  final Edificio? edificio;
  final Salon? salon;
  final NegocioServicio? negocio;
  final int? piso;

  /// Línea de contexto opcional (materia, hora y cuándo, en «Mi próxima clase»).
  final String? detalle;

  /// Etiqueta de accesibilidad vertical (ascensor, múltiples ascensores,
  /// sótano o solo escaleras internas). Para un edificio sin piso concreto se
  /// informa el acceso a los pisos altos.
  String? get etiquetaAccesibilidad {
    final e = edificio;
    if (e == null) return null;
    final p = piso;
    if (p != null) return e.etiquetaAccesibilidadVertical(p);
    if ((e.niveles ?? 1) > 1) {
      return 'Pisos altos · ${e.etiquetaAccesibilidadVertical(2)}';
    }
    return null;
  }
}

/// Vista previa de la ruta hacia el destino elegido (antes de tocar «Ir»).
sealed class VistaPreviaRuta {
  const VistaPreviaRuta();
}

class PreviaRuta extends VistaPreviaRuta {
  const PreviaRuta(this.ruta);

  final RutaCalculada ruta;
}

class PreviaError extends VistaPreviaRuta {
  const PreviaError(this.mensaje);

  final String mensaje;
}

/// No hay GPS ni origen manual: la distancia y el tiempo aún no se conocen.
class PreviaSinOrigen extends VistaPreviaRuta {
  const PreviaSinOrigen();
}

/// Texto de «distancia · tiempo» de una ruta (`320 m · 5 min`).
String resumenDistanciaTiempo(RutaCalculada ruta) =>
    '${ruta.distanciaMetros.round()} m · ${formatoMinutos(ruta.tiempoEstimadoMinutos)}';

String formatoMinutos(int minutos) => minutos < 1 ? '< 1 min' : '$minutos min';

/// Hoja inferior del destino (toque 2): nombre oficial, `Edificio X · Piso Y`,
/// distancia y tiempo estimados, accesibilidad vertical, «Evitar escaleras» y el
/// único botón **«Ir»** (toque 3). El botón queda fijo, visible sin desplazarse
/// aunque el texto esté al 200 %.
class BuildingDetailSheet extends StatelessWidget {
  const BuildingDetailSheet({
    super.key,
    required this.destino,
    required this.vistaPrevia,
    required this.evitarEscaleras,
    required this.onEvitarEscaleras,
    required this.onIr,
    required this.onCerrar,
    this.onElegirOrigen,
  });

  final DestinoSeleccionado destino;
  final VistaPreviaRuta vistaPrevia;
  final bool evitarEscaleras;
  final ValueChanged<bool> onEvitarEscaleras;
  final VoidCallback onIr;
  final VoidCallback onCerrar;
  final VoidCallback? onElegirOrigen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accesibilidad = destino.etiquetaAccesibilidad;
    final altoMaximo = MediaQuery.sizeOf(context).height * 0.5;
    final previa = vistaPrevia;
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Text(destino.titulo, style: textTheme.titleLarge),
                          ),
                          IconButton(
                            tooltip: 'Cerrar',
                            icon: const Icon(Icons.close),
                            onPressed: onCerrar,
                          ),
                        ],
                      ),
                      if (destino.detalle != null)
                        Text(destino.detalle!, style: textTheme.bodyMedium),
                      Text(destino.ubicacionEtiqueta, style: textTheme.titleMedium),
                      if (accesibilidad != null) ...<Widget>[
                        const SizedBox(height: LayoutMetrics.space8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(
                              Icons.elevator_outlined,
                              size: 24,
                              color: PontiMapsTheme.primary,
                            ),
                            const SizedBox(width: LayoutMetrics.space8),
                            Expanded(child: Text(accesibilidad, style: textTheme.bodyMedium)),
                          ],
                        ),
                      ],
                      const SizedBox(height: LayoutMetrics.space8),
                      _ResumenPrevio(previa: previa, onElegirOrigen: onElegirOrigen),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Evitar escaleras'),
                        value: evitarEscaleras,
                        onChanged: onEvitarEscaleras,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: LayoutMetrics.space8),
              FilledButton(
                onPressed: previa is PreviaError ? null : onIr,
                child: const Text('Ir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumenPrevio extends StatelessWidget {
  const _ResumenPrevio({required this.previa, this.onElegirOrigen});

  final VistaPreviaRuta previa;
  final VoidCallback? onElegirOrigen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = previa;
    switch (p) {
      case PreviaRuta():
        final advertencia = p.ruta.accesoVertical?.advertencia;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(resumenDistanciaTiempo(p.ruta), style: textTheme.titleLarge),
            if (advertencia != null) ...<Widget>[
              const SizedBox(height: LayoutMetrics.space8),
              _Aviso(texto: advertencia),
            ],
          ],
        );
      case PreviaError():
        return _Aviso(texto: p.mensaje);
      case PreviaSinOrigen():
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Elige tu punto de partida para ver la distancia y el tiempo.',
              style: textTheme.bodyMedium,
            ),
            if (onElegirOrigen != null)
              TextButton(
                onPressed: onElegirOrigen,
                child: const Text('Elegir punto de partida'),
              ),
          ],
        );
    }
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LayoutMetrics.space8),
      decoration: BoxDecoration(
        color: PontiMapsTheme.accentContainer,
        borderRadius: BorderRadius.circular(LayoutMetrics.radiusControl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline, size: 24, color: PontiMapsTheme.warningText),
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
