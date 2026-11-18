import 'package:flutter_test/flutter_test.dart';
import 'package:pontimaps_app/data/consent_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ConsentController', () {
    test('sin respuesta previa el consentimiento está pendiente y no hay GPS', () async {
      final c = ConsentController(MemoryConsentRepository());
      expect(c.cargado, isFalse);
      await c.cargar();

      expect(c.cargado, isTrue);
      expect(c.estado.decision, DecisionGps.pendiente);
      expect(c.estado.resuelto, isFalse);
      expect(c.estado.gpsActivo, isFalse);
      expect(c.estado.modoVisitante, isTrue);
    });

    test('aceptar activa el GPS; pausar lo apaga sin perder la decisión', () async {
      final repo = MemoryConsentRepository();
      final c = ConsentController(repo);
      await c.cargar();

      await c.aceptarGps();
      expect(c.estado.resuelto, isTrue);
      expect(c.estado.gpsActivo, isTrue);

      await c.pausarGps(true);
      expect(c.estado.decision, DecisionGps.aceptado);
      expect(c.estado.gpsActivo, isFalse);
      expect(c.estado.resuelto, isTrue);

      await c.pausarGps(false);
      expect(c.estado.gpsActivo, isTrue);
      expect((await repo.cargar()).gpsActivo, isTrue);
    });

    test('rechazar resuelve el consentimiento pero deja el GPS apagado', () async {
      final c = ConsentController(MemoryConsentRepository());
      await c.cargar();
      await c.rechazarGps();

      expect(c.estado.resuelto, isTrue);
      expect(c.estado.gpsActivo, isFalse);
    });

    test('un texto de otra versión vuelve a pedir el consentimiento', () async {
      final repo = MemoryConsentRepository(
        const ConsentState(decision: DecisionGps.aceptado, version: 'vieja'),
      );
      final c = ConsentController(repo);
      await c.cargar();

      expect(c.estado.decision, DecisionGps.pendiente);
      expect(c.estado.resuelto, isFalse);
      expect(c.estado.version, kConsentVersion);
    });

    test('notifica a quienes escuchan (el enrutador) en cada cambio', () async {
      final c = ConsentController(MemoryConsentRepository());
      var avisos = 0;
      c.addListener(() => avisos++);
      await c.cargar();
      await c.aceptarGps();
      await c.pausarGps(true);
      expect(avisos, 3);
    });
  });

  group('SharedPreferencesConsentRepository', () {
    test('guarda y recupera la decisión, la versión y la pausa', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesConsentRepository(prefs);

      expect((await repo.cargar()).decision, DecisionGps.pendiente);

      await repo.guardar(
        const ConsentState(decision: DecisionGps.aceptado, gpsPausado: true),
      );
      final leido = await repo.cargar();
      expect(leido.decision, DecisionGps.aceptado);
      expect(leido.version, kConsentVersion);
      expect(leido.gpsPausado, isTrue);
    });

    test('solo guarda preferencias de consentimiento, nunca coordenadas (Regla 4)', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesConsentRepository(prefs);
      await repo.guardar(const ConsentState(decision: DecisionGps.aceptado));

      expect(prefs.getKeys(), isNotEmpty);
      expect(prefs.getKeys().every((k) => k.startsWith('consent.')), isTrue);
    });
  });
}
