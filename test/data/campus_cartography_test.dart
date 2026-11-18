import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pontimaps_app/core/utils/author_hash.dart';
import 'package:pontimaps_app/core/utils/geo_utils.dart';
import 'package:pontimaps_app/data/campus_cartography.dart';
import 'package:pontimaps_app/domain/routing/grafo_campus.dart';
import 'package:pontimaps_app/models/negocio_servicio.dart';
import 'package:pontimaps_app/models/reporte_comunidad.dart';
import 'package:pontimaps_app/models/ruta_calculada.dart';

void main() {
  final cartografia = CampusCartography.seed();
  final grafo = cartografia.grafo;

  LatLng entrada(String idEdificio) => cartografia.entradasDe(idEdificio).first.ubicacion;

  /// Pares de ubicaciones de los tramos de escaleras (en ambos sentidos).
  final tramosDeEscaleras = <(LatLng, LatLng)>{
    for (final a in grafo.aristas)
      if (a.esEscaleras) ...<(LatLng, LatLng)>[
        (grafo.nodoPorId(a.origenId)!.ubicacion, grafo.nodoPorId(a.destinoId)!.ubicacion),
        (grafo.nodoPorId(a.destinoId)!.ubicacion, grafo.nodoPorId(a.origenId)!.ubicacion),
      ],
  };

  bool usaEscaleras(RutaCalculada ruta) {
    for (var i = 0; i < ruta.puntos.length - 1; i++) {
      if (tramosDeEscaleras.contains((ruta.puntos[i], ruta.puntos[i + 1]))) return true;
    }
    return false;
  }

  group('Integridad del catálogo de OpenStreetMap', () {
    test('el grafo es completamente conexo y validar() no reporta problemas', () {
      expect(grafo.esConexo, isTrue);
      expect(cartografia.validar(), isEmpty);
    });

    test('todo edificio y todo servicio independiente tiene al menos un nodo de entrada', () {
      expect(cartografia.edificios.length, greaterThanOrEqualTo(30));
      for (final edificio in cartografia.edificios) {
        final entradas = cartografia.entradasDe(edificio.id);
        expect(entradas, isNotEmpty, reason: edificio.etiqueta);
        for (final nodo in entradas) {
          expect(nodo.idEdificioAsociado, edificio.id);
        }
      }
      for (final negocio in cartografia.negocios.where((n) => !n.dentroDeEdificio)) {
        expect(cartografia.entradasDe(negocio.id), isNotEmpty, reason: negocio.nombre);
      }
    });

    test('las coordenadas vienen de OpenStreetMap y caen en el campus de Bogotá', () {
      expect(CampusCartography.coordenadasVerificadas, isTrue);
      expect(CampusCartography.atribucion, contains('OpenStreetMap'));
      for (final edificio in cartografia.edificios) {
        expect(edificio.ubicacion.latitude, inInclusiveRange(4.625, 4.633), reason: edificio.etiqueta);
        expect(edificio.ubicacion.longitude, inInclusiveRange(-74.068, -74.061), reason: edificio.etiqueta);
        // El centroide cae dentro de la caja de su propio contorno.
        final lats = edificio.perimetro.map((p) => p.latitude);
        final lngs = edificio.perimetro.map((p) => p.longitude);
        expect(edificio.perimetro.length, greaterThanOrEqualTo(3), reason: edificio.etiqueta);
        expect(edificio.ubicacion.latitude, inInclusiveRange(lats.reduce((a, b) => a < b ? a : b), lats.reduce((a, b) => a > b ? a : b)));
        expect(edificio.ubicacion.longitude, inInclusiveRange(lngs.reduce((a, b) => a < b ? a : b), lngs.reduce((a, b) => a > b ? a : b)));
      }
    });

    test('usa los números y nombres oficiales de OpenStreetMap', () {
      final oficiales = <int, String>{
        2: 'Fernando Barón',
        3: 'Gabriel Giraldo',
        8: 'Centro Ático',
        11: 'José Gabriel Maldonado',
        18: 'Talleres de Arquitectura',
        20: 'Jorge Hoyos',
        21: 'Emilio Arango',
        24: 'San Ignacio',
        25: 'Odontología',
        41: 'Pablo VI',
        51: 'Ángel Valtierra',
        52: 'Carlos Ortiz',
        53: 'Jesús Emilio Ramírez',
        67: 'José Rafael Arboleda',
      };
      oficiales.forEach((numero, nombre) {
        final edificio = cartografia.edificioPorNumero(numero);
        expect(edificio, isNotNull, reason: 'Edificio $numero');
        expect(edificio!.nombre, contains(nombre), reason: 'Edificio $numero');
        expect(edificio.etiqueta, 'Edificio $numero');
      });
      for (final (id, nombre) in <(String, String)>[
        (IdEdificio.biblioteca, 'Alfonso Borrero Cabal'),
        (IdEdificio.hospital, 'Hospital Universitario San Ignacio'),
        (IdEdificio.cienciasPuj, 'Edificio Ciencias PUJ'),
      ]) {
        final edificio = cartografia.edificioPorId(id)!;
        expect(edificio.numero, isNull, reason: id);
        expect(edificio.nombre, contains(nombre));
        expect(edificio.etiqueta, edificio.nombre);
      }
    });

    test('los pisos salen de building:levels', () {
      final niveles = <String, int>{
        IdEdificio.ed02: 10,
        IdEdificio.ed03: 9,
        IdEdificio.ed51: 7,
        IdEdificio.ed67: 8,
        IdEdificio.biblioteca: 6,
        IdEdificio.hospital: 9,
        IdEdificio.cienciasPuj: 12,
      };
      niveles.forEach((id, n) {
        final edificio = cartografia.edificioPorId(id)!;
        expect(edificio.niveles, n, reason: id);
        expect(edificio.pisos, <int>[for (var i = 1; i <= n; i++) i]);
      });
      for (final salon in cartografia.salones) {
        final edificio = cartografia.edificioPorId(salon.idEdificio)!;
        final niveles = edificio.niveles;
        expect(niveles, isNotNull);
        expect(salon.piso, isNot(0), reason: salon.codigo);
        expect(salon.piso, inInclusiveRange(-edificio.sotanos, niveles!), reason: salon.codigo);
      }
    });

    test('incluye los servicios del campus y los comercios aliados de la Calle 40C', () {
      final nombres = cartografia.negocios.map((n) => n.nombre).toList();
      expect(
        nombres,
        containsAll(<String>[
          'Biblioteca General Alfonso Borrero Cabal',
          'Hospital Universitario San Ignacio',
          'Cafetería La Central',
          'La Pecera',
          'Kiosko Urapanes',
          'La Conejera',
          'El Italiano Express',
        ]),
      );
      expect(cartografia.negocios.where((n) => n.categoria == CategoriaServicio.papeleria), isNotEmpty);
      // Nada ajeno al campus (hoteles, vivienda, otras universidades).
      for (final texto in <String>['Hotel', 'Gran Colombia', 'Distrital', 'Torres', 'Vivienda']) {
        expect(nombres.any((n) => n.contains(texto)), isFalse, reason: texto);
        expect(cartografia.edificios.any((e) => e.nombre.contains(texto)), isFalse, reason: texto);
      }
    });

    test('los horarios etiquetados en OpenStreetMap están confirmados y se evalúan', () {
      final central = cartografia.negocioPorId('cafeteria-la-central')!;
      expect(central.horarioConfirmado, isTrue);
      expect(central.estaAbierto(DateTime(2026, 11, 17, 10)), isTrue);
      expect(central.estaAbierto(DateTime(2026, 11, 17, 21)), isFalse);
      final biblioteca = cartografia.negocioPorId('biblioteca-general')!;
      expect(biblioteca.estaAbierto(DateTime(2026, 11, 17, 23, 30)), isTrue);
      expect(biblioteca.estaAbierto(DateTime(2026, 11, 17, 9)), isFalse);
      expect(cartografia.negocioPorId('la-pecera')!.horarioConfirmado, isFalse);
      for (final negocio in cartografia.negocios) {
        expect(cartografia.edificioPorId(negocio.idEdificioCercano), isNotNull, reason: negocio.nombre);
      }
    });

    test('las etiquetas de ubicación distinguen "dentro de" y "cerca de"', () {
      expect(
        cartografia.etiquetaUbicacion(cartografia.negocioPorId('biblioteca-general')!),
        'Biblioteca General Alfonso Borrero Cabal · Piso 1',
      );
      expect(cartografia.etiquetaUbicacion(cartografia.negocioPorId('cafeteria-la-central')!), startsWith('Cerca de'));
      expect(cartografia.idDestinoRuta(cartografia.negocioPorId('biblioteca-general')!), IdEdificio.biblioteca);
      expect(cartografia.idDestinoRuta(cartografia.negocioPorId('la-pecera')!), 'la-pecera');
    });

    test('los senderos tienen distancias reales en metros y escaleras marcadas', () {
      final escaleras = grafo.aristas.where((a) => a.esEscaleras).toList();
      expect(grafo.cantidadNodos, greaterThan(300));
      expect(escaleras.length, greaterThanOrEqualTo(20), reason: 'highway=steps');
      for (final arista in grafo.aristas) {
        final a = grafo.nodoPorId(arista.origenId)!.ubicacion;
        final b = grafo.nodoPorId(arista.destinoId)!.ubicacion;
        expect(arista.distanciaMetros, greaterThan(0), reason: arista.id);
        expect(arista.distanciaMetros, lessThan(400), reason: arista.id);
        // La polilínea real nunca es más corta que la línea recta entre sus extremos.
        expect(arista.distanciaMetros, greaterThanOrEqualTo(distanciaHaversine(a, b) - 0.5), reason: arista.id);
        expect(arista.factorCongestion, 1.0);
        expect(arista.bloqueada, isFalse);
      }
    });
  });

  group('Búsqueda', () {
    test('el salón 67-205 devuelve "Edificio 67 · Piso 2"', () {
      final salon = cartografia.buscarSalon('67-205');
      expect(salon, isNotNull);
      expect(salon!.etiquetaUbicacion(), 'Edificio 67 · Piso 2');
      expect(salon.idEdificio, IdEdificio.ed67);
      expect(cartografia.edificioPorId(salon.idEdificio)!.nombre, contains('José Rafael Arboleda'));
    });

    test('tolera mayúsculas y espacios y rechaza códigos inexistentes', () {
      for (final consulta in <String>['67-205', ' 67 - 205 ']) {
        expect(cartografia.buscarSalon(consulta)?.etiquetaUbicacion(), 'Edificio 67 · Piso 2', reason: consulta);
      }
      expect(cartografia.buscarSalon('51-lab2')?.etiquetaUbicacion(), 'Edificio 51 · Piso 1');
      expect(cartografia.buscarSalon('99-999'), isNull);
      expect(cartografia.buscarSalon(''), isNull);
    });

    test('todo salón declara su edificio y su piso', () {
      expect(cartografia.salones, isNotEmpty);
      final patron = RegExp(r'^Edificio \d+ · Piso -?\d+$');
      for (final salon in cartografia.salones) {
        final edificio = cartografia.edificioPorId(salon.idEdificio);
        expect(edificio, isNotNull, reason: salon.codigo);
        expect(salon.numeroEdificio, edificio!.numero);
        expect(salon.etiquetaUbicacion(), matches(patron), reason: salon.codigo);
        expect(salon.codigo, startsWith('${edificio.numero}-'));
      }
    });

    test('encuentra edificios por número, nombre y sin tildes', () {
      expect(cartografia.buscarEdificios('51').single.nombre, contains('Valtierra'));
      expect(cartografia.buscarEdificios('ed 3').single.nombre, contains('Gabriel Giraldo'));
      expect(cartografia.buscarEdificios('gabriel giraldo').single.numero, 3);
      expect(cartografia.buscarEdificios('angel valtierra').single.numero, 51);
      expect(cartografia.buscarEdificios('Fernando Barón').single.numero, 2);
      expect(cartografia.buscarEdificios('fernando baron').single.numero, 2);
      expect(cartografia.buscarEdificios('arboleda').single.numero, 67);
      expect(cartografia.buscarEdificios('atico').single.numero, 8);
      expect(cartografia.buscarEdificios('borrero').single.id, IdEdificio.biblioteca);
      expect(cartografia.buscarEdificios('hospital').single.id, IdEdificio.hospital);
      expect(cartografia.buscarEdificios('zzz'), isEmpty);
    });

    test('encuentra servicios por nombre', () {
      expect(cartografia.buscarNegocios('conejera').single.nombre, 'La Conejera');
      expect(cartografia.buscarNegocios('  PECERA ').single.nombre, 'La Pecera');
      expect(cartografia.buscarNegocios('urapanes').single.nombre, 'Kiosko Urapanes');
      expect(cartografia.buscarNegocios('italiano').single.nombre, 'El Italiano Express');
      expect(cartografia.buscarNegocios('cafeteria la central').single.id, 'cafeteria-la-central');
      expect(cartografia.buscarNegocios(''), isEmpty);
    });
  });

  group('Rutas A* sobre el campus real', () {
    final idsEdificios = cartografia.edificios.map((e) => e.id).toList();

    test('calcula la ruta entre cualquier par de edificios en < 2 s', () {
      var rutas = 0;
      var maxMs = 0;
      for (final origen in idsEdificios) {
        for (final destino in idsEdificios) {
          if (origen == destino) continue;
          final reloj = Stopwatch()..start();
          final ruta = grafo.calcularRutaAStar(entrada(origen), destino);
          reloj.stop();
          if (reloj.elapsedMilliseconds > maxMs) maxMs = reloj.elapsedMilliseconds;

          expect(reloj.elapsedMilliseconds, lessThan(2000), reason: '$origen -> $destino');
          expect(ruta.puntos.first, entrada(origen), reason: '$origen -> $destino');
          expect(ruta.puntos.last, entrada(destino), reason: '$origen -> $destino');
          expect(ruta.distanciaMetros, greaterThan(0));
          expect(ruta.tiempoEstimadoMinutos, greaterThanOrEqualTo(1));
          rutas++;
        }
      }
      expect(rutas, idsEdificios.length * (idsEdificios.length - 1));
      expect(maxMs, lessThan(2000));
    });

    test('también calcula rutas hacia servicios independientes y dentro de edificios', () {
      final origen = entrada(IdEdificio.ed67);
      for (final negocio in cartografia.negocios) {
        final ruta = grafo.calcularRutaAStar(origen, cartografia.idDestinoRuta(negocio));
        expect(ruta.puntos.last, entrada(cartografia.idDestinoRuta(negocio)), reason: negocio.nombre);
      }
    });

    test('evitarEscaleras cambia de camino y nunca pisa un escalón', () {
      var cambian = 0;
      var accesibles = 0;
      for (final origen in idsEdificios) {
        for (final destino in idsEdificios) {
          if (origen == destino) continue;
          final normal = grafo.calcularRutaAStar(entrada(origen), destino);
          RutaCalculada accesible;
          try {
            accesible = grafo.calcularRutaAStar(entrada(origen), destino, evitarEscaleras: true);
          } on RutaNoEncontradaException {
            continue; // cubierto en la prueba siguiente
          }
          accesibles++;
          expect(usaEscaleras(accesible), isFalse, reason: '$origen -> $destino');
          expect(
            accesible.distanciaMetros,
            greaterThanOrEqualTo(normal.distanciaMetros - 1e-6),
            reason: '$origen -> $destino',
          );
          if (usaEscaleras(normal)) {
            cambian++;
            expect(accesible.puntos, isNot(normal.puntos), reason: '$origen -> $destino');
            expect(accesible.distanciaMetros, greaterThan(normal.distanciaMetros));
          } else {
            expect(accesible.puntos, normal.puntos, reason: '$origen -> $destino');
          }
        }
      }
      expect(accesibles, greaterThan(100), reason: 'debe haber una zona amplia sin escalones');
      expect(cambian, greaterThanOrEqualTo(1), reason: 'al menos un par debe cambiar de camino');
    });

    test('un destino que solo se alcanza por escaleras lo dice con su propio motivo', () {
      var soloEscaleras = 0;
      for (final origen in idsEdificios) {
        for (final destino in idsEdificios) {
          if (origen == destino) continue;
          try {
            grafo.calcularRutaAStar(entrada(origen), destino, evitarEscaleras: true);
          } on RutaNoEncontradaException catch (e) {
            // Con el grafo conexo, la única causa posible son las escaleras.
            expect(e.motivo, MotivoSinRuta.soloPorEscaleras, reason: '$origen -> $destino');
            expect(() => grafo.calcularRutaAStar(entrada(origen), destino), returnsNormally);
            soloEscaleras++;
          }
        }
      }
      expect(soloEscaleras, greaterThan(0), reason: 'en OSM hay edificios solo accesibles por escalones');
    });

    test('las instrucciones avisan cuando la ruta usa escaleras', () {
      for (final origen in idsEdificios) {
        for (final destino in idsEdificios) {
          if (origen == destino) continue;
          final ruta = grafo.calcularRutaAStar(entrada(origen), destino);
          if (!usaEscaleras(ruta)) continue;
          expect(
            ruta.instrucciones.map((i) => i.maniobra),
            contains(TipoManiobra.escaleras),
            reason: '$origen -> $destino',
          );
          return;
        }
      }
      fail('ninguna ruta usó escaleras');
    });

    test('la distancia de ida y vuelta es la misma', () {
      final ida = grafo.calcularRutaAStar(entrada(IdEdificio.ed02), IdEdificio.ed67);
      final vuelta = grafo.calcularRutaAStar(entrada(IdEdificio.ed67), IdEdificio.ed02);
      expect(vuelta.distanciaMetros, closeTo(ida.distanciaMetros, 1e-6));
    });

    test('un cierre reportado en mitad de la ruta la desvía o la declara bloqueada', () {
      final grafoLocal = CampusCartography.seed().grafo;
      final ahora = DateTime(2026, 11, 17, 10);
      final origen = entrada(IdEdificio.ed02);
      final normal = grafoLocal.calcularRutaAStar(origen, IdEdificio.ed67);
      expect(normal.puntos.length, greaterThanOrEqualTo(3));

      // Arista de la ruta normal que une los puntos del medio.
      final k = normal.puntos.length ~/ 2;
      final aristaCerrada = grafoLocal.aristas.firstWhere((a) {
        final p = grafoLocal.nodoPorId(a.origenId)!.ubicacion;
        final q = grafoLocal.nodoPorId(a.destinoId)!.ubicacion;
        final u = normal.puntos[k - 1];
        final v = normal.puntos[k];
        return (p == u && q == v) || (p == v && q == u);
      });

      grafoLocal.aplicarReportesVigentes(
        <ReporteComunidad>[
          ReporteComunidad.nuevo(
            id: 'cierre-1',
            tipo: TipoReporte.cierre,
            ubicacion: normal.puntos[k],
            ahora: ahora,
            authorHash: calcularAuthorHash('uid-de-prueba'),
            idAristaAfectada: aristaCerrada.id,
          ),
        ],
        ahora: ahora,
      );
      expect(grafoLocal.aristaEfectiva(aristaCerrada.id)!.bloqueada, isTrue);

      try {
        final desviada = grafoLocal.calcularRutaAStar(origen, IdEdificio.ed67);
        expect(desviada.tieneDesvioPorReporte, isTrue);
        expect(desviada.puntos, isNot(normal.puntos));
        expect(desviada.distanciaMetros, greaterThan(normal.distanciaMetros));
      } on RutaNoEncontradaException catch (e) {
        expect(e.motivo, MotivoSinRuta.bloqueadoPorReportes);
      }
    });
  });
}
