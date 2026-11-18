import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/theme/pontimaps_theme.dart';
import 'package:pontimaps_app/domain/search/campus_search.dart';

/// Barra de búsqueda **fija en la parte superior** del mapa (toque 1 del flujo
/// `Abrir → Destino → Ir`; nunca en un *Drawer*).
///
/// Busca en vivo y sin red por edificio (número o nombre parcial), salón o
/// servicio, con resultados agrupados *Edificios · Salones · Servicios*. Todo
/// resultado de salón muestra `Edificio X · Piso Y`.
class TopSearchBar extends StatefulWidget {
  const TopSearchBar({
    super.key,
    required this.busqueda,
    required this.onSeleccionar,
  });

  final CampusSearch busqueda;
  final ValueChanged<ResultadoBusqueda> onSeleccionar;

  @override
  State<TopSearchBar> createState() => _TopSearchBarState();
}

class _TopSearchBarState extends State<TopSearchBar> {
  final TextEditingController _texto = TextEditingController();
  final FocusNode _foco = FocusNode();
  ResultadosAgrupados _resultados = const ResultadosAgrupados();
  String _consulta = '';

  static const double _alturaMaximaResultados = 320;

  @override
  void dispose() {
    _texto.dispose();
    _foco.dispose();
    super.dispose();
  }

  void _alCambiar(String valor) {
    setState(() {
      _consulta = valor.trim();
      _resultados = widget.busqueda.buscar(valor);
    });
  }

  void _limpiar() {
    _texto.clear();
    _alCambiar('');
  }

  void _elegir(ResultadoBusqueda resultado) {
    _foco.unfocus();
    _limpiar();
    widget.onSeleccionar(resultado);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Material(
          color: PontiMapsTheme.surface,
          elevation: 4,
          borderRadius: BorderRadius.circular(LayoutMetrics.radiusCard),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: LayoutMetrics.minTouchTarget),
            child: TextField(
              controller: _texto,
              focusNode: _foco,
              onChanged: _alCambiar,
              textInputAction: TextInputAction.search,
              style: textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Buscar edificio, salón o servicio',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _consulta.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Borrar búsqueda',
                        icon: const Icon(Icons.close),
                        onPressed: _limpiar,
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: LayoutMetrics.space16,
                  vertical: LayoutMetrics.space16,
                ),
              ),
            ),
          ),
        ),
        if (_consulta.isNotEmpty) ...<Widget>[
          const SizedBox(height: LayoutMetrics.space8),
          Material(
            color: PontiMapsTheme.surface,
            elevation: 4,
            borderRadius: BorderRadius.circular(LayoutMetrics.radiusCard),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _alturaMaximaResultados),
              child: _resultados.vacio
                  ? Padding(
                      padding: const EdgeInsets.all(LayoutMetrics.space16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'No encontramos ese edificio o salón',
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: LayoutMetrics.space8),
                          Text(
                            'Prueba con el número del edificio (51) o el código de un salón (67-205).',
                            style: textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: LayoutMetrics.space8),
                      children: <Widget>[
                        if (_resultados.edificios.isNotEmpty) const _Encabezado('Edificios'),
                        for (final r in _resultados.edificios)
                          _FilaResultado(
                            icono: Icons.apartment,
                            resultado: r,
                            onTap: () => _elegir(r),
                          ),
                        if (_resultados.salones.isNotEmpty) const _Encabezado('Salones'),
                        for (final r in _resultados.salones)
                          _FilaResultado(
                            icono: Icons.meeting_room_outlined,
                            resultado: r,
                            onTap: () => _elegir(r),
                          ),
                        if (_resultados.servicios.isNotEmpty) const _Encabezado('Servicios'),
                        for (final r in _resultados.servicios)
                          _FilaResultado(
                            icono: Icons.storefront_outlined,
                            resultado: r,
                            onTap: () => _elegir(r),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LayoutMetrics.space16,
        LayoutMetrics.space8,
        LayoutMetrics.space16,
        0,
      ),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: PontiMapsTheme.textSecondary,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _FilaResultado extends StatelessWidget {
  const _FilaResultado({
    required this.icono,
    required this.resultado,
    required this.onTap,
  });

  final IconData icono;
  final ResultadoBusqueda resultado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: LayoutMetrics.minTouchTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LayoutMetrics.space16,
            vertical: LayoutMetrics.space8,
          ),
          child: Row(
            children: <Widget>[
              Icon(icono, color: PontiMapsTheme.primary),
              const SizedBox(width: LayoutMetrics.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(resultado.titulo, style: textTheme.titleMedium),
                    Text(resultado.subtitulo, style: textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
