import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/providers.dart';
import 'package:pontimaps_app/core/theme/pontimaps_theme.dart';
import 'package:pontimaps_app/core/utils/geo_utils.dart';
import 'package:pontimaps_app/data/campus_cartography.dart';
import 'package:pontimaps_app/data/consent_repository.dart';
import 'package:pontimaps_app/data/app_session.dart';
import 'package:pontimaps_app/data/location_service.dart';
import 'package:pontimaps_app/data/map_sdk_adapter.dart';
import 'package:pontimaps_app/data/notification_scheduler.dart';
import 'package:pontimaps_app/data/official_alerts_repository.dart';
import 'package:pontimaps_app/data/reports_repository.dart';
import 'package:pontimaps_app/data/schedule_repository.dart';
import 'package:pontimaps_app/domain/routing/grafo_campus.dart';
import 'package:pontimaps_app/domain/search/campus_search.dart';
import 'package:pontimaps_app/domain/services/auth_guard.dart';
import 'package:pontimaps_app/domain/services/congestion_service.dart';
import 'package:pontimaps_app/domain/services/departure_planner.dart';
import 'package:pontimaps_app/domain/services/opening_hours.dart';
import 'package:pontimaps_app/domain/services/moderation_service.dart';
import 'package:pontimaps_app/domain/services/next_class.dart';
import 'package:pontimaps_app/models/horario_usuario.dart';
import 'package:pontimaps_app/models/reporte_comunidad.dart';
import 'package:pontimaps_app/models/ruta_calculada.dart';
import 'package:pontimaps_app/presentation/report_flow.dart';
import 'package:pontimaps_app/presentation/shell_controller.dart';
import 'package:pontimaps_app/presentation/widgets/building_detail_sheet.dart';
import 'package:pontimaps_app/presentation/widgets/congestion_legend.dart';
import 'package:pontimaps_app/presentation/widgets/departure_alert_banner.dart';
import 'package:pontimaps_app/presentation/widgets/next_class_chip.dart';
import 'package:pontimaps_app/presentation/widgets/official_alert_sheet.dart';
import 'package:pontimaps_app/presentation/widgets/report_detail_sheet.dart';
import 'package:pontimaps_app/presentation/widgets/restricted_action_dialog.dart';
import 'package:pontimaps_app/presentation/widgets/route_summary_card.dart';
import 'package:pontimaps_app/presentation/widgets/top_search_bar.dart';

/// Mapa principal (S12) con el flujo `Abrir → Destino → Ir`:
///
/// 1. toque 1: la barra de búsqueda **fija arriba**;
/// 2. toque 2: elegir el edificio, salón o servicio → hoja de detalle (S14);
/// 3. toque 3: **«Ir»** → ruta en curso (S15/S16) y, al llegar, confirmación (S17).
///
/// Entra en modo visitante de solo lectura. El GPS se puede pausar o revocar en
/// cualquier momento (RF-PER-04); sin GPS se elige el origen a mano (RF-PER-05).
/// La posición vive solo en memoria: no se guarda ni se envía (Regla 4).
class MapHomeScreen extends ConsumerStatefulWidget {
  const MapHomeScreen({super.key});

