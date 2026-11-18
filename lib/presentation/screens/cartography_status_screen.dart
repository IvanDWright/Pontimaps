import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/config/app_config.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/theme/pontimaps_theme.dart';
import 'package:pontimaps_app/data/campus_cartography.dart';

/// Pantalla inicial provisional (Fase 0): confirma que la base cartográfica
/// semilla se cargó y es consistente. Se reemplazará por el flujo de
/// bienvenida → consentimiento → mapa (USER_PATHS, Path 0A/0B).
///
/// Sigue el lenguaje visual del mockup: marca azul con el logo de mapa, héroe
/// dorado girado -3°, tarjetas blancas de borde suave y avisos azul claro.
class CartographyStatusScreen extends StatelessWidget {
  const CartographyStatusScreen({
    super.key,
    required this.cartography,
    required this.config,
  });

  final CampusCartography cartography;
  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final problemas = cartography.validar();
    final cargada = problemas.isEmpty;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: LayoutMetrics.screenMargin,
            vertical: LayoutMetrics.space24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const _Brand(),
              const SizedBox(height: LayoutMetrics.space32),
              const Center(child: _HeroMark()),
              const SizedBox(height: LayoutMetrics.space24),
              Semantics(
                header: true,
                child: Text(
                  cargada
                      ? 'Base cartográfica cargada'
                      : 'Base cartográfica con problemas',
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: LayoutMetrics.space16),
              Text(
                cargada
                    ? 'El catálogo semilla del campus está listo para buscar '
                        'edificios y salones y trazar rutas.'
                    : problemas.join('\n'),
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: cargada
                      ? PontiMapsTheme.textSecondary
                      : PontiMapsTheme.error,
                ),
              ),
              const SizedBox(height: LayoutMetrics.space24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(LayoutMetrics.space16),
                  child: Column(
                    children: <Widget>[
                      _StatRow(
                        icon: Icons.apartment_outlined,
                        label: 'Edificios',
                        value: '${cartography.edificios.length}',
                      ),
                      _StatRow(
                        icon: Icons.meeting_room_outlined,
                        label: 'Salones',
                        value: '${cartography.salones.length}',
                      ),
                      _StatRow(
                        icon: Icons.local_cafe_outlined,
                        label: 'Servicios',
                        value: '${cartography.negocios.length}',
                      ),
                      _StatRow(
                        icon: Icons.place_outlined,
                        label: 'Nodos del grafo',
                        value: '${cartography.grafo.cantidadNodos}',
                      ),
                      _StatRow(
                        icon: Icons.alt_route,
                        label: 'Senderos',
                        value: '${cartography.grafo.cantidadAristas}',
                      ),
                      _StatRow(
                        icon: cartography.grafo.esConexo
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        label: 'Conectividad',
                        value: cartography.grafo.esConexo
                            ? 'Conexo'
                            : 'No conexo',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: LayoutMetrics.space16),
              _InfoCard(
                icon: Icons.info_outline,
                text: CampusCartography.coordenadasVerificadas
                    ? 'Mapa y senderos de OpenStreetMap. '
                        '${CampusCartography.atribucion}.'
                    : 'Las coordenadas son aproximadas y están pendientes de '
                        'verificar en campo.',
              ),
              const SizedBox(height: LayoutMetrics.space16),
              _InfoCard(
                icon: config.useOfflineFallback
                    ? Icons.cloud_off_outlined
                    : Icons.cloud_done_outlined,
                text: config.useOfflineFallback
                    ? 'Modo demostración sin conexión: todos los datos son '
                        'locales.'
                    : 'Modo en línea · proyecto ${config.firebaseProjectId}.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Logo de marca del mockup (`.brand`): cuadro azul con mapa + nombre.
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Container(
          width: LayoutMetrics.brandMarkSize,
          height: LayoutMetrics.brandMarkSize,
          decoration: BoxDecoration(
            color: PontiMapsTheme.primary,
            borderRadius: BorderRadius.circular(LayoutMetrics.radiusControl),
          ),
          child: const Icon(
            Icons.map_outlined,
            size: 22,
            color: PontiMapsTheme.onPrimary,
          ),
        ),
        const SizedBox(width: LayoutMetrics.space8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('La Pontimaps', style: textTheme.titleMedium),
              Text('Universidad Javeriana', style: textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// Héroe dorado del mockup (`.hero-map`): cuadrado girado -3°.
class _HeroMark extends StatelessWidget {
  const _HeroMark();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Transform.rotate(
        angle: -0.0524, // -3°
        child: Container(
          width: LayoutMetrics.heroMarkSize,
          height: LayoutMetrics.heroMarkSize,
          decoration: BoxDecoration(
            color: PontiMapsTheme.accent,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x38F2A900),
                blurRadius: 30,
                offset: Offset(0, 15),
              ),
            ],
          ),
          child: const Icon(
            Icons.map_outlined,
            size: 40,
            color: PontiMapsTheme.onAccent,
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$label: $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: LayoutMetrics.space8),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: PontiMapsTheme.primary),
            const SizedBox(width: LayoutMetrics.space8),
            Expanded(child: Text(label, style: textTheme.bodyLarge)),
            const SizedBox(width: LayoutMetrics.space8),
            Text(value, style: textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

/// Aviso azul claro del mockup (`.info-card`).
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(LayoutMetrics.space16),
      decoration: BoxDecoration(
        color: PontiMapsTheme.infoContainer,
        borderRadius: BorderRadius.circular(LayoutMetrics.radiusControl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: PontiMapsTheme.primary),
          const SizedBox(width: LayoutMetrics.space8),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodySmall?.copyWith(
                color: PontiMapsTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
