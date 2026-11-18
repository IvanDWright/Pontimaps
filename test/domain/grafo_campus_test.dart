import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pontimaps_app/core/utils/author_hash.dart';
import 'package:pontimaps_app/core/utils/geo_utils.dart';
import 'package:pontimaps_app/domain/routing/grafo_campus.dart';
import 'package:pontimaps_app/models/reporte_comunidad.dart';
import 'package:pontimaps_app/models/ruta_calculada.dart';

// ATENCIÓN: las coordenadas de este grafo semilla son ILUSTRATIVAS. Reproducen
// la topología aproximada de 6 edificios del campus (Ed. 2 Fernando Barón,
// Ed. 11 Gabriel Giraldo, Ed. 20 Jorge Hoyos, Ed. 42 Ingeniería, Ed. 67 José
// Rafael Arboleda y el Hospital San Ignacio) para probar el algoritmo, pero NO
// son datos levantados en campo. Verificar antes de usarlas en la app
// (REQUIREMENTS A-2).
//
// Topología (norte arriba):
//
//   ed11 ---- este ---- hsi
//    |          \
//  norte         \
//    |            \
//  ed02 -- centro -- ed20
//    |                 |
//  ed42 -- sur ------ ed67      (ed20 -- ed67 es el camino corto)
//
// Ruta corta ed02 -> ed67: ed02 - centro - ed20 - ed67   (~300 m)
// Ruta alterna:            ed02 - ed42 - sur - ed67      (~333 m)

const double _latitudHospital = 4.6295;

final LatLng _ed02 = LatLng(4.6285, -74.0650);
final LatLng _norte = LatLng(4.6290, -74.0645);
final LatLng _ed11 = LatLng(4.6290, -74.0640);
final LatLng _centro = LatLng(4.6282, -74.0640);
final LatLng _ed20 = LatLng(4.6280, -74.0635);
final LatLng _ed42 = LatLng(4.6275, -74.0645);
final LatLng _sur = LatLng(4.6268, -74.0640);
final LatLng _ed67 = LatLng(4.6270, -74.0630);
final LatLng _este = LatLng(4.6288, -74.0630);
final LatLng _hsi = LatLng(_latitudHospital, -74.0625);

final DateTime _ahora = DateTime(2026, 11, 17, 10, 0);

GrafoCampus crearGrafoSemilla() {
  final g = GrafoCampus()
    ..agregarNodo(NodoCamino(id: 'n_ed02', ubicacion: _ed02, idEdificioAsociado: 'ed02'))
    ..agregarNodo(NodoCamino(id: 'n_norte', ubicacion: _norte))
    ..agregarNodo(NodoCamino(id: 'n_ed11', ubicacion: _ed11, idEdificioAsociado: 'ed11'))
    ..agregarNodo(NodoCamino(id: 'n_centro', ubicacion: _centro))
    ..agregarNodo(NodoCamino(id: 'n_ed20', ubicacion: _ed20, idEdificioAsociado: 'ed20'))
    ..agregarNodo(NodoCamino(id: 'n_ed42', ubicacion: _ed42, idEdificioAsociado: 'ed42'))
    ..agregarNodo(NodoCamino(id: 'n_sur', ubicacion: _sur))
    ..agregarNodo(NodoCamino(id: 'n_ed67', ubicacion: _ed67, idEdificioAsociado: 'ed67'))
    ..agregarNodo(NodoCamino(id: 'n_este', ubicacion: _este))
    ..agregarNodo(NodoCamino(id: 'n_hsi', ubicacion: _hsi, idEdificioAsociado: 'hsi'))
    ..conectar('e_02_centro', 'n_ed02', 'n_centro')
    ..conectar('e_centro_20', 'n_centro', 'n_ed20')
    ..conectar('e_20_67', 'n_ed20', 'n_ed67')
    ..conectar('e_02_42', 'n_ed02', 'n_ed42')
    ..conectar('e_42_sur', 'n_ed42', 'n_sur')
    ..conectar('e_sur_67', 'n_sur', 'n_ed67')
    ..conectar('e_02_norte', 'n_ed02', 'n_norte')
    ..conectar('e_norte_11', 'n_norte', 'n_ed11')
    ..conectar('e_11_este', 'n_ed11', 'n_este')
    ..conectar('e_este_hsi', 'n_este', 'n_hsi')
    ..conectar('e_este_20', 'n_este', 'n_ed20');
  return g;
}