  @override
  ConsumerState<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends ConsumerState<MapHomeScreen> {
  final MapController _mapa = MapController();

  late final CampusCartography _cartografia;
  late final CampusSearch _busqueda;
  late final ConsentController _consentimiento;
  late final LocationProvider _ubicacion;
  late final double _velocidad;
  late final ReportsRepository _reportes;
  late final Reloj _reloj;
  late final AppSession _sesion;
  late final ScheduleController _horario;
  late final ShellController _shell;
  late final NotificationScheduler _alertas;
  late final OfficialAlertsRepository _alertasOficiales;
  StreamSubscription<List<AlertaOficial>>? _suscripcionAlertas;
  List<AlertaOficial> _alertasVigentes = const <AlertaOficial>[];
  AlertaOficial? _alertaSeleccionada;
  late final List<ZonaCongestion> _zonas;

  bool _mostrarCongestion = false;
  final Set<String> _alertasDescartadas = <String>{};

  StreamSubscription<List<ReporteComunidad>>? _suscripcionReportes;
  Timer? _temporizadorVigencia;
  List<ReporteComunidad> _reportesVigentes = const <ReporteComunidad>[];
  ReporteComunidad? _reporteSeleccionado;
  String? _avisoRuta;

  /// Cada cuánto se vuelve a evaluar la vigencia de los reportes (el cliente es
  /// la autoridad sobre `expiraEn`).
  static const Duration _periodoVigencia = Duration(seconds: 30);

  StreamSubscription<PosicionUsuario>? _suscripcion;
  PosicionUsuario? _posicion;
  EstadoPermisoUbicacion? _permiso;
  LatLng? _origenManual;

  DestinoSeleccionado? _destino;
  VistaPreviaRuta _vistaPrevia = const PreviaSinOrigen();
  bool _evitarEscaleras = false;
  RutaCalculada? _ruta;
  bool _llegada = false;

  /// Distancia máxima al nodo más cercano para considerar que el usuario está
  /// dentro del campus (E1-06): no se ajusta en silencio al nodo más cercano.
  static const double _radioCampusMetros = 400;

  LatLng? get _origen => _posicion?.punto ?? _origenManual;

  @override
  void initState() {
    super.initState();
    _cartografia = ref.read(cartographyProvider);
    _busqueda = CampusSearch(_cartografia);
    _consentimiento = ref.read(consentControllerProvider);
    _ubicacion = ref.read(locationProviderProvider);
    _velocidad = ref.read(appConfigProvider).velocidadPeatonalMetrosPorSegundo;
    _reportes = ref.read(reportsRepositoryProvider);
    _reloj = ref.read(clockProvider);
    _sesion = ref.read(sessionProvider);
    _horario = ref.read(scheduleControllerProvider);
    _shell = ref.read(shellControllerProvider);
    _alertas = ref.read(notificationSchedulerProvider);
    _alertasOficiales = ref.read(alertsRepositoryProvider);
    _alertasVigentes = _alertasOficiales.vigentes();
    _suscripcionAlertas = _alertasOficiales.observar().listen((lista) {
      if (!mounted) return;
      setState(() {
        _alertasVigentes = lista;
        final sel = _alertaSeleccionada;
        if (sel != null && !lista.any((a) => a.id == sel.id)) _alertaSeleccionada = null;
      });
    });
    _zonas = CongestionService.zonasDelCampus(_cartografia);
    _consentimiento.addListener(_sincronizarGps);
    _sesion.addListener(_alCambiarSesion);
    _horario.addListener(_alCambiarSesion);
    _alertas.addListener(_alCambiarSesion);
    _shell.addListener(_alCambiarPestana);
    _reportesVigentes = _reportes.vigentes();
    _cartografia.grafo.aplicarReportesVigentes(_reportesVigentes, ahora: _reloj());
    _suscripcionReportes = _reportes.observar().listen(_alCambiarReportes);
    _temporizadorVigencia = Timer.periodic(_periodoVigencia, (_) => _reportes.refrescar());
    _sincronizarGps();
    _alCambiarPestana();
    _actualizarAlertaSalida();
  }

  @override
  void dispose() {
    _consentimiento.removeListener(_sincronizarGps);
    _sesion.removeListener(_alCambiarSesion);
    _horario.removeListener(_alCambiarSesion);
    _alertas.removeListener(_alCambiarSesion);
    _shell.removeListener(_alCambiarPestana);
    _temporizadorVigencia?.cancel();
    _suscripcionAlertas?.cancel();
    _suscripcionReportes?.cancel();
    _suscripcion?.cancel();
    _mapa.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- GPS

  /// Enciende o apaga la lectura del GPS según el consentimiento vigente.
  void _sincronizarGps() {
    if (_consentimiento.estado.gpsActivo) {
      _iniciarGps();
    } else {
      _detenerGps();
    }
  }

  Future<void> _iniciarGps() async {
    if (_suscripcion != null) return;
    final permiso = await _ubicacion.estadoPermiso();
    if (!mounted || !_consentimiento.estado.gpsActivo || _suscripcion != null) return;
    if (permiso != EstadoPermisoUbicacion.concedido) {
      setState(() => _permiso = permiso);
      return;
    }
    setState(() => _permiso = permiso);
    _suscripcion = _ubicacion.posiciones().listen(
      _alRecibirPosicion,
      onError: (Object _) {
        if (mounted) setState(() => _permiso = EstadoPermisoUbicacion.servicioApagado);
      },
    );
  }

  /// Cancela el flujo de posiciones (en menos de 1 s) y descarta la última
  /// posición de la memoria. Una ruta ya calculada sigue como ruta estática.
  void _detenerGps() {
    _suscripcion?.cancel();
    _suscripcion = null;
    if (!mounted || (_posicion == null && _permiso == null)) return;
    setState(() {
      _posicion = null;
      _permiso = null;
    });
    if (_destino != null && _ruta == null) _calcularVistaPrevia();
  }

  void _alRecibirPosicion(PosicionUsuario posicion) {
    if (!mounted) return;
    final primera = _posicion == null;
    setState(() {
      _posicion = posicion;
      final ruta = _ruta;
      if (ruta != null && !_llegada && ruta.haLlegado(posicion.punto)) {
        _llegada = true;
      }
    });
    if (primera && _destino != null && _ruta == null) _calcularVistaPrevia();
    // Con la posición conocida se puede calcular la hora de salida hacia la clase.
    if (primera) _actualizarAlertaSalida();
  }

  Future<void> _alternarGps(bool encendido) async {
    if (!encendido) {
      await _consentimiento.pausarGps(true);
      return;
    }
    if (_consentimiento.estado.decision == DecisionGps.aceptado) {
      await _consentimiento.pausarGps(false);
      return;
    }
    // Aún no aceptó: se vuelve al consentimiento (único lugar que pide el permiso).
    if (mounted) context.push('/permiso');
  }

  // ------------------------------------------------- reportes y sesión

  void _alCambiarSesion() {
    if (!mounted) return;
    setState(() {});
    _actualizarAlertaSalida();
  }

  /// Planifica la alerta de hora de salida hacia la próxima clase:
  /// `inicio − duración de la ruta A* − 5 min` (RF-HOR-05). Sin cuenta verificada
  /// o sin clase, no hay alerta.
  void _actualizarAlertaSalida() {
    if (accionBloqueada(ref, AccionProtegida.miProximaClase)) {
      _alertas.cancelar();
      return;
    }
    final alerta = DeparturePlanner.planificar(
      perfil: _sesion.perfil,
      horario: _horario.bloques,
      ahora: _reloj(),
      cartografia: _cartografia,
      posicion: _posicion?.punto,
      velocidadMetrosPorSegundo: _velocidad,
    );
    if (alerta == null) {
      _alertas.cancelar();
    } else {
      _alertas.programar(alerta);
    }
  }

  /// El aviso solo se muestra desde 10 min antes de la hora de salida y mientras
  /// la clase siga siendo la próxima.
  AlertaSalida? _alertaVisible() {
    final alerta = _alertas.activa;
    if (alerta == null || _alertasDescartadas.contains(alerta.id)) return null;
    return alerta.minutosParaSalir(horaBogota(_reloj())) <= 10 ? alerta : null;
  }

  void _iniciarRutaALaClase(AlertaSalida alerta) {
    final edificio = _cartografia.edificioPorId(alerta.salon.idEdificio);
    if (edificio == null) return;
    setState(() {
      _alertasDescartadas.add(alerta.id);
      _reporteSeleccionado = null;
    });
    _seleccionarDestino(DestinoSeleccionado.deSalon(alerta.salon, edificio));
    _ir();
  }

  /// Hora (`HH:mm`) de la próxima clase, o `null` si no hay o la cuenta no puede verla.
  String? _horaProximaClase() {
    if (accionBloqueada(ref, AccionProtegida.miProximaClase)) return null;
    final proxima = calcularProximaClase(_sesion.perfil, _horario.bloques, _reloj());
    return proxima == null ? null : BloqueHorario.formatoHora(proxima.bloque.horaInicio);
  }

  /// Un reporte nuevo, confirmado, ocultado o vencido cambia el grafo: se
  /// reaplican los vigentes y, si hay un destino, se recalcula la ruta (P3-09).
  void _alCambiarReportes(List<ReporteComunidad> vigentes) {
    if (!mounted) return;
    _cartografia.grafo.aplicarReportesVigentes(vigentes, ahora: _reloj());
    final seleccionado = _reporteSeleccionado;
    setState(() {
      _reportesVigentes = vigentes;
      if (seleccionado != null) {
        final actualizado = vigentes.where((r) => r.id == seleccionado.id);
        _reporteSeleccionado = actualizado.isEmpty ? null : actualizado.first;
      }
    });
    _recalcularPorReportes();
    _actualizarAlertaSalida();
  }

  void _recalcularPorReportes() {
    final destino = _destino;
    if (destino == null) return;
    final ruta = _ruta;
    if (ruta == null) {
      _calcularVistaPrevia();
      return;
    }
    final origen = _origen;
    if (origen == null || _llegada) return;
    try {
      final nueva = _calcular(origen, destino);
      final cambio = !listEquals(nueva.puntos, ruta.puntos);
      setState(() {
        _ruta = nueva;
        _avisoRuta = null;
      });
      if (cambio) _avisar('Ruta actualizada por un reporte.');
    } on RutaNoEncontradaException catch (e) {
      setState(() => _avisoRuta = _mensajeSinRuta(e));
    }
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _alTocarReportar() => iniciarFlujoReporte(context, ref, origenAproximado: _origen);

  Future<void> _votar(ReporteComunidad reporte, VotoReporte voto) =>
      votarReporte(context, ref, reporte: reporte, voto: voto);

  /// El directorio (otra pestaña) pide abrir un destino en el mapa.
  void _alCambiarPestana() {
    final solicitud = _shell.consumirSolicitud();
    if (solicitud == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _reporteSeleccionado = null);
        _seleccionarDestino(solicitud.destino);
      }
    });
  }

