import 'package:flutter_test/flutter_test.dart';
import 'package:pontimaps_app/data/campus_cartography.dart';
import 'package:pontimaps_app/domain/search/campus_search.dart';
import 'package:pontimaps_app/models/salon.dart';

void main() {
  late CampusCartography cartografia;
  late CampusSearch busqueda;

  setUp(() {
    cartografia = CampusCartography.seed();
    busqueda = CampusSearch(cartografia);
  });

  bool hayEdificio(ResultadosAgrupados r, {int? numero, String? id}) => r.edificios.any(
        (e) => (numero != null && e.edificio.numero == numero) || (id != null && e.edificio.id == id),
      );

  bool haySalon(ResultadosAgrupados r, String codigo) =>
      r.salones.any((s) => s.salon.codigo == codigo);

  group('RF-BUS-03 · búsqueda tolerante (tabla de consultas)', () {
    final casosEdificio = <String, int>{
      '51': 51,
      'ed 51': 51,
      'ED 51': 51,
      'edificio 51': 51,
      'Edificio 67': 67,
      '67': 67,
      'arboleda': 67,
      'ARBOLEDA': 67,
      'jose rafael': 67,
      'José Rafael Arboleda': 67,
      'baron': 2,
      'Barón': 2,
      'fernando': 2,
      '  gabriel   giraldo ': 3,
    };
    for (final entrada in casosEdificio.entries) {
      test('"${entrada.key}" encuentra el edificio ${entrada.value}', () {
        expect(hayEdificio(busqueda.buscar(entrada.key), numero: entrada.value), isTrue);
      });
    }

    final casosSalon = <String, String>{
      '67-205': '67-205',
      '67205': '67-205',
      '67 205': '67-205',
      '67 - 205': '67-205',
      '205': '67-205',
      '12-s101': '12-S101',
      '12S101': '12-S101',
      '51-lab2': '51-LAB2',
    };
    for (final entrada in casosSalon.entries) {
      test('"${entrada.key}" encuentra el salón ${entrada.value}', () {
        expect(haySalon(busqueda.buscar(entrada.key), entrada.value), isTrue);
      });
    }

    test('"cafeteria" y "CAFETERÍA" encuentran el servicio', () {
      for (final consulta in <String>['cafeteria', 'CAFETERÍA']) {
        final r = busqueda.buscar(consulta);
        expect(
          r.servicios.any((s) => s.negocio.nombre.contains('Cafetería')),
          isTrue,
          reason: consulta,
        );
      }
    });

    test('"biblioteca" y "hospital" encuentran sus edificios', () {
      expect(hayEdificio(busqueda.buscar('biblioteca'), id: IdEdificio.biblioteca), isTrue);
      expect(hayEdificio(busqueda.buscar('hospital'), id: IdEdificio.hospital), isTrue);
    });

    test('consulta vacía, solo espacios o sin coincidencias no devuelve nada', () {
      for (final consulta in <String>['', '   ', 'zzzzz', 'zzzz-999']) {
        expect(busqueda.buscar(consulta).vacio, isTrue, reason: '"$consulta"');
      }
    });
  });

  group('RF-BUS-02 · todo salón muestra Edificio + Piso', () {
    test('cada salón del catálogo se encuentra por su código y trae ambos datos', () {
      final patron = RegExp(r'^Edificio \S+ · Piso -?\d+');
      for (final salon in cartografia.salones) {
        final resultado = busqueda.buscar(salon.codigo).salones.where((s) => s.salon == salon);
        expect(resultado, hasLength(1), reason: salon.codigo);
        expect(resultado.single.subtitulo, matches(patron), reason: salon.codigo);
        expect(resultado.single.edificio.id, salon.idEdificio, reason: salon.codigo);
      }
    });

    test('el sótano se nombra explícitamente', () {
      final sotano = cartografia.buscarSalon('12-S101')!;
      expect(etiquetaSalon(sotano), 'Edificio 12 · Piso -1 (sótano 1)');
      expect(etiquetaSalon(cartografia.buscarSalon('67-205')!), 'Edificio 67 · Piso 2');
    });

    test('un salón sin número de edificio usa el nombre del edificio', () {
      const salon = Salon(
        codigo: 'B-1',
        piso: 2,
        idEdificio: 'biblioteca',
        nombreEdificio: 'Biblioteca General',
        numeroEdificio: null,
      );
      expect(etiquetaSalon(salon), 'Biblioteca General · Piso 2');
    });
  });

  test('los resultados por grupo están acotados', () {
    final r = busqueda.buscar('1');
    expect(r.edificios.length, lessThanOrEqualTo(CampusSearch.maximoPorGrupo));
    expect(r.salones.length, lessThanOrEqualTo(CampusSearch.maximoPorGrupo));
  });
}
