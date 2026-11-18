import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pontimaps_app/data/campus_cartography.dart';
import 'package:pontimaps_app/domain/routing/grafo_campus.dart';

void main() {
  final cartografia = CampusCartography.seed();

  LatLng entrada(String idEdificio) => cartografia.entradasDe(idEdificio).first.ubicacion;

  // El Edificio 2 está en la zona del campus que se recorre sin escalones.
  final origen = entrada(IdEdificio.ed02);

  group('Acceso por ascensor en el catálogo real', () {
    test('Salón 67-205 (Edificio 67 · Piso 2): se llega en ascensor y hay varios', () {
      final salon = cartografia.buscarSalon('67-205')!;
      final edificio = cartografia.edificioPorId(salon.idEdificio)!;

      expect(salon.etiquetaUbicacion(), 'Edificio 67 · Piso 2');
      expect(edificio.puedeLlegarEnAscensor(2), isTrue);
      expect(edificio.puedeLlegarEnAscensor(salon.piso), isTrue);
      expect(edificio.tieneAscensor, isTrue);
      expect(edificio.tieneMultiplesAscensores, isTrue);
      expect(edificio.etiquetaAccesibilidadVertical(2), 'Acceso por ascensor disponible (múltiples ascensores)');
    });

    test('la ruta hacia el salón 67-205 informa del ascensor y de que hay varios', () {
      final salon = cartografia.buscarSalon('67-205')!;
      final ruta = cartografia.calcularRutaHaciaSalon(origen, salon);

      expect(ruta.puntos.last, entrada(IdEdificio.ed67));
      final acceso = ruta.accesoVertical!;
      expect(acceso.piso, 2);
      expect(acceso.llegaEnAscensor, isTrue);
      expect(acceso.multiplesAscensores, isTrue);
      expect(acceso.etiqueta, contains('múltiples ascensores'));
      expect(acceso.advertencia, isNull);
    });

    test('Edificio 18 (Talleres de Arquitectura), piso 2: sin ascensor', () {
      final salon = cartografia.buscarSalon('18-201')!;
      final edificio = cartografia.edificioPorId(salon.idEdificio)!;

      expect(salon.etiquetaUbicacion(), 'Edificio 18 · Piso 2');
      expect(edificio.nombre, contains('Talleres de Arquitectura'));
      expect(edificio.niveles, 2);
      expect(edificio.tieneAscensor, isFalse);
      expect(edificio.tieneMultiplesAscensores, isFalse);
      expect(edificio.puedeLlegarEnAscensor(2), isFalse);
      expect(edificio.etiquetaAccesibilidadVertical(2), 'Sin ascensor (solo escaleras internas para piso 2)');
    });

    test('con evitarEscaleras la ruta al Edificio 18 piso 2 trae la advertencia', () {
      final salon = cartografia.buscarSalon('18-201')!;

      final conAviso = cartografia.calcularRutaHaciaSalon(origen, salon, evitarEscaleras: true);
      final acceso = conAviso.accesoVertical!;
      expect(acceso.llegaEnAscensor, isFalse);
      expect(acceso.multiplesAscensores, isFalse);
      expect(acceso.etiqueta, contains('Sin ascensor'));
      expect(acceso.advertencia, isNotNull);
      expect(acceso.advertencia, allOf(contains('Edificio 18'), contains('no tiene ascensor'), contains('piso 2')));

      // Sin pedir evitar escaleras, la información está pero no hay aviso.
      final sinPedirlo = cartografia.calcularRutaHaciaSalon(origen, salon);
      expect(sinPedirlo.accesoVertical!.llegaEnAscensor, isFalse);
      expect(sinPedirlo.accesoVertical!.advertencia, isNull);
    });

    test('el piso 1 de un edificio sin rampa avisa de los escalones', () {
      final ed18 = cartografia.edificioPorId(IdEdificio.ed18)!;
      expect(ed18.tieneAccesoMovilidadReducida, isFalse);
      expect(ed18.puedeLlegarEnAscensor(1), isFalse);
      expect(ed18.accesoVertical(1, evitarEscaleras: true).advertencia, contains('escalones'));
      final ed15 = cartografia.edificioPorNumero(15)!;
      expect(ed15.niveles, 1);
      expect(ed15.puedeLlegarEnAscensor(1), isTrue);
      expect(ed15.etiquetaAccesibilidadVertical(1), 'Acceso a nivel o por rampa');
    });

    test('un solo ascensor se dice sin "múltiples"', () {
      for (final numero in <int>[25, 41, 50, 53]) {
        final e = cartografia.edificioPorNumero(numero)!;
        expect(e.tieneAscensor, isTrue, reason: 'Edificio $numero');
        expect(e.tieneMultiplesAscensores, isFalse, reason: 'Edificio $numero');
        expect(e.etiquetaAccesibilidadVertical(2), 'Acceso por ascensor disponible', reason: 'Edificio $numero');
      }
    });

    test('los edificios sin datos de ascensor quedan "sin confirmar", no "sin ascensor"', () {
      final hospital = cartografia.edificioPorId(IdEdificio.hospital)!;
      expect(hospital.niveles, 9);
      expect(hospital.accesibilidadConfirmada, isFalse);
      expect(hospital.puedeLlegarEnAscensor(3), isFalse);
      expect(hospital.etiquetaAccesibilidadVertical(3), 'Acceso por ascensor sin confirmar para el piso 3');
      expect(hospital.etiquetaAccesibilidadVertical(3), isNot(contains('Sin ascensor')));
    });

    test('la Biblioteca, el Edificio 12 y el Edificio Ciencias PUJ tienen 2 sótanos y ascensores confirmados', () {
      for (final id in <String>[IdEdificio.biblioteca, IdEdificio.cienciasPuj]) {
        final e = cartografia.edificioPorId(id)!;
        expect(e.numero, isNull, reason: 'OSM no les da número (el JSON trae uno inventado)');
        expect(e.accesibilidadConfirmada, isTrue, reason: id);
        expect(e.tieneMultiplesAscensores, isTrue, reason: id);
        expect(e.sotanos, 2, reason: id);
        expect(e.pisosSotano, <int>[-1, -2], reason: id);
        expect(e.puedeLlegarEnAscensor(e.niveles!), isTrue, reason: id);
        expect(e.puedeLlegarEnAscensor(-1), isTrue, reason: '$id sótano 1');
        expect(e.puedeLlegarEnAscensor(-2), isTrue, reason: '$id sótano 2');
        expect(e.puedeLlegarEnAscensor(-3), isFalse, reason: '$id no tiene sótano 3');
      }
      final ed12 = cartografia.edificioPorId(IdEdificio.ed12)!;
      expect(ed12.sotanos, 2);
      final labSotano = cartografia.buscarSalon('12-S101')!;
      expect(labSotano.piso, -1);
      expect(labSotano.etiquetaUbicacion(), 'Edificio 12 · Piso -1');
      final rutaSotano = cartografia.calcularRutaHaciaSalon(
        entrada(IdEdificio.ed12),
        labSotano,
        evitarEscaleras: true,
      );
      expect(rutaSotano.accesoVertical!.piso, -1);
      expect(rutaSotano.accesoVertical!.llegaEnAscensor, isTrue);
      expect(rutaSotano.accesoVertical!.multiplesAscensores, isTrue);
      expect(rutaSotano.accesoVertical!.advertencia, isNull);
    });

    test('una ruta sin piso, o hacia un servicio independiente, no trae acceso vertical', () {
      expect(cartografia.calcularRuta(origen, IdEdificio.ed67).accesoVertical, isNull);
      expect(cartografia.calcularRuta(origen, 'la-pecera', piso: 1).accesoVertical, isNull);
    });

    test('calcularRuta propaga los errores del motor (destino solo por escaleras)', () {
      expect(
        () => cartografia.calcularRuta(origen, IdEdificio.ed51, piso: 1, evitarEscaleras: true),
        throwsA(isA<RutaNoEncontradaException>().having((e) => e.motivo, 'motivo', MotivoSinRuta.soloPorEscaleras)),
      );
    });
  });

  group('Coherencia con docs/edificios_ascensores.json', () {
    final datos = jsonDecode(File('docs/edificios_ascensores.json').readAsStringSync()) as Map<String, dynamic>;
    final entradas = (datos['edificios'] as List<dynamic>).cast<Map<String, dynamic>>();

    test('cada edificio del JSON con número oficial coincide con el catálogo', () {
      var cruzados = 0;
      for (final x in entradas) {
        final numero = int.tryParse(x['numero'] as String);
        final edificio = numero == null ? null : cartografia.edificioPorNumero(numero);
        if (edificio == null) continue; // sin número (Biblioteca), o numeración que OSM no tiene
        cruzados++;
        expect(edificio.tieneAscensor, x['tieneAscensor'], reason: x['id'] as String);
        expect(edificio.tieneMultiplesAscensores, x['tieneMultiplesAscensores'], reason: x['id'] as String);
        expect(edificio.tieneAccesoMovilidadReducida, x['accesoMovilidadReducida'], reason: x['id'] as String);
        expect(edificio.niveles, x['pisos'], reason: x['id'] as String);
        expect(edificio.sotanos, x['sotanos'], reason: x['id'] as String);
        expect(edificio.accesibilidadConfirmada, isTrue, reason: x['id'] as String);
      }
      expect(cruzados, 20);
    });

    test('el catálogo solo marca como confirmados los edificios que están en el JSON', () {
      final confirmados = cartografia.edificios.where((e) => e.accesibilidadConfirmada).length;
      expect(confirmados, 22, reason: '20 numerados + Biblioteca + Edificio Ciencias PUJ');
      for (final e in cartografia.edificios.where((e) => !e.accesibilidadConfirmada)) {
        expect(e.tieneAscensor || e.tieneMultiplesAscensores || e.tieneAccesoMovilidadReducida, isFalse, reason: e.etiqueta);
      }
    });

    test('ningún edificio de un solo nivel tiene ascensor y varios implican ascensor', () {
      for (final e in cartografia.edificios) {
        if (e.niveles == 1) expect(e.tieneAscensor, isFalse, reason: e.etiqueta);
        if (e.tieneMultiplesAscensores) expect(e.tieneAscensor, isTrue, reason: e.etiqueta);
      }
    });
  });
}