  /// «Mi próxima clase» (Path 2): un toque muestra la materia, la hora y
  /// `Edificio · Piso · Salón` con la ruta lista para «Ir».
  Future<void> _alTocarProximaClase() async {
    if (!await verificarAccion(context, ref, AccionProtegida.miProximaClase)) return;
    if (!mounted) return;
    final proxima = calcularProximaClase(_sesion.perfil, _horario.bloques, _reloj());
    if (proxima == null) {
      await showDialog<void>(
        context: context,
        builder: (dialogo) => AlertDialog(
          title: const Text('Aún no tienes clases'),
          content: const Text('Agrega tu primera clase y la verás aquí con un toque.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogo).pop(),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogo).pop();
                context.push('/horario');
              },
              child: const Text('Agregar mi primera clase'),
            ),
          ],
        ),
      );
      return;
    }
    final bloque = proxima.bloque;
    final edificio = _cartografia.edificioPorId(bloque.idEdificio);
    final salon = edificio?.buscarSalon(bloque.codigoSalon);
    if (edificio == null || salon == null) {
      _avisar('No encontramos el salón de esa clase. Edítala en tu horario.');
      return;
    }
    setState(() => _reporteSeleccionado = null);
    _seleccionarDestino(
      DestinoSeleccionado.deSalon(
        salon,
        edificio,
        detalle:
            '${bloque.materia} · ${BloqueHorario.formatoHora(bloque.horaInicio)} · ${proxima.estado}',
      ),
    );
  }

  // ------------------------------------------------------------ destino y ruta

  void _alElegirResultado(ResultadoBusqueda resultado) {
    final DestinoSeleccionado destino;
    switch (resultado) {
      case ResultadoEdificio():
        destino = DestinoSeleccionado.deEdificio(resultado.edificio);
      case ResultadoSalon():
        destino = DestinoSeleccionado.deSalon(resultado.salon, resultado.edificio);
      case ResultadoServicio():
        destino = DestinoSeleccionado.deNegocio(resultado.negocio, _cartografia);
    }
    _seleccionarDestino(destino);
  }

  void _seleccionarDestino(DestinoSeleccionado destino) {
    setState(() {
      _destino = destino;
      _ruta = null;
      _llegada = false;
    });
    _calcularVistaPrevia();
    _mapa.move(destino.punto, 18);
  }

  RutaCalculada _calcular(LatLng origen, DestinoSeleccionado destino) {
    final salon = destino.salon;
    if (salon != null) {
      return _cartografia.calcularRutaHaciaSalon(
        origen,
        salon,
        evitarEscaleras: _evitarEscaleras,
        velocidadMetrosPorSegundo: _velocidad,
      );
    }
    return _cartografia.calcularRuta(
      origen,
      destino.idRuta,
      piso: destino.piso,
      evitarEscaleras: _evitarEscaleras,
      velocidadMetrosPorSegundo: _velocidad,
    );
  }

  bool _fueraDelCampus(LatLng origen) {
    for (final nodo in _cartografia.grafo.nodos) {
      if (distanciaHaversine(origen, nodo.ubicacion) <= _radioCampusMetros) return false;
    }
    return true;
  }

  static String _mensajeSinRuta(RutaNoEncontradaException e) {
    switch (e.motivo) {
      case MotivoSinRuta.edificioSinEntradas:
        return 'Aún no tenemos la entrada de este edificio.';
      case MotivoSinRuta.desconectado:
        return 'No encontramos un camino desde tu punto de partida. Elige otro origen.';
      case MotivoSinRuta.bloqueadoPorReportes:
        return 'Los cierres reportados bloquean el camino. Intenta más tarde.';
      case MotivoSinRuta.soloPorEscaleras:
        return 'Con «Evitar escaleras» no hay camino hasta este destino. Desactívalo para ver la mejor ruta.';
      case MotivoSinRuta.grafoVacio:
        return 'El mapa de caminos del campus no está disponible.';
    }
  }

  void _calcularVistaPrevia() {
    final destino = _destino;
    final origen = _origen;
    VistaPreviaRuta previa;
    if (destino == null) return;
    if (origen == null) {
      previa = const PreviaSinOrigen();
    } else if (_fueraDelCampus(origen)) {
      previa = const PreviaError(
        'Parece que estás fuera del campus. Elige tu punto de partida.',
      );
    } else {
      try {
        previa = PreviaRuta(_calcular(origen, destino));
      } on RutaNoEncontradaException catch (e) {
        previa = PreviaError(_mensajeSinRuta(e));
      }
    }
    if (mounted) setState(() => _vistaPrevia = previa);
  }

  Future<void> _ir() async {
    final destino = _destino;
    if (destino == null) return;
    if (_origen == null) {
      final elegido = await _elegirOrigen();
      if (!elegido || !mounted) return;
    }
    final origen = _origen;
    if (origen == null) return;
    final previa = _vistaPrevia;
    if (previa is! PreviaRuta) return;
    setState(() {
      _ruta = previa.ruta;
      _llegada = previa.ruta.haLlegado(origen);
    });
    _mapa.fitCamera(
      CameraFit.coordinates(
        coordinates: <LatLng>[origen, ...previa.ruta.puntos],
        padding: const EdgeInsets.all(LayoutMetrics.space48),
        maxZoom: 18,
      ),
    );
  }

  void _detenerRuta() {
    setState(() {
      _ruta = null;
      _destino = null;
      _llegada = false;
      _avisoRuta = null;
      _vistaPrevia = const PreviaSinOrigen();
    });
  }

  void _cerrarDetalle() => _detenerRuta();

  void _alCambiarEvitarEscaleras(bool valor) {
    setState(() => _evitarEscaleras = valor);
    _calcularVistaPrevia();
  }

  /// Lista de edificios para elegir el punto de partida cuando no hay GPS.
  /// Devuelve `true` si el usuario eligió uno.
  Future<bool> _elegirOrigen() async {
    final edificio = await showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PontiMapsTheme.surface,
      builder: (context) => _SelectorOrigen(cartografia: _cartografia),
    );
    if (edificio == null) return false;
    _fijarOrigenManual(edificio);
    return true;
  }

  void _fijarOrigenManual(LatLng punto) {
    setState(() => _origenManual = punto);
    if (_destino != null && _ruta == null) _calcularVistaPrevia();
  }

  // ------------------------------------------------------------------- vista

  String _siguienteTramo(RutaCalculada ruta) {
    final p = _posicion?.punto;
    return (p == null ? ruta.instrucciones.first : ruta.obtenerSiguienteTramo(p)).texto;
  }

  Widget? _panelInferior() {
    final alertaOficial = _alertaSeleccionada;
    if (alertaOficial != null) {
      return OfficialAlertSheet(
        alerta: alertaOficial,
        onCerrar: () => setState(() => _alertaSeleccionada = null),
      );
    }
    final reporte = _reporteSeleccionado;
    if (reporte != null) {
      return ReportDetailSheet(
        reporte: reporte,
        ahora: _reloj(),
        bloqueado: accionBloqueada(ref, AccionProtegida.calificarReporte),
        onSigueAhi: () => _votar(reporte, VotoReporte.sigueAhi),
        onFalso: () => _votar(reporte, VotoReporte.falso),
        onCerrar: () => setState(() => _reporteSeleccionado = null),
      );
    }
    final destino = _destino;
    if (destino == null) {
      final alerta = _alertaVisible();
      if (alerta == null) return null;
      return DepartureAlertBanner(
        alerta: alerta,
        ahora: horaBogota(_reloj()),
        onIniciarRuta: () => _iniciarRutaALaClase(alerta),
        onCerrar: () => setState(() => _alertasDescartadas.add(alerta.id)),
      );
    }
    final ruta = _ruta;
    if (ruta != null && _llegada) {
      return ArrivalCard(destino: destino, onListo: _detenerRuta);
    }
    if (ruta != null) {
      return RouteSummaryCard(
        ruta: ruta,
        destino: destino,
        siguienteTramo: _siguienteTramo(ruta),
        senalDebil: _posicion?.senalDebil ?? false,
        avisoRuta: _avisoRuta,
        onDetener: _detenerRuta,
      );
    }
    return BuildingDetailSheet(
      destino: destino,
      vistaPrevia: _vistaPrevia,
      evitarEscaleras: _evitarEscaleras,
      onEvitarEscaleras: _alCambiarEvitarEscaleras,
      onIr: _ir,
      onCerrar: _cerrarDetalle,
      onElegirOrigen: _elegirOrigen,
    );
  }

  @override
  Widget build(BuildContext context) {
    final panel = _panelInferior();
    final congestion = _mostrarCongestion
        ? CongestionService.calcular(zonas: _zonas, reportes: _reportesVigentes, ahora: _reloj())
        : const <CongestionZona>[];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Stack(
                children: <Widget>[
                  CampusMapView(
                    cartography: _cartografia,
                    controller: _mapa,
                    tileProvider: ref.watch(tileProviderProvider),
                    ubicacionUsuario: _posicion?.punto,
                    origenManual: _posicion == null ? _origenManual : null,
                    reportes: _reportesVigentes,
                    alertas: _alertasVigentes,
                    onAlertaTap: (a) => setState(() => _alertaSeleccionada = a),
                    zonasCongestion: congestion,
                    mostrarCongestion: _mostrarCongestion,
                    onReporteTap: (r) => setState(() => _reporteSeleccionado = r),
                    ruta: _ruta?.puntos ?? _vistaPreviaPuntos(),
                    destinoId: _destino?.idRuta,
                    onEdificioTap: (e) => _seleccionarDestino(DestinoSeleccionado.deEdificio(e)),
                    onServicioTap: (n) =>
                        _seleccionarDestino(DestinoSeleccionado.deNegocio(n, _cartografia)),
                    onLongPress: _fijarOrigenManual,
                  ),
                  if (_mostrarCongestion)
                    Positioned(
                      left: LayoutMetrics.screenMargin,
                      right: LayoutMetrics.screenMargin + 128,
                      bottom: 112,
                      child: CongestionLegend(zonas: congestion),
                    ),
                  Positioned(
                    left: LayoutMetrics.screenMargin,
                    bottom: 56,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: LayoutMetrics.minTouchTarget),
                      child: FilterChip(
                        avatar: const Icon(Icons.layers_outlined, size: 24),
                        label: const Text('Congestión'),
                        selected: _mostrarCongestion,
                        onSelected: (valor) => setState(() => _mostrarCongestion = valor),
                      ),
                    ),
                  ),
                  Positioned(
                    right: LayoutMetrics.screenMargin,
                    bottom: LayoutMetrics.space48,
                    child: FloatingActionButton.extended(
                      onPressed: _alTocarReportar,
                      icon: Icon(
                        accionBloqueada(ref, AccionProtegida.crearReporte)
                            ? Icons.lock_outline
                            : Icons.campaign_outlined,
                      ),
                      label: const Text('Reportar'),
                    ),
                  ),
                  Positioned(
                    top: LayoutMetrics.space16,
                    left: LayoutMetrics.screenMargin,
                    right: LayoutMetrics.screenMargin,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        TopSearchBar(busqueda: _busqueda, onSeleccionar: _alElegirResultado),
                        const SizedBox(height: LayoutMetrics.space8),
                        _PanelUbicacion(
                          modoVisitante: _sesion.perfil.esInvitado || _sesion.perfil.authState == AuthState.bloqueado,
                          suspendida: _sesion.perfil.authState == AuthState.bloqueado,
                          proximaClase: NextClassChip(
                            bloqueado: accionBloqueada(ref, AccionProtegida.miProximaClase),
                            onTap: _alTocarProximaClase,
                            // Con texto > 130 % el chip se compacta para dejar libre el mapa.
                            compacto: MediaQuery.textScalerOf(context).scale(1) > 1.3,
                            hora: _horaProximaClase(),
                          ),
                          gpsActivo: _consentimiento.estado.gpsActivo,
                          hayPosicion: _posicion != null,
                          permiso: _permiso,
                          onAlternar: _alternarGps,
                          onElegirOrigen: _elegirOrigen,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ?panel,
          ],
        ),
      ),
    );
  }

  List<LatLng>? _vistaPreviaPuntos() {
    final previa = _vistaPrevia;
    return _destino != null && previa is PreviaRuta ? previa.ruta.puntos : null;
  }
}

