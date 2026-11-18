import 'package:flutter/foundation.dart';
import 'package:pontimaps_app/presentation/widgets/building_detail_sheet.dart';

/// Pestañas de la barra inferior.
abstract final class Pestana {
  static const int mapa = 0;
  static const int directorio = 1;
  static const int mas = 2;
}

/// Petición de abrir un destino en el mapa (desde el directorio o desde
/// «Mi próxima clase»).
class SolicitudMapa {
  const SolicitudMapa(this.destino);

  final DestinoSeleccionado destino;
}

/// Coordina las pestañas `Mapa · Directorio · Más`: qué pestaña está activa y
/// qué destino debe abrir el mapa cuando otra pestaña lo pide (Path 1 desde el
/// botón «Ir» del directorio).
class ShellController extends ChangeNotifier {
  int _pestana = Pestana.mapa;
  SolicitudMapa? _pendiente;

  int get pestana => _pestana;

  void irAPestana(int pestana) {
    if (pestana == _pestana) return;
    _pestana = pestana;
    notifyListeners();
  }

  /// Cambia al mapa y le pide mostrar [destino] (hoja de detalle con «Ir»).
  void irAlMapaCon(DestinoSeleccionado destino) {
    _pendiente = SolicitudMapa(destino);
    _pestana = Pestana.mapa;
    notifyListeners();
  }

  /// Entrega la petición pendiente al mapa (una sola vez).
  SolicitudMapa? consumirSolicitud() {
    final solicitud = _pendiente;
    _pendiente = null;
    return solicitud;
  }
}
