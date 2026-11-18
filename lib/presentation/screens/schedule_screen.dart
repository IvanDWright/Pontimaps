import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/providers.dart';
import 'package:pontimaps_app/core/theme/pontimaps_theme.dart';
import 'package:pontimaps_app/data/schedule_repository.dart';
import 'package:pontimaps_app/domain/search/campus_search.dart';
import 'package:pontimaps_app/domain/services/auth_guard.dart';
import 'package:pontimaps_app/domain/services/next_class.dart';
import 'package:pontimaps_app/models/horario_usuario.dart';
import 'package:pontimaps_app/presentation/widgets/restricted_action_dialog.dart';

String _capitalizar(String texto) => texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);

/// Horario académico (S23). Se guarda **solo en este dispositivo**, asociado a la
/// cuenta; nunca en la nube. Agregar, editar y eliminar clases exige una cuenta
/// institucional verificada (el visitante ve el control con candado).
class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  Future<void> _abrirEdicion(BuildContext context, WidgetRef ref, [BloqueHorario? bloque]) async {
    if (!await verificarAccion(context, ref, AccionProtegida.guardarHorario)) return;
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => ScheduleEditScreen(bloque: bloque)),
    );
  }

  Future<void> _eliminar(BuildContext context, WidgetRef ref, BloqueHorario bloque) async {
    if (!await verificarAccion(context, ref, AccionProtegida.guardarHorario)) return;
    if (!context.mounted) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Eliminar clase'),
        content: Text('¿Eliminar «${bloque.materia}» de tu horario?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado == true) {
      await ref.read(scheduleControllerProvider).eliminar(bloque.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final controlador = ref.watch(scheduleControllerProvider);
    final sesion = ref.watch(sessionProvider);
    final cartografia = ref.watch(cartographyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi horario')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[controlador, sesion]),
          builder: (context, _) {
            final bloques = controlador.bloques;
            final bloqueado = accionBloqueada(ref, AccionProtegida.guardarHorario);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: bloques.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(LayoutMetrics.screenMargin),
                          child: Text(
                            'Aún no tienes clases. Agrega la primera y la verás en «Mi próxima clase».',
                            style: textTheme.bodyMedium,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(LayoutMetrics.screenMargin),
                          itemCount: bloques.length,
                          separatorBuilder: (_, _) => const SizedBox(height: LayoutMetrics.space8),
                          itemBuilder: (context, i) {
                            final b = bloques[i];
                            final edificio = cartografia.edificioPorId(b.idEdificio);
                            final salon = edificio?.buscarSalon(b.codigoSalon);
                            return Card(
                              color: PontiMapsTheme.surface,
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(LayoutMetrics.space16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(b.materia, style: textTheme.titleMedium),
                                          Text(
                                            '${_capitalizar(ProximaClase.nombreDia(b.diaSemana))} · '
                                            '${BloqueHorario.formatoHora(b.horaInicio)} – '
                                            '${BloqueHorario.formatoHora(b.horaFin)}',
                                            style: textTheme.bodyMedium,
                                          ),
                                          Text(
                                            salon == null
                                                ? 'Salón ${b.codigoSalon}'
                                                : '${etiquetaSalon(salon)} · Salón ${salon.codigo}',
                                            style: textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Editar ${b.materia}',
                                      icon: Icon(bloqueado ? Icons.lock_outline : Icons.edit_outlined),
                                      onPressed: () => _abrirEdicion(context, ref, b),
                                    ),
                                    IconButton(
                                      tooltip: 'Eliminar ${b.materia}',
                                      icon: Icon(bloqueado ? Icons.lock_outline : Icons.delete_outline),
                                      onPressed: () => _eliminar(context, ref, b),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(LayoutMetrics.screenMargin),
                  child: FilledButton.icon(
                    onPressed: () => _abrirEdicion(context, ref),
                    icon: Icon(bloqueado ? Icons.lock_outline : Icons.add),
                    label: Text(bloques.isEmpty ? 'Agregar mi primera clase' : 'Agregar clase'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Alta y edición de una clase (S24). El edificio y el salón se **eligen del
/// catálogo** (`Edificio X · Piso Y`): no se acepta texto libre inexistente.
/// «Guardar» queda deshabilitado mientras haya un error (E2-07) y un solapamiento
/// solo avisa (E2-08).
class ScheduleEditScreen extends ConsumerStatefulWidget {
  const ScheduleEditScreen({super.key, this.bloque});

  /// La clase que se edita; `null` para agregar una nueva.
  final BloqueHorario? bloque;

  @override
  ConsumerState<ScheduleEditScreen> createState() => _ScheduleEditScreenState();
}

class _ScheduleEditScreenState extends ConsumerState<ScheduleEditScreen> {
  final TextEditingController _materia = TextEditingController();
  final Set<int> _dias = <int>{};
  int _inicio = BloqueHorario.minutos(8, 0);
  int _fin = BloqueHorario.minutos(10, 0);
  String? _idEdificio;
  String? _codigoSalon;

  static const List<String> _abreviaturas = <String>['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  void initState() {
    super.initState();
    final b = widget.bloque;
    if (b != null) {
      _materia.text = b.materia;
      _dias.add(b.diaSemana);
      _inicio = b.horaInicio;
      _fin = b.horaFin;
      _idEdificio = b.idEdificio;
      _codigoSalon = b.codigoSalon;
    }
  }

  @override
  void dispose() {
    _materia.dispose();
    super.dispose();
  }

  BloqueHorario _construir(int dia, String id) => BloqueHorario(
        id: id,
        materia: _materia.text.trim(),
        diaSemana: dia,
        horaInicio: _inicio,
        horaFin: _fin > _inicio ? _fin : _inicio + 1,
        idEdificio: _idEdificio ?? 'sin-edificio',
        codigoSalon: _codigoSalon ?? 'sin-salon',
      );

  /// Primer error de validación, o `null` si se puede guardar.
  ErrorBloque? get _error {
    if (_fin <= _inicio) return ErrorBloque.horaFinNoPosterior;
    if (_idEdificio == null) return ErrorBloque.edificioInexistente;
    if (_codigoSalon == null) return ErrorBloque.salonInexistente;
    return validarBloque(_construir(1, 'validacion'), ref.read(cartographyProvider));
  }

  bool get _puedeGuardar => _materia.text.trim().isNotEmpty && _dias.isNotEmpty && _error == null;

  List<BloqueHorario> get _solapamientos {
    if (_error != null) return const <BloqueHorario>[];
    final existentes = ref.read(scheduleControllerProvider).bloques;
    final idActual = widget.bloque?.id;
    return <BloqueHorario>[
      for (final dia in _dias)
        ...bloquesSolapados(_construir(dia, idActual ?? 'nuevo-$dia'), existentes),
    ];
  }

  Future<void> _elegirHora({required bool inicio}) async {
    final actual = inicio ? _inicio : _fin;
    final elegida = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: actual ~/ 60, minute: actual % 60),
    );
    if (elegida == null) return;
    setState(() {
      final minutos = elegida.hour * 60 + elegida.minute;
      if (inicio) {
        _inicio = minutos;
      } else {
        _fin = minutos;
      }
    });
  }

  Future<void> _guardar() async {
    if (!await verificarAccion(context, ref, AccionProtegida.guardarHorario)) return;
    if (!_puedeGuardar || !mounted) return;
    final controlador = ref.read(scheduleControllerProvider);
    final editado = widget.bloque;
    if (editado != null) {
      await controlador.guardar(_construir(editado.diaSemana, editado.id));
    } else {
      final base = DateTime.now().microsecondsSinceEpoch;
      for (final dia in _dias) {
        await controlador.guardar(_construir(dia, 'clase-$base-$dia'));
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cartografia = ref.watch(cartographyProvider);
    final edificio = _idEdificio == null ? null : cartografia.edificioPorId(_idEdificio!);
    final error = _error;
    final solapados = _solapamientos;
    final editando = widget.bloque != null;
    return Scaffold(
      appBar: AppBar(title: Text(editando ? 'Editar clase' : 'Agregar clase')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(LayoutMetrics.screenMargin),
          children: <Widget>[
            TextField(
              controller: _materia,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Materia'),
            ),
            const SizedBox(height: LayoutMetrics.space16),
            Text(editando ? 'Día' : 'Días', style: textTheme.titleMedium),
            const SizedBox(height: LayoutMetrics.space8),
            Wrap(
              spacing: LayoutMetrics.space8,
              runSpacing: LayoutMetrics.space8,
              children: <Widget>[
                for (var d = 1; d <= 7; d++)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: LayoutMetrics.minTouchTarget),
                    child: FilterChip(
                      label: Text(_abreviaturas[d - 1]),
                      selected: _dias.contains(d),
                      onSelected: (marcado) => setState(() {
                        if (editando) {
                          _dias
                            ..clear()
                            ..add(d);
                        } else if (marcado) {
                          _dias.add(d);
                        } else {
                          _dias.remove(d);
                        }
                      }),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: LayoutMetrics.space16),
            Wrap(
              spacing: LayoutMetrics.space8,
              runSpacing: LayoutMetrics.space8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () => _elegirHora(inicio: true),
                  icon: const Icon(Icons.schedule),
                  label: Text('Inicio ${BloqueHorario.formatoHora(_inicio)}'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _elegirHora(inicio: false),
                  icon: const Icon(Icons.schedule),
                  label: Text('Fin ${BloqueHorario.formatoHora(_fin)}'),
                ),
              ],
            ),
            const SizedBox(height: LayoutMetrics.space16),
            DropdownButtonFormField<String>(
              initialValue: _idEdificio,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Edificio'),
              items: <DropdownMenuItem<String>>[
                for (final e in cartografia.edificiosDeClase)
                  DropdownMenuItem<String>(
                    value: e.id,
                    child: Text('${e.etiqueta} · ${e.nombre}', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (valor) => setState(() {
                _idEdificio = valor;
                _codigoSalon = null;
              }),
            ),
            const SizedBox(height: LayoutMetrics.space16),
            DropdownButtonFormField<String>(
              key: ValueKey<String?>(_idEdificio),
              initialValue: _codigoSalon,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Salón'),
              items: <DropdownMenuItem<String>>[
                if (edificio != null)
                  for (final s in edificio.salones)
                    DropdownMenuItem<String>(
                      value: s.codigo,
                      child: Text(
                        '${s.codigo} · ${etiquetaSalon(s)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
              ],
              onChanged: edificio == null ? null : (valor) => setState(() => _codigoSalon = valor),
            ),
            if (error != null && (_idEdificio != null || _fin <= _inicio)) ...<Widget>[
              const SizedBox(height: LayoutMetrics.space16),
              Text(
                error.mensaje,
                style: textTheme.bodyMedium?.copyWith(color: PontiMapsTheme.error),
              ),
            ],
            if (solapados.isNotEmpty) ...<Widget>[
              const SizedBox(height: LayoutMetrics.space16),
              Text(
                'Se solapa con «${solapados.first.materia}». Puedes guardarla de todos modos.',
                style: textTheme.bodyMedium?.copyWith(color: PontiMapsTheme.warningText),
              ),
            ],
            const SizedBox(height: LayoutMetrics.space24),
            FilledButton(
              onPressed: _puedeGuardar ? _guardar : null,
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