/// Insignia de modo visitante, interruptor del GPS y aviso de ubicación (S12/S11).
class _PanelUbicacion extends StatelessWidget {
  const _PanelUbicacion({
    required this.modoVisitante,
    required this.suspendida,
    required this.proximaClase,
    required this.gpsActivo,
    required this.hayPosicion,
    required this.permiso,
    required this.onAlternar,
    required this.onElegirOrigen,
  });

  final bool modoVisitante;

  /// Cuenta bloqueada por un administrador: queda en modo Visitante (solo lectura).
  final bool suspendida;
  final Widget proximaClase;
  final bool gpsActivo;
  final bool hayPosicion;
  final EstadoPermisoUbicacion? permiso;
  final ValueChanged<bool> onAlternar;
  final VoidCallback onElegirOrigen;

  String? get _aviso {
    if (!gpsActivo) return 'Ubicación apagada. Elige tu punto de partida para trazar rutas.';
    switch (permiso) {
      case EstadoPermisoUbicacion.denegado:
      case EstadoPermisoUbicacion.denegadoPermanente:
        return 'Sin permiso de ubicación. Actívalo en los ajustes del sistema o elige tu punto de partida.';
      case EstadoPermisoUbicacion.servicioApagado:
        return 'El GPS del dispositivo está apagado. Enciéndelo o elige tu punto de partida.';
      case EstadoPermisoUbicacion.noSolicitado:
      case EstadoPermisoUbicacion.concedido:
      case null:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final aviso = _aviso;
    return Material(
      color: PontiMapsTheme.surface,
      elevation: 4,
      borderRadius: BorderRadius.circular(LayoutMetrics.radiusCard),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: LayoutMetrics.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: LayoutMetrics.minTouchTarget),
              child: Row(
                children: <Widget>[
                  if (modoVisitante)
                    Flexible(
                      child: Text(
                        suspendida ? 'Cuenta suspendida · solo lectura' : 'Modo visitante',
                        style: textTheme.bodySmall?.copyWith(
                          color: PontiMapsTheme.textSecondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Flexible(
                    flex: 2,
                    child: Text(
                      hayPosicion ? 'Ubicación activa' : 'Ubicación (GPS)',
                      textAlign: TextAlign.end,
                      style: textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: LayoutMetrics.space8),
                  Semantics(
                    label: 'Ubicación GPS',
                    child: Switch(value: gpsActivo, onChanged: onAlternar),
                  ),
                ],
              ),
            ),
            if (aviso != null) ...<Widget>[
              Text(aviso, style: textTheme.bodySmall),
              TextButton(
                onPressed: onElegirOrigen,
                child: const Text('Elegir punto de partida'),
              ),
            ],
            Align(alignment: Alignment.centerLeft, child: proximaClase),
            const SizedBox(height: LayoutMetrics.space8),
          ],
        ),
      ),
    );
  }
}

/// Hoja para elegir el origen entre los edificios del campus (sin GPS).
class _SelectorOrigen extends StatelessWidget {
  const _SelectorOrigen({required this.cartografia});

  final CampusCartography cartografia;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final edificios = cartografia.edificios;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(LayoutMetrics.screenMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Elige tu punto de partida', style: textTheme.titleLarge),
            const SizedBox(height: LayoutMetrics.space8),
            Text(
              'También puedes mantener pulsado un punto del mapa.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: LayoutMetrics.space8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: edificios.length,
                itemBuilder: (context, i) {
                  final e = edificios[i];
                  return ListTile(
                    minTileHeight: LayoutMetrics.minTouchTarget,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.apartment, color: PontiMapsTheme.primary),
                    title: Text(e.nombre),
                    subtitle: e.numero == null ? null : Text(e.etiqueta),
                    onTap: () => Navigator.of(context).pop(e.ubicacion),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
