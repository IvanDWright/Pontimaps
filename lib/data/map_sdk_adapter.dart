import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/theme/pontimaps_theme.dart';
import 'package:pontimaps_app/data/campus_cartography.dart';
import 'package:pontimaps_app/data/official_alerts_repository.dart';
import 'package:pontimaps_app/domain/services/congestion_service.dart';
import 'package:pontimaps_app/models/edificio.dart';
import 'package:pontimaps_app/models/negocio_servicio.dart';
import 'package:pontimaps_app/models/reporte_comunidad.dart';
import 'package:pontimaps_app/presentation/widgets/report_modal_sheet.dart';

/// Adaptador del motor cartográfico (módulo `map_sdk_adapter`): el resto de la
/// app no conoce `flutter_map`. Dibuja el campus de la Javeriana sobre teselas de
/// OpenStreetMap, los pines de edificios y servicios, la posición del usuario o
/// el origen manual y la polilínea de la ruta.
///
/// Mantiene siempre visible la atribución legal de OpenStreetMap (licencia ODbL,
/// RF-MAP-05).
class CampusMapView extends StatelessWidget {
  const CampusMapView({
    super.key,
    required this.cartography,
    required this.controller,
    required this.onEdificioTap,
    required this.onServicioTap,
    this.onReporteTap,
    this.reportes = const <ReporteComunidad>[],
    this.zonasCongestion = const <CongestionZona>[],
    this.alertas = const <AlertaOficial>[],
    this.onAlertaTap,
    this.mostrarCongestion = false,
    this.onLongPress,
    this.ubicacionUsuario,
    this.origenManual,
    this.ruta,
    this.destinoId,
    this.tileProvider,
  });

  final CampusCartography cartography;
  final MapController controller;
  final void Function(Edificio edificio) onEdificioTap;
  final void Function(NegocioServicio negocio) onServicioTap;

  /// Reportes vigentes (vista pública, sin autor) que se dibujan como pines.
  final List<ReporteComunidad> reportes;

  /// Alertas oficiales fijas (sin expiración automática) y su toque.
  final List<AlertaOficial> alertas;
  final void Function(AlertaOficial alerta)? onAlertaTap;

  /// Congestión por zonas (Path 4); solo se dibuja con [mostrarCongestion].
  final List<CongestionZona> zonasCongestion;
  final bool mostrarCongestion;

  /// Se llama al tocar el pin de un reporte (abre su detalle anónimo).
  final void Function(ReporteComunidad reporte)? onReporteTap;

  /// Mantener pulsado el mapa elige un origen manual en ese punto.
  final void Function(LatLng punto)? onLongPress;

  /// Posición del usuario (solo en memoria); `null` sin GPS.
  final LatLng? ubicacionUsuario;

  /// Origen elegido a mano cuando no hay GPS.
  final LatLng? origenManual;

  /// Puntos de la ruta activa o en vista previa.
  final List<LatLng>? ruta;

  /// Id del edificio o servicio destino, para resaltarlo.
  final String? destinoId;

  /// Proveedor de teselas; `null` usa la red. Las pruebas inyectan uno sin red.
  final TileProvider? tileProvider;

  /// Identificador de paquete que OpenStreetMap exige en el `User-Agent`.
  static const String userAgentPackageName = 'co.edu.javeriana.pontimaps_app';

  static const String _plantillaTeselas = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Zoom desde el que se dibujan los pines de servicios (evita saturar el mapa).
  static const double zoomServicios = 17.5;

  /// Centro del campus: el promedio de las ubicaciones de sus edificios.
  static LatLng centroCampus(CampusCartography cartografia) {
    final edificios = cartografia.edificios;
    if (edificios.isEmpty) return const LatLng(4.6285, -74.0645);
    var lat = 0.0;
    var lng = 0.0;
    for (final e in edificios) {
      lat += e.ubicacion.latitude;
      lng += e.ubicacion.longitude;
    }
    return LatLng(lat / edificios.length, lng / edificios.length);
  }

  /// Color del nivel: se usa **junto con** la etiqueta de texto (WCAG 1.4.1).
  static Color colorNivel(NivelCongestion nivel) {
    switch (nivel) {
      case NivelCongestion.baja:
        return PontiMapsTheme.success;
      case NivelCongestion.media:
        return PontiMapsTheme.accent;
      case NivelCongestion.alta:
        return PontiMapsTheme.error;
    }
  }

