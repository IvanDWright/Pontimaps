import 'package:flutter_test/flutter_test.dart';
import 'package:pontimaps_app/domain/services/opening_hours.dart';

void main() {
  /// Instante cuya hora de pared en Bogotá (UTC-5) es [h]:[m].
  DateTime bogota(int h, int m, {int dia = 18}) => DateTime.utc(2026, 11, dia, h + 5, m);

  EstadoHorario estado(String apertura, String cierre, DateTime ahora) =>
      calcularEstadoHorario(apertura: apertura, cierre: cierre, ahora: ahora);

  group('Horario sin cruce de medianoche (06:00–21:00)', () {
    test('Abierto en horario normal, con la hora de cierre', () {
      final e = estado('06:00', '21:00', bogota(12, 0));
      expect(e.estado, EstadoApertura.abierto);
      expect(e.etiqueta, 'Abierto');
      expect(e.detalle, 'Cierra a las 21:00');
    });

    test('la apertura se incluye', () {
      expect(estado('06:00', '21:00', bogota(6, 0)).estado, EstadoApertura.abierto);
    });

    test('Cerrado antes de abrir, indicando cuándo abre', () {
      final e = estado('06:00', '21:00', bogota(5, 59));
      expect(e.estado, EstadoApertura.cerrado);
      expect(e.etiqueta, 'Cerrado');
      expect(e.detalle, 'Abre a las 06:00');
    });

    test('el cierre se excluye: a las 21:00 ya está cerrado', () {
      expect(estado('06:00', '21:00', bogota(21, 0)).estado, EstadoApertura.cerrado);
      expect(estado('06:00', '21:00', bogota(22, 30)).estado, EstadoApertura.cerrado);
    });
  });

  group('Cierra pronto (< 30 min)', () {
    test('a 29 min del cierre avisa «Cierra pronto»', () {
      final e = estado('06:00', '21:00', bogota(20, 31));
      expect(e.estado, EstadoApertura.cierraPronto);
      expect(e.etiqueta, 'Cierra pronto');
      expect(e.detalle, 'Cierra en 29 min');
      expect(e.estaAbierto, isTrue);
    });

    test('a exactamente 30 min todavía es Abierto (el umbral es estricto)', () {
      expect(estado('06:00', '21:00', bogota(20, 30)).estado, EstadoApertura.abierto);
    });

    test('a 1 min del cierre', () {
      final e = estado('06:00', '21:00', bogota(20, 59));
      expect(e.estado, EstadoApertura.cierraPronto);
      expect(e.detalle, 'Cierra en 1 min');
    });
  });

  group('Cruce de medianoche (10:00–00:00, Biblioteca)', () {
    test('Abierto por la tarde y cierra pronto antes de medianoche', () {
      expect(estado('10:00', '00:00', bogota(15, 0)).estado, EstadoApertura.abierto);
      final e = estado('10:00', '00:00', bogota(23, 45));
      expect(e.estado, EstadoApertura.cierraPronto);
      expect(e.detalle, 'Cierra en 15 min');
    });

    test('a medianoche cierra y de madrugada sigue cerrado', () {
      expect(estado('10:00', '00:00', bogota(0, 0)).estado, EstadoApertura.cerrado);
      final e = estado('10:00', '00:00', bogota(3, 30));
      expect(e.estado, EstadoApertura.cerrado);
      expect(e.detalle, 'Abre a las 10:00');
    });

    test('horario nocturno 22:00–02:00: abierto antes y después de medianoche', () {
      expect(estado('22:00', '02:00', bogota(23, 0)).estado, EstadoApertura.abierto);
      expect(estado('22:00', '02:00', bogota(0, 30)).estado, EstadoApertura.abierto);
      final e = estado('22:00', '02:00', bogota(1, 45));
      expect(e.estado, EstadoApertura.cierraPronto);
      expect(e.detalle, 'Cierra en 15 min');
      expect(estado('22:00', '02:00', bogota(2, 0)).estado, EstadoApertura.cerrado);
      expect(estado('22:00', '02:00', bogota(12, 0)).estado, EstadoApertura.cerrado);
    });

    test('cierra pronto cruzando medianoche: 23:50 con cierre 00:10', () {
      final e = estado('08:00', '00:10', bogota(23, 50));
      expect(e.estado, EstadoApertura.cierraPronto);
      expect(e.detalle, 'Cierra en 20 min');
    });
  });

  test('apertura == cierre es 24 horas: siempre abierto y nunca «cierra pronto»', () {
    for (final h in <int>[0, 3, 12, 23]) {
      final e = estado('00:00', '00:00', bogota(h, 59));
      expect(e.estado, EstadoApertura.abierto);
      expect(e.detalle, 'Abierto las 24 horas');
    }
  });

  group('Zona horaria America/Bogota', () {
    test('un instante UTC se evalúa en hora de Colombia (UTC-5)', () {
      // 14:30Z = 09:30 en Bogotá: la cafetería de 06:00–21:00 está abierta,
      // pero la Biblioteca (10:00) aún no abre.
      final instante = DateTime.utc(2026, 11, 18, 14, 30);
      expect(estado('06:00', '21:00', instante).estado, EstadoApertura.abierto);
      expect(estado('10:00', '00:00', instante).estado, EstadoApertura.cerrado);
    });

    test('el día cambia a las 05:00Z (medianoche en Bogotá)', () {
      final antes = horaBogota(DateTime.utc(2026, 11, 19, 4, 59));
      final despues = horaBogota(DateTime.utc(2026, 11, 19, 5, 0));
      expect(antes.day, 18);
      expect(antes.hour, 23);
      expect(despues.day, 19);
      expect(despues.hour, 0);
    });

    test('un DateTime local equivalente da el mismo resultado que su UTC', () {
      final utc = DateTime.utc(2026, 11, 18, 20, 45); // 15:45 en Bogotá
      final local = utc.toLocal();
      expect(estado('06:00', '16:00', local).estado, estado('06:00', '16:00', utc).estado);
      expect(estado('06:00', '16:00', local).detalle, estado('06:00', '16:00', utc).detalle);
    });
  });
}
