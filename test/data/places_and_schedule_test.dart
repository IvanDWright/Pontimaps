import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pontimaps_app/core/utils/author_hash.dart';
import 'package:pontimaps_app/data/campus_cartography.dart';
import 'package:pontimaps_app/data/places_repository.dart';
import 'package:pontimaps_app/data/schedule_repository.dart';
import 'package:pontimaps_app/domain/services/next_class.dart';
import 'package:pontimaps_app/domain/services/opening_hours.dart';
import 'package:pontimaps_app/models/horario_usuario.dart';
import 'package:pontimaps_app/models/negocio_servicio.dart';
import 'package:pontimaps_app/models/reporte_comunidad.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late CampusCartography cartografia;

  setUp(() => cartografia = CampusCartography.seed());

  // 18 de noviembre de 2026 es miércoles. 15:00Z = 10:00 en Bogotá.
  final miercoles10 = DateTime.utc(2026, 11, 18, 15);

  group('Directorio de lugares (RF-DIR-01 y RF-DIR-04)', () {
    test('expone los lugares semilla del campus con su estado de apertura', () {
      final repo = SeedPlacesRepository(cartografia);
      final lugares = repo.lugares(ahora: miercoles10);
      expect(lugares.length, greaterThanOrEqualTo(10));

      final nombres = lugares.map((l) => l.negocio.nombre).join(' | ');
      for (final esperado in <String>[
        'Biblioteca General',
        'Cafetería La Central',
        'La Pecera',
        'Kiosko Urapanes',
        'La Conejera',
        'Papelería El Círculo',
      ]) {
        expect(nombres, contains(esperado));
      }
      for (final l in lugares) {
        expect(l.ubicacionEtiqueta, isNotEmpty);
        expect(l.horario.etiqueta, isNotEmpty);
      }
    });

    test('los filtros por categoría separan cafeterías y papelerías', () {
      final repo = SeedPlacesRepository(cartografia);
      final cafes = repo.lugares(filtro: FiltroDirectorio.cafeterias, ahora: miercoles10);
      final papelerias = repo.lugares(filtro: FiltroDirectorio.papelerias, ahora: miercoles10);

      expect(cafes, isNotEmpty);
      expect(cafes.every((l) => l.negocio.categoria == CategoriaServicio.cafeteria), isTrue);
      expect(papelerias, isNotEmpty);
      expect(
        papelerias.every(
          (l) =>
              l.negocio.categoria == CategoriaServicio.papeleria ||
              l.negocio.categoria == CategoriaServicio.comercioAliado,
        ),
        isTrue,
      );
      expect(
        repo.lugares(filtro: FiltroDirectorio.todos, ahora: miercoles10).length,
        greaterThan(cafes.length + papelerias.length - 1),
      );
    });

    test('sin reporte de fila vigente se muestra «Sin datos recientes», nunca «Sin fila»', () {
      final repo = SeedPlacesRepository(cartografia);
      for (final l in repo.lugares(ahora: miercoles10)) {
        expect(l.nivelFila, isNull);
        expect(l.etiquetaFila, 'Sin datos recientes');
      }
      expect(etiquetaNivelFila(null), isNot('Sin fila'));
    });

    test('los reportes «Fila larga» vigentes anclados al lugar fijan su nivel', () {
      final autor = calcularAuthorHash('uid');
      ReporteComunidad fila(String id, String lugar, {int confirmaciones = 0}) {
        var r = ReporteComunidad.nuevo(
          id: id,
          tipo: TipoReporte.fila,
          ubicacion: const LatLng(4.6285, -74.0645),
          ahora: miercoles10,
          authorHash: autor,
          idLugar: lugar,
        ).sinAutor();
        for (var i = 0; i < confirmaciones; i++) {
          r = r.confirmar(miercoles10);
        }
        return r;
      }

      final ahora = miercoles10.add(const Duration(minutes: 5));
      expect(nivelFilaDe('cafeteria-la-central', <ReporteComunidad>[fila('1', 'cafeteria-la-central')], ahora),
          NivelCongestion.media);
      expect(
        nivelFilaDe(
          'cafeteria-la-central',
          <ReporteComunidad>[fila('1', 'cafeteria-la-central', confirmaciones: 1)],
          ahora,
        ),
        NivelCongestion.alta,
      );
      expect(
        nivelFilaDe(
          'cafeteria-la-central',
          <ReporteComunidad>[fila('1', 'cafeteria-la-central'), fila('2', 'cafeteria-la-central')],
          ahora,
        ),
        NivelCongestion.alta,
      );
      // De otro lugar, vencido o de otro tipo: no cuenta.
      expect(nivelFilaDe('cafeteria-la-central', <ReporteComunidad>[fila('1', 'la-pecera')], ahora), isNull);
      expect(
        nivelFilaDe(
          'cafeteria-la-central',
          <ReporteComunidad>[fila('1', 'cafeteria-la-central')],
          miercoles10.add(const Duration(minutes: 61)),
        ),
        isNull,
      );
    });

    test('el estado de apertura usa la hora de Bogotá y cruza la medianoche', () {
      final repo = SeedPlacesRepository(cartografia);
      LugarDirectorio lugar(String id, DateTime ahora) =>
          repo.lugares(ahora: ahora).firstWhere((l) => l.negocio.id == id);

      // 10:00 en Bogotá: la Biblioteca (10:00–00:00) acaba de abrir.
      expect(lugar('biblioteca-general', miercoles10).horario.estado, EstadoApertura.abierto);
      // 23:45 en Bogotá (04:45Z del día siguiente): cierra pronto.
      expect(
        lugar('biblioteca-general', DateTime.utc(2026, 11, 19, 4, 45)).horario.estado,
        EstadoApertura.cierraPronto,
      );
      // Cafetería La Central (06:00–21:00) a las 20:45: cierra pronto; a las 21:00, cerrada.
      expect(
        lugar('cafeteria-la-central', DateTime.utc(2026, 11, 19, 1, 45)).horario.estado,
        EstadoApertura.cierraPronto,
      );
      expect(
        lugar('cafeteria-la-central', DateTime.utc(2026, 11, 19, 2, 0)).horario.estado,
        EstadoApertura.cerrado,
      );
    });
  });

  group('Horario local (RF-HOR-01 y RF-HOR-02)', () {
    BloqueHorario bloque({
      String id = 'b1',
      int dia = 3,
      int inicio = 600,
      int fin = 720,
      String edificio = IdEdificio.ed67,
      String salon = '67-205',
    }) => BloqueHorario(
          id: id,
          materia: 'Cálculo',
          diaSemana: dia,
          horaInicio: inicio,
          horaFin: fin,
          idEdificio: edificio,
          codigoSalon: salon,
        );

    test('valida contra el catálogo: sin texto libre inexistente', () {
      expect(validarBloque(bloque(), cartografia), isNull);
      // La hora de fin posterior a la de inicio la exige el propio BloqueHorario
      // (no se puede construir uno inválido) y la pantalla de edición la valida antes.
      expect(validarBloque(bloque(edificio: 'no-existe'), cartografia), ErrorBloque.edificioInexistente);
      expect(validarBloque(bloque(salon: '99-999'), cartografia), ErrorBloque.salonInexistente);
      // Un salón real pero de otro edificio tampoco vale.
      expect(validarBloque(bloque(salon: '51-101'), cartografia), ErrorBloque.salonInexistente);
    });

    test('detecta solapamientos el mismo día y no consigo mismo', () {
      final a = bloque(id: 'a', inicio: 600, fin: 720);
      final solapa = bloque(id: 'b', inicio: 700, fin: 800);
      final contigua = bloque(id: 'c', inicio: 720, fin: 800);
      final otroDia = bloque(id: 'd', dia: 4, inicio: 600, fin: 720);

      expect(bloquesSolapados(solapa, <BloqueHorario>[a]), <BloqueHorario>[a]);
      expect(bloquesSolapados(contigua, <BloqueHorario>[a]), isEmpty);
      expect(bloquesSolapados(otroDia, <BloqueHorario>[a]), isEmpty);
      expect(bloquesSolapados(a, <BloqueHorario>[a]), isEmpty);
    });

    test('se guarda por cuenta en SharedPreferences y no se mezcla entre cuentas', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesScheduleRepository(prefs);

      await repo.guardar('cuenta-a', <BloqueHorario>[bloque(id: 'x')]);
      expect(await repo.cargar('cuenta-a'), <BloqueHorario>[bloque(id: 'x')]);
      expect(await repo.cargar('cuenta-b'), isEmpty);
      expect(prefs.getKeys().every((k) => k.startsWith('schedule.')), isTrue);
    });

    test('un JSON dañado o un bloque inválido se descarta sin romper la app', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'schedule.v1.cuenta': 'esto no es json',
        'schedule.v1.otra': '[{"id":"x","materia":"M","diaSemana":9},42]',
      });
      final repo = SharedPreferencesScheduleRepository(await SharedPreferences.getInstance());
      expect(await repo.cargar('cuenta'), isEmpty);
      expect(await repo.cargar('otra'), isEmpty);
    });

    test('el controlador no guarda nada para el visitante (sin cuenta)', () async {
      final repo = MemoryScheduleRepository();
      final controlador = ScheduleController(repo);
      await controlador.usarCuenta(null);

      expect(await controlador.guardar(bloque()), isFalse);
      expect(controlador.bloques, isEmpty);
      expect(await repo.cargar('cualquiera'), isEmpty);
    });

    test('agrega, edita y elimina por cuenta y ordena por día y hora', () async {
      final controlador = ScheduleController(MemoryScheduleRepository());
      await controlador.usarCuenta('cuenta-a');
      await controlador.guardar(bloque(id: 'tarde', dia: 3, inicio: 840, fin: 900));
      await controlador.guardar(bloque(id: 'manana', dia: 3, inicio: 480, fin: 540));
      await controlador.guardar(bloque(id: 'lunes', dia: 1, inicio: 900, fin: 960));
      expect(controlador.bloques.map((b) => b.id), <String>['lunes', 'manana', 'tarde']);

      await controlador.guardar(bloque(id: 'manana', dia: 3, inicio: 480, fin: 600));
      expect(controlador.bloques.firstWhere((b) => b.id == 'manana').horaFin, 600);

      await controlador.eliminar('lunes');
      expect(controlador.bloques.map((b) => b.id), <String>['manana', 'tarde']);

      await controlador.usarCuenta('cuenta-b');
      expect(controlador.bloques, isEmpty, reason: 'el horario de otra cuenta no se muestra');
      await controlador.usarCuenta('cuenta-a');
      expect(controlador.bloques, hasLength(2));
    });
  });

  group('Próxima clase (RF-HOR-06)', () {
    final perfil = UsuarioPerfil.institucional(
      uid: 'u',
      correoInstitucional: 'a@javeriana.edu.co',
      rol: RolUsuario.estudiante,
      emailVerified: true,
    );

    BloqueHorario clase(String id, int dia, int h, int m) => BloqueHorario(
          id: id,
          materia: 'Materia $id',
          diaSemana: dia,
          horaInicio: h * 60 + m,
          horaFin: h * 60 + m + 60,
          idEdificio: IdEdificio.ed67,
          codigoSalon: '67-205',
        );

    test('la clase que empezó hace menos de 10 min sigue siendo la próxima', () {
      // Miércoles 10:09 en Bogotá (15:09Z) con una clase a las 10:00.
      final proxima = calcularProximaClase(
        perfil,
        <BloqueHorario>[clase('a', 3, 10, 0), clase('b', 3, 12, 0)],
        DateTime.utc(2026, 11, 18, 15, 9),
      )!;
      expect(proxima.bloque.id, 'a');
      expect(proxima.yaEmpezo, isTrue);
      expect(proxima.estado, 'Tu clase empezó hace 9 min');
    });

    test('con más de 10 min de retraso pasa a la siguiente', () {
      final proxima = calcularProximaClase(
        perfil,
        <BloqueHorario>[clase('a', 3, 10, 0), clase('b', 3, 12, 0)],
        DateTime.utc(2026, 11, 18, 15, 11),
      )!;
      expect(proxima.bloque.id, 'b');
      expect(proxima.estado, 'Empieza en 109 min');
    });

    test('exactamente a los 10 min todavía cuenta (inicio >= ahora - 10 min)', () {
      final proxima = calcularProximaClase(
        perfil,
        <BloqueHorario>[clase('a', 3, 10, 0)],
        DateTime.utc(2026, 11, 18, 15, 10),
      );
      expect(proxima?.bloque.id, 'a');
    });

    test('sin clases hoy muestra la de otro día e indica cuándo', () {
      final manana = calcularProximaClase(
        perfil,
        <BloqueHorario>[clase('j', 4, 8, 0)],
        miercoles10,
      )!;
      expect(manana.cuando, 'mañana');
      expect(manana.estado, 'Empieza mañana');

      final lunes = calcularProximaClase(
        perfil,
        <BloqueHorario>[clase('l', 1, 8, 0)],
        miercoles10,
      )!;
      expect(lunes.cuando, 'lunes');
    });

    test('domingo, sin horario y clase pasada de hoy', () {
      final domingo = DateTime.utc(2026, 11, 22, 17); // domingo 12:00 en Bogotá
      expect(domingo.weekday, DateTime.sunday);
      expect(
        calcularProximaClase(perfil, <BloqueHorario>[clase('l', 1, 8, 0)], domingo)!.cuando,
        'mañana',
      );
      expect(calcularProximaClase(perfil, const <BloqueHorario>[], miercoles10), isNull);
      // La única clase fue hoy a las 07:00 y ya pasó: la próxima es la del miércoles siguiente.
      final proxima = calcularProximaClase(perfil, <BloqueHorario>[clase('a', 3, 7, 0)], miercoles10)!;
      expect(proxima.inicio.day, 25);
    });

    test('usa la hora de Bogotá aunque el instante llegue en UTC', () {
      // 03:00Z del jueves es miércoles 22:00 en Bogotá: la clase del jueves 08:00
      // todavía es «mañana» y no «hoy».
      final proxima = calcularProximaClase(
        perfil,
        <BloqueHorario>[clase('j', 4, 8, 0)],
        DateTime.utc(2026, 11, 19, 3),
      )!;
      expect(proxima.cuando, 'mañana');
    });
  });
}