  /// Círculos translúcidos por zona con dato, más su etiqueta «Zona · Nivel».
  List<Widget> _capasCongestion() {
    final conDato = <CongestionZona>[
      for (final z in zonasCongestion)
        if (z.nivel != null) z,
    ];
    if (conDato.isEmpty) return const <Widget>[];
    return <Widget>[
      CircleLayer(
        circles: <CircleMarker>[
          for (final z in conDato)
            for (final ancla in z.zona.anclas)
              CircleMarker(
                point: ancla,
                radius: z.zona.radioMetros,
                useRadiusInMeter: true,
                color: colorNivel(z.nivel!).withValues(alpha: 0.28),
                borderColor: colorNivel(z.nivel!),
                borderStrokeWidth: 3,
              ),
        ],
      ),
      MarkerLayer(
        markers: <Marker>[
          for (final z in conDato)
            Marker(
              point: z.zona.anclas.first,
              width: 176,
              height: LayoutMetrics.space32,
              child: IgnorePointer(
                child: Semantics(
                  label: 'Congestión ${z.zona.nombre}: ${z.etiqueta}',
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: LayoutMetrics.space8),
                    decoration: BoxDecoration(
                      color: PontiMapsTheme.surface,
                      borderRadius: BorderRadius.circular(LayoutMetrics.radiusControl),
                      border: Border.all(color: colorNivel(z.nivel!), width: 2),
                    ),
                    child: Text(
                      '${z.zona.nombre} · ${z.etiqueta}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(
                        fontSize: PontiMapsTheme.noteSize,
                        fontWeight: FontWeight.w800,
                        color: PontiMapsTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final puntosRuta = ruta;
    return Stack(
      children: <Widget>[
        FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: centroCampus(cartography),
            initialZoom: 17,
            minZoom: 15,
            maxZoom: 19,
            backgroundColor: PontiMapsTheme.infoContainer,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onLongPress: onLongPress == null ? null : (_, punto) => onLongPress!(punto),
          ),
          children: <Widget>[
            TileLayer(
              urlTemplate: _plantillaTeselas,
              userAgentPackageName: userAgentPackageName,
              tileProvider: tileProvider,
              maxNativeZoom: 19,
            ),
            if (mostrarCongestion) ..._capasCongestion(),
            if (puntosRuta != null && puntosRuta.length >= 2)
              PolylineLayer(
                polylines: <Polyline>[
                  Polyline(
                    points: puntosRuta,
                    strokeWidth: 6,
                    color: PontiMapsTheme.accent,
                    borderStrokeWidth: 2,
                    borderColor: PontiMapsTheme.surface,
                  ),
                ],
              ),
            MarkerLayer(
              markers: <Marker>[
                for (final e in cartography.edificios)
                  Marker(
                    point: e.ubicacion,
                    width: LayoutMetrics.minTouchTarget,
                    height: LayoutMetrics.minTouchTarget,
                    child: _PinEdificio(
                      edificio: e,
                      seleccionado: e.id == destinoId,
                      onTap: () => onEdificioTap(e),
                    ),
                  ),
              ],
            ),
            _CapaServicios(
              cartography: cartography,
              destinoId: destinoId,
              onServicioTap: onServicioTap,
            ),
            MarkerLayer(
              markers: <Marker>[
                if (origenManual != null)
                  Marker(
                    point: origenManual!,
                    width: LayoutMetrics.space32,
                    height: LayoutMetrics.space32,
                    child: const _PinOrigen(),
                  ),
                if (ubicacionUsuario != null)
                  Marker(
                    point: ubicacionUsuario!,
                    width: LayoutMetrics.space24,
                    height: LayoutMetrics.space24,
                    child: const _PuntoUsuario(),
                  ),
              ],
            ),
            MarkerLayer(
              markers: <Marker>[
                for (final a in alertas)
                  Marker(
                    point: a.ubicacion,
                    width: LayoutMetrics.minTouchTarget,
                    height: LayoutMetrics.minTouchTarget,
                    child: _PinAlerta(alerta: a, onTap: () => onAlertaTap?.call(a)),
                  ),
                for (final r in reportes)
                  Marker(
                    point: r.ubicacion,
                    width: LayoutMetrics.minTouchTarget,
                    height: LayoutMetrics.minTouchTarget,
                    child: _PinReporte(reporte: r, onTap: () => onReporteTap?.call(r)),
                  ),
              ],
            ),
          ],
        ),
        const Positioned(
          left: 0,
          bottom: 0,
          child: _Atribucion(),
        ),
      ],
    );
  }
}

/// Atribución de OpenStreetMap, siempre visible (ODbL).
class _Atribucion extends StatelessWidget {
  const _Atribucion();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PontiMapsTheme.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: LayoutMetrics.space8,
        vertical: LayoutMetrics.space8,
      ),
      child: Text(
        CampusCartography.atribucion,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _PinEdificio extends StatelessWidget {
  const _PinEdificio({
    required this.edificio,
    required this.seleccionado,
    required this.onTap,
  });

  final Edificio edificio;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final numero = edificio.numero;
    return Semantics(
      button: true,
      label: edificio.numero == null ? edificio.nombre : '${edificio.etiqueta}, ${edificio.nombre}',
      child: InkResponse(
        onTap: onTap,
        radius: LayoutMetrics.space24,
        child: Center(
          child: Container(
            width: seleccionado ? LayoutMetrics.space48 : LayoutMetrics.space32,
            height: seleccionado ? LayoutMetrics.space48 : LayoutMetrics.space32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: seleccionado ? PontiMapsTheme.accent : PontiMapsTheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: PontiMapsTheme.surface, width: 2),
            ),
            child: numero == null
                ? Icon(
                    Icons.account_balance,
                    size: 16,
                    color: seleccionado ? PontiMapsTheme.onAccent : PontiMapsTheme.onPrimary,
                  )
                : Text(
                    '$numero',
                    maxLines: 1,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: PontiMapsTheme.noteSize,
                      fontWeight: FontWeight.w800,
                      color: seleccionado ? PontiMapsTheme.onAccent : PontiMapsTheme.onPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Pines de servicios: solo con zoom cercano para no saturar el mapa.
class _CapaServicios extends StatelessWidget {
  const _CapaServicios({
    required this.cartography,
    required this.destinoId,
    required this.onServicioTap,
  });

  final CampusCartography cartography;
  final String? destinoId;
  final void Function(NegocioServicio negocio) onServicioTap;

  static IconData _icono(CategoriaServicio categoria) {
    switch (categoria) {
      case CategoriaServicio.cafeteria:
        return Icons.local_cafe;
      case CategoriaServicio.papeleria:
        return Icons.edit;
      case CategoriaServicio.atencionEstudiante:
        return Icons.support_agent;
      case CategoriaServicio.bienestar:
        return Icons.favorite;
      case CategoriaServicio.comercioAliado:
        return Icons.storefront;
      case CategoriaServicio.biblioteca:
        return Icons.local_library;
      case CategoriaServicio.salud:
        return Icons.local_hospital;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (MapCamera.of(context).zoom < CampusMapView.zoomServicios) {
      return const SizedBox.shrink();
    }
    return MarkerLayer(
      markers: <Marker>[
        for (final n in cartography.negocios)
          Marker(
            point: n.ubicacion,
            width: LayoutMetrics.minTouchTarget,
            height: LayoutMetrics.minTouchTarget,
            child: Semantics(
              button: true,
              label: n.nombre,
              child: InkResponse(
                onTap: () => onServicioTap(n),
                radius: LayoutMetrics.space24,
                child: Center(
                  child: Container(
                    width: LayoutMetrics.space32,
                    height: LayoutMetrics.space32,
                    decoration: BoxDecoration(
                      color: PontiMapsTheme.accent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: n.id == destinoId ? PontiMapsTheme.primary : PontiMapsTheme.surface,
                        width: 2,
                      ),
                    ),
                    child: Icon(_icono(n.categoria), size: 16, color: PontiMapsTheme.onAccent),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PuntoUsuario extends StatelessWidget {
  const _PuntoUsuario();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tu ubicación',
      child: Container(
        decoration: BoxDecoration(
          color: PontiMapsTheme.primary,
          shape: BoxShape.circle,
          border: Border.all(color: PontiMapsTheme.surface, width: 3),
        ),
      ),
    );
  }
}

class _PinOrigen extends StatelessWidget {
  const _PinOrigen();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Punto de partida',
      child: const Icon(Icons.flag, size: 32, color: PontiMapsTheme.error),
    );
  }
}

/// Pin de un reporte vigente: icono del tipo sobre su color, con zona táctil de
/// 48 × 48 dp y etiqueta accesible.
class _PinReporte extends StatelessWidget {
  const _PinReporte({required this.reporte, required this.onTap});

  final ReporteComunidad reporte;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Reporte: ${reporte.tipo.etiqueta}',
      child: InkResponse(
        onTap: onTap,
        radius: LayoutMetrics.space24,
        child: Center(
          child: Container(
            width: LayoutMetrics.space32,
            height: LayoutMetrics.space32,
            decoration: BoxDecoration(
              color: reporte.tipo.colorFondo,
              shape: BoxShape.circle,
              border: Border.all(color: PontiMapsTheme.surface, width: 2),
            ),
            child: Icon(reporte.tipo.icono, size: 16, color: reporte.tipo.colorIcono),
          ),
        ),
      ),
    );
  }
}

/// Pin de una alerta oficial: icono de megáfono sobre azul institucional, con zona
/// táctil de 48 × 48 dp y etiqueta accesible.
class _PinAlerta extends StatelessWidget {
  const _PinAlerta({required this.alerta, required this.onTap});

  final AlertaOficial alerta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Alerta oficial: ${alerta.mensaje}',
      child: InkResponse(
        onTap: onTap,
        radius: LayoutMetrics.space24,
        child: Center(
          child: Container(
            width: LayoutMetrics.space32,
            height: LayoutMetrics.space32,
            decoration: BoxDecoration(
              color: PontiMapsTheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: PontiMapsTheme.accent, width: 3),
            ),
            child: const Icon(Icons.campaign, size: 16, color: PontiMapsTheme.onPrimary),
          ),
        ),
      ),
    );
  }
}