double _longitud(List<LatLng> puntos) {
  var total = 0.0;
  for (var i = 0; i < puntos.length - 1; i++) {
    total += distanciaHaversine(puntos[i], puntos[i + 1]);
  }
  return total;
}

ReporteComunidad _reporte(
  String id,
  TipoReporte tipo, {
  String? arista,
  LatLng? ubicacion,
  DateTime? ahora,
}) {
  return ReporteComunidad.nuevo(
    id: id,
    tipo: tipo,
    ubicacion: ubicacion ?? _ed20,
    ahora: ahora ?? _ahora,
    authorHash: calcularAuthorHash('uid-de-prueba'),
    idAristaAfectada: arista,
  );
}

void main() {
  group('GrafoCampus · construcción', () {
    test('rechaza nodos y aristas duplicados o con extremos inexistentes', () {
      final g = crearGrafoSemilla();
      expect(g.cantidadNodos, 10);
      expect(g.cantidadAristas, 11);
      expect(
        () => g.agregarNodo(NodoCamino(id: 'n_ed02', ubicacion: _ed02)),
        throwsArgumentError,
      );
      expect(() => g.conectar('e_02_centro', 'n_ed02', 'n_sur'), throwsArgumentError);
      expect(() => g.conectar('e_x', 'n_ed02', 'n_fantasma'), throwsArgumentError);
    });

    test('nodoMasCercano devuelve el nodo con menor distancia', () {
      final g = crearGrafoSemilla();
      expect(g.nodoMasCercano(LatLng(4.62851, -74.06501)).id, 'n_ed02');
      expect(g.nodoMasCercano(LatLng(4.6269, -74.0631)).id, 'n_ed67');
      expect(() => GrafoCampus().nodoMasCercano(_ed02), throwsStateError);
    });
  });

  group('GrafoCampus · A* sobre el grafo semilla', () {
    test('encuentra la ruta más corta Ed. 2 -> Ed. 67', () {
      final g = crearGrafoSemilla();
      final ruta = g.calcularRutaAStar(LatLng(4.62851, -74.06501), 'ed67');

      expect(ruta.puntos, <LatLng>[_ed02, _centro, _ed20, _ed67]);
      expect(ruta.distanciaMetros, closeTo(_longitud(ruta.puntos), 0.01));
      expect(ruta.distanciaMetros, lessThan(310));
      expect(ruta.tiempoEstimadoMinutos, 4);
      expect(ruta.tieneDesvioPorReporte, isFalse);
    });

    test('es simétrica y óptima en otras parejas de edificios', () {
      final g = crearGrafoSemilla();
      final ida = g.calcularRutaAStar(_ed02, 'hsi');
      final vuelta = g.calcularRutaAStar(_hsi, 'ed02');
      expect(ida.puntos, <LatLng>[_ed02, _norte, _ed11, _este, _hsi]);
      expect(vuelta.puntos, ida.puntos.reversed.toList());
      expect(vuelta.distanciaMetros, closeTo(ida.distanciaMetros, 0.01));
    });

    test('origen ya en el destino devuelve una ruta de un solo punto', () {
      final g = crearGrafoSemilla();
      final ruta = g.calcularRutaAStar(_ed67, 'ed67');
      expect(ruta.puntos, <LatLng>[_ed67]);
      expect(ruta.distanciaMetros, 0);
      expect(ruta.instrucciones.single.maniobra, TipoManiobra.llegada);
      expect(ruta.haLlegado(_ed67), isTrue);
    });

    test('genera instrucciones con el giro correcto y termina en llegada', () {
      final ruta = crearGrafoSemilla().calcularRutaAStar(_ed02, 'ed67');
      final ins = ruta.instrucciones;
      expect(ins.map((i) => i.maniobra), <TipoManiobra>[
        TipoManiobra.inicio,
        TipoManiobra.derecha,
        TipoManiobra.llegada,
      ]);
      expect(ins.first.texto, contains('este'));
      expect(ins[1].texto, contains('derecha'));
      final suma = ins.fold<double>(0, (s, i) => s + i.distanciaMetros);
      expect(suma, closeTo(ruta.distanciaMetros, 0.01));
    });

    test('evitarEscaleras descarta el atajo por escaleras', () {
      final g = crearGrafoSemilla()
        ..agregarNodo(NodoCamino(id: 'n_esc', ubicacion: LatLng(4.6276, -74.0634), esEscaleras: true))
        ..conectar('e_centro_esc', 'n_centro', 'n_esc')
        ..conectar('e_esc_67', 'n_esc', 'n_ed67');

      final conEscaleras = g.calcularRutaAStar(_ed02, 'ed67');
      expect(conEscaleras.puntos.length, 4);
      expect(conEscaleras.puntos[2], LatLng(4.6276, -74.0634));
      expect(
        conEscaleras.instrucciones.map((i) => i.maniobra),
        contains(TipoManiobra.escaleras),
      );

      final sinEscaleras = g.calcularRutaAStar(_ed02, 'ed67', evitarEscaleras: true);
      expect(sinEscaleras.puntos, <LatLng>[_ed02, _centro, _ed20, _ed67]);
      expect(sinEscaleras.distanciaMetros, greaterThan(conEscaleras.distanciaMetros));
    });

    test('un edificio con varias entradas usa la más barata', () {
      final g = crearGrafoSemilla()
        ..agregarNodo(NodoCamino(id: 'n_ed67_b', ubicacion: LatLng(4.6269, -74.0641), idEdificioAsociado: 'ed67'))
        ..conectar('e_sur_67b', 'n_sur', 'n_ed67_b');
      // Desde Ed. 42 la entrada sur (vía n_sur) es más corta que la principal.
      final ruta = g.calcularRutaAStar(_ed42, 'ed67');
      expect(ruta.puntos.last, LatLng(4.6269, -74.0641));
    });

    test('lanza motivos claros cuando no hay ruta', () {
      expect(
        () => GrafoCampus().calcularRutaAStar(_ed02, 'ed67'),
        throwsA(isA<RutaNoEncontradaException>().having((e) => e.motivo, 'motivo', MotivoSinRuta.grafoVacio)),
      );
      final g = crearGrafoSemilla();
      expect(
        () => g.calcularRutaAStar(_ed02, 'ed99'),
        throwsA(isA<RutaNoEncontradaException>().having((e) => e.motivo, 'motivo', MotivoSinRuta.edificioSinEntradas)),
      );
      g.agregarNodo(NodoCamino(id: 'n_isla', ubicacion: LatLng(4.6300, -74.0700), idEdificioAsociado: 'isla'));
      expect(
        () => g.calcularRutaAStar(_ed02, 'isla'),
        throwsA(isA<RutaNoEncontradaException>().having((e) => e.motivo, 'motivo', MotivoSinRuta.desconectado)),
      );
    });

    test('respeta el sentido en un grafo dirigido', () {
      final g = GrafoCampus(dirigido: true)
        ..agregarNodo(NodoCamino(id: 'a', ubicacion: _ed02, idEdificioAsociado: 'A'))
        ..agregarNodo(NodoCamino(id: 'b', ubicacion: _centro, idEdificioAsociado: 'B'))
        ..conectar('ab', 'a', 'b');
      expect(g.calcularRutaAStar(_ed02, 'B').puntos, <LatLng>[_ed02, _centro]);
      expect(
        () => g.calcularRutaAStar(_centro, 'A'),
        throwsA(isA<RutaNoEncontradaException>()),
      );
    });

    test('un tramo marcado como escaleras se evita; si es el único, lo dice con su motivo', () {
      // Atajo con escalones a -> b (≈ 116 m) y un rodeo plano a -> c -> b (≈ 183 m).
      final g = GrafoCampus()
        ..agregarNodo(NodoCamino(id: 'a', ubicacion: _ed02, idEdificioAsociado: 'A'))
        ..agregarNodo(NodoCamino(id: 'c', ubicacion: _norte))
        ..agregarNodo(NodoCamino(id: 'b', ubicacion: _centro, idEdificioAsociado: 'B'))
        ..conectar('ab_escalones', 'a', 'b', esEscaleras: true)
        ..conectar('ac', 'a', 'c')
        ..conectar('cb', 'c', 'b');
      final atajo = g.calcularRutaAStar(_ed02, 'B');
      expect(atajo.puntos, <LatLng>[_ed02, _centro]);
      expect(atajo.instrucciones.map((i) => i.maniobra), contains(TipoManiobra.escaleras));
      expect(g.aristas.firstWhere((a) => a.id == 'ab_escalones').esEscaleras, isTrue);

      final plano = g.calcularRutaAStar(_ed02, 'B', evitarEscaleras: true);
      expect(plano.puntos, <LatLng>[_ed02, _norte, _centro]);
      expect(plano.distanciaMetros, greaterThan(atajo.distanciaMetros));
      expect(plano.instrucciones.map((i) => i.maniobra), isNot(contains(TipoManiobra.escaleras)));

      // Sin tramo plano alternativo, solo se llega por escalones.
      final soloEscalones = GrafoCampus()
        ..agregarNodo(NodoCamino(id: 'a', ubicacion: _ed02, idEdificioAsociado: 'A'))
        ..agregarNodo(NodoCamino(id: 'b', ubicacion: _centro, idEdificioAsociado: 'B'))
        ..conectar('ab', 'a', 'b', esEscaleras: true);
      expect(soloEscalones.calcularRutaAStar(_ed02, 'B').distanciaMetros, greaterThan(0));
      expect(
        () => soloEscalones.calcularRutaAStar(_ed02, 'B', evitarEscaleras: true),
        throwsA(isA<RutaNoEncontradaException>().having((e) => e.motivo, 'motivo', MotivoSinRuta.soloPorEscaleras)),
      );
    });

    test('las aristas bloqueadas de base no se recorren', () {
      final g = crearGrafoSemilla()..conectar('e_hsi_67', 'n_hsi', 'n_ed67', bloqueada: true);
      final ruta = g.calcularRutaAStar(_hsi, 'ed67');
      expect(ruta.puntos.length, greaterThan(2));
    });
  });

  group('GrafoCampus · reportes comunitarios', () {
    test('un cierre desvía la ruta automáticamente', () {
      final g = crearGrafoSemilla();
      final normal = g.calcularRutaAStar(_ed02, 'ed67');

      final aplicados = g.aplicarReportesVigentes(
        <ReporteComunidad>[_reporte('r1', TipoReporte.cierre, arista: 'e_20_67')],
        ahora: _ahora,
      );
      final desviada = g.calcularRutaAStar(_ed02, 'ed67');

      expect(aplicados, 1);
      expect(g.aristaEfectiva('e_20_67')!.bloqueada, isTrue);
      expect(g.aristas.firstWhere((a) => a.id == 'e_20_67').bloqueada, isFalse,
          reason: 'la arista base no se modifica');
      expect(desviada.puntos, <LatLng>[_ed02, _ed42, _sur, _ed67]);
      expect(desviada.tieneDesvioPorReporte, isTrue);
      expect(desviada.distanciaMetros, greaterThan(normal.distanciaMetros));
    });

    test('un cierre sin idAristaAfectada se asigna por cercanía', () {
      final g = crearGrafoSemilla();
      final medio = LatLng((_ed20.latitude + _ed67.latitude) / 2, (_ed20.longitude + _ed67.longitude) / 2);
      g.aplicarReportesVigentes(
        <ReporteComunidad>[_reporte('r1', TipoReporte.cierre, ubicacion: medio)],
        ahora: _ahora,
      );
      expect(g.aristaEfectiva('e_20_67')!.bloqueada, isTrue);
      expect(g.calcularRutaAStar(_ed02, 'ed67').tieneDesvioPorReporte, isTrue);
    });

    test('un reporte lejano de cualquier sendero se ignora', () {
      final g = crearGrafoSemilla();
      final aplicados = g.aplicarReportesVigentes(
        <ReporteComunidad>[_reporte('r1', TipoReporte.cierre, ubicacion: LatLng(4.7, -74.2))],
        ahora: _ahora,
      );
      expect(aplicados, 0);
      expect(g.cantidadAristasAfectadas, 0);
    });

    test('una fila larga encarece el tramo y también puede desviar', () {
      final g = crearGrafoSemilla();
      g.aplicarReportesVigentes(
        <ReporteComunidad>[_reporte('r1', TipoReporte.fila, arista: 'e_20_67')],
        ahora: _ahora,
      );
      expect(g.aristaEfectiva('e_20_67')!.factorCongestion, 1.5);
      final ruta = g.calcularRutaAStar(_ed02, 'ed67');
      expect(ruta.puntos, <LatLng>[_ed02, _ed42, _sur, _ed67]);
      expect(ruta.tieneDesvioPorReporte, isTrue);
    });

    test('una fila en un tramo sin alternativa no desvía pero sí suma tiempo', () {
      final g = crearGrafoSemilla();
      final base = g.calcularRutaAStar(_ed02, 'hsi');
      g.aplicarReportesVigentes(
        <ReporteComunidad>[_reporte('r1', TipoReporte.fila, arista: 'e_este_hsi')],
        ahora: _ahora,
      );
      final ruta = g.calcularRutaAStar(_ed02, 'hsi');
      expect(ruta.puntos, base.puntos);
      expect(ruta.tieneDesvioPorReporte, isFalse);
      expect(ruta.distanciaMetros, closeTo(base.distanciaMetros, 0.01));
      expect(ruta.tiempoEstimadoMinutos, greaterThanOrEqualTo(base.tiempoEstimadoMinutos));
    });

    test('un reporte vencido (>= 60 min) no afecta la ruta', () {
      final g = crearGrafoSemilla();
      final viejo = _reporte('r1', TipoReporte.cierre, arista: 'e_20_67', ahora: _ahora.subtract(const Duration(minutes: 61)));
      expect(g.aplicarReportesVigentes(<ReporteComunidad>[viejo], ahora: _ahora), 0);
      final ruta = g.calcularRutaAStar(_ed02, 'ed67');
      expect(ruta.puntos, <LatLng>[_ed02, _centro, _ed20, _ed67]);
      expect(ruta.tieneDesvioPorReporte, isFalse);
    });

    test('aplicar una lista nueva reemplaza la anterior; limpiar la borra', () {
      final g = crearGrafoSemilla();
      g.aplicarReportesVigentes(
        <ReporteComunidad>[_reporte('r1', TipoReporte.cierre, arista: 'e_20_67')],
        ahora: _ahora,
      );
      expect(g.cantidadAristasAfectadas, 1);
      g.aplicarReportesVigentes(const <ReporteComunidad>[], ahora: _ahora);
      expect(g.cantidadAristasAfectadas, 0);
      g.aplicarReportesVigentes(
        <ReporteComunidad>[_reporte('r1', TipoReporte.cierre, arista: 'e_20_67')],
        ahora: _ahora,
      );
      g.limpiarReportes();
      expect(g.cantidadAristasAfectadas, 0);
    });

    test('cierres que aíslan el destino lanzan bloqueadoPorReportes', () {
      final g = crearGrafoSemilla();
      g.aplicarReportesVigentes(
        <ReporteComunidad>[
          _reporte('r1', TipoReporte.cierre, arista: 'e_20_67'),
          _reporte('r2', TipoReporte.cierre, arista: 'e_sur_67'),
        ],
        ahora: _ahora,
      );
      expect(
        () => g.calcularRutaAStar(_ed02, 'ed67'),
        throwsA(isA<RutaNoEncontradaException>().having((e) => e.motivo, 'motivo', MotivoSinRuta.bloqueadoPorReportes)),
      );
    });

    test('un cierre ocultado por la comunidad (3 negativos) deja de aplicar', () {
      final g = crearGrafoSemilla();
      var cierre = _reporte('r1', TipoReporte.cierre, arista: 'e_20_67');
      for (var i = 0; i < ReporteComunidad.umbralOcultamiento; i++) {
        cierre = cierre.negar();
      }
      expect(g.aplicarReportesVigentes(<ReporteComunidad>[cierre], ahora: _ahora), 0);
    });
  });

  group('RutaCalculada · seguimiento', () {
    late RutaCalculada ruta;
    setUp(() => ruta = crearGrafoSemilla().calcularRutaAStar(_ed02, 'ed67'));

    LatLng medio(LatLng a, LatLng b) => LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2);

    test('obtenerSiguienteTramo sigue al usuario a lo largo de la ruta', () {
      expect(ruta.obtenerSiguienteTramo(medio(_ed02, _centro)).maniobra, TipoManiobra.inicio);
      expect(ruta.obtenerSiguienteTramo(medio(_centro, _ed20)).maniobra, TipoManiobra.inicio);
      expect(ruta.obtenerSiguienteTramo(medio(_ed20, _ed67)).maniobra, TipoManiobra.derecha);
      expect(ruta.obtenerSiguienteTramo(_ed67).maniobra, TipoManiobra.llegada);
    });

    test('haLlegado respeta el radio', () {
      expect(ruta.haLlegado(_ed67), isTrue);
      expect(ruta.haLlegado(LatLng(4.62705, -74.0630)), isTrue); // ~5,5 m
      expect(ruta.haLlegado(_ed20), isFalse);
      expect(ruta.haLlegado(_ed20, radioMetros: 500), isTrue);
    });

    test('el resultado es inmutable', () {
      expect(() => ruta.puntos.add(_ed02), throwsUnsupportedError);
      expect(() => ruta.instrucciones.clear(), throwsUnsupportedError);
    });
  });

  group('A* · optimalidad y rendimiento', () {
    GrafoCampus crearMalla(int n, math.Random azar, {required double probBloqueo}) {
      final g = GrafoCampus();
      for (var i = 0; i < n; i++) {
        for (var j = 0; j < n; j++) {
          g.agregarNodo(
            NodoCamino(
              id: 'n_${i}_$j',
              ubicacion: LatLng(
                4.6200 + i * 0.0005 + azar.nextDouble() * 0.0001,
                -74.0700 + j * 0.0005 + azar.nextDouble() * 0.0001,
              ),
              idEdificioAsociado: (i == n - 1 && j == n - 1) ? 'meta' : null,
            ),
          );
        }
      }
      void unir(String a, String b) {
        final recta = distanciaHaversine(g.nodoPorId(a)!.ubicacion, g.nodoPorId(b)!.ubicacion);
        g.conectar(
          'e_${a}_$b',
          a,
          b,
          // Incluye aristas más CORTAS que la línea recta (datos imperfectos)
          // para comprobar que la heurística sigue siendo admisible.
          distanciaMetros: recta * (0.6 + azar.nextDouble() * 0.8),
          factorCongestion: azar.nextBool() ? 1.0 : 1.0 + azar.nextDouble() * 0.5,
          bloqueada: azar.nextDouble() < probBloqueo,
        );
      }

      for (var i = 0; i < n; i++) {
        for (var j = 0; j < n; j++) {
          if (j + 1 < n) unir('n_${i}_$j', 'n_${i}_${j + 1}');
          if (i + 1 < n) unir('n_${i}_$j', 'n_${i + 1}_$j');
        }
      }
      return g;
    }

    /// Dijkstra de referencia, O(V²), sobre las aristas base del grafo.
    double? costoDijkstra(GrafoCampus g, String origenId, Set<String> metas) {
      final dist = <String, double>{for (final n in g.nodos) n.id: double.infinity};
      dist[origenId] = 0;
      final pendientes = dist.keys.toSet();
      while (pendientes.isNotEmpty) {
        final u = pendientes.reduce((a, b) => dist[a]! <= dist[b]! ? a : b);
        if (dist[u]!.isInfinite) return null;
        if (metas.contains(u)) return dist[u];
        pendientes.remove(u);
        for (final a in g.aristas) {
          if (a.bloqueada) continue;
          final String? v = a.origenId == u ? a.destinoId : (a.destinoId == u ? a.origenId : null);
          if (v == null) continue;
          if (dist[u]! + a.costo < dist[v]!) dist[v] = dist[u]! + a.costo;
        }
      }
      return null;
    }

    test('coincide con Dijkstra en 60 mallas aleatorias con bloqueos y congestión', () {
      final azar = math.Random(2026);
      var conRuta = 0;
      for (var intento = 0; intento < 60; intento++) {
        final g = crearMalla(7, azar, probBloqueo: 0.2);
        final origen = g.nodoPorId('n_0_0')!;
        final esperado = costoDijkstra(g, origen.id, <String>{'n_6_6'});

        if (esperado == null) {
          expect(
            () => g.calcularRutaAStar(origen.ubicacion, 'meta'),
            throwsA(isA<RutaNoEncontradaException>()),
          );
          continue;
        }
        conRuta++;
        final ruta = g.calcularRutaAStar(origen.ubicacion, 'meta');
        final idPorUbicacion = <LatLng, String>{for (final n in g.nodos) n.ubicacion: n.id};
        var costo = 0.0;
        for (var k = 0; k < ruta.puntos.length - 1; k++) {
          final a = idPorUbicacion[ruta.puntos[k]]!;
          final b = idPorUbicacion[ruta.puntos[k + 1]]!;
          final arista = g.aristas.firstWhere(
            (e) => (e.origenId == a && e.destinoId == b) || (e.origenId == b && e.destinoId == a),
          );
          expect(arista.bloqueada, isFalse);
          costo += arista.costo;
        }
        expect(costo, closeTo(esperado, 1e-6), reason: 'intento $intento');
      }
      expect(conRuta, greaterThan(20), reason: 'la prueba debe ejercitar rutas reales');
    });

    test('calcula en < 2 s sobre una malla de 14 400 nodos', () {
      final g = crearMalla(120, math.Random(7), probBloqueo: 0.05);
      expect(g.cantidadNodos, 14400);
      final origen = g.nodoPorId('n_0_0')!.ubicacion;

      final reloj = Stopwatch()..start();
      RutaCalculada? ruta;
      try {
        ruta = g.calcularRutaAStar(origen, 'meta');
      } on RutaNoEncontradaException {
        // Con 5 % de bloqueos puede aislarse la esquina; el tiempo igual cuenta.
      }
      reloj.stop();

      expect(reloj.elapsedMilliseconds, lessThan(2000));
      if (ruta != null) {
        expect(ruta.puntos.first, origen);
      }
    });
  });
}
