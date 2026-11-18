import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/providers.dart';
import 'package:pontimaps_app/core/theme/pontimaps_theme.dart';
import 'package:pontimaps_app/presentation/widgets/brand_mark.dart';

/// Consentimiento de ubicación (S08, Ley 1581 de 2012).
///
/// Es la **única** pantalla que puede pedir el permiso de GPS al sistema, y solo
/// después de que el usuario toca «Acepto activar ubicación» (RF-PER-01).
/// Explica la finalidad, que la posición se procesa solo en memoria
/// y que no se guarda ningún historial ligado a la persona. Rechazar no bloquea
/// la app: se sigue con un origen elegido a mano (RF-PER-05).
class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key});

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen> {
  bool _procesando = false;

  Future<void> _aceptar() async {
    if (_procesando) return;
    setState(() => _procesando = true);
    final consentimiento = ref.read(consentControllerProvider);
    final ubicacion = ref.read(locationProviderProvider);
    await consentimiento.aceptarGps();
    try {
      // Único punto de la app que invoca el permiso del sistema.
      await ubicacion.solicitarPermiso();
    } catch (_) {
      // Si la plataforma no puede mostrar el diálogo, la app sigue con origen manual.
    }
    if (!mounted) return;
    context.go('/mapa');
  }

  Future<void> _rechazar() async {
    if (_procesando) return;
    setState(() => _procesando = true);
    await ref.read(consentControllerProvider).rechazarGps();
    if (!mounted) return;
    context.go('/mapa');
  }

  Future<void> _verPolitica() {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tratamiento de datos'),
        content: const SingleChildScrollView(
          child: Text(
            'Ley 1581 de 2012 (Colombia). Finalidad: guiarte a pie por el campus. '
            'Tu posición se usa solo en tu dispositivo, en memoria, y se descarta al '
            'cerrar la app. No guardamos historial de recorridos ni coordenadas '
            'asociadas a ti, a tu correo o a tu dispositivo.\n\n'
            'Puedes revocar o pausar el uso de la ubicación en cualquier momento '
            'desde el mapa. Como titular tienes derecho a conocer, actualizar, '
            'rectificar y suprimir tus datos y a revocar tu autorización.\n\n'
            'El responsable del tratamiento se definirá con la Universidad antes '
            'del piloto.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(LayoutMetrics.screenMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Center(child: BrandMark(size: LayoutMetrics.space48)),
                      const SizedBox(height: LayoutMetrics.space16),
                      Text('Usar tu ubicación', style: textTheme.titleLarge),
                      const SizedBox(height: LayoutMetrics.space8),
                      Text(
                        'PontiMaps puede mostrar dónde estás para guiarte a pie hasta '
                        'tu edificio o salón.',
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: LayoutMetrics.space16),
                      const _Punto(
                        icono: Icons.my_location,
                        titulo: 'Para qué la usamos',
                        texto: 'Solo para ubicarte en el mapa y guiar tu ruta dentro del campus.',
                      ),
                      const _Punto(
                        icono: Icons.memory,
                        titulo: 'Qué procesamos',
                        texto:
                            'Tu posición se procesa solo en la memoria de tu dispositivo, '
                            'mientras la app está abierta.',
                      ),
                      const _Punto(
                        icono: Icons.block,
                        titulo: 'Qué NO guardamos',
                        texto:
                            'No guardamos historial de recorridos ni coordenadas ligadas a ti. '
                            'Nada de tu posición sale de tu dispositivo.',
                      ),
                      const _Punto(
                        icono: Icons.toggle_on_outlined,
                        titulo: 'Tú decides',
                        texto:
                            'Puedes pausar o revocar la ubicación cuando quieras desde el mapa. '
                            'Sin ella puedes elegir tu punto de partida a mano.',
                      ),
                      TextButton(
                        onPressed: _verPolitica,
                        child: const Text('Ver política de tratamiento de datos'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: LayoutMetrics.space16),
              FilledButton(
                onPressed: _procesando ? null : _aceptar,
                child: const Text('Acepto activar ubicación', textAlign: TextAlign.center),
              ),
              const SizedBox(height: LayoutMetrics.space8),
              OutlinedButton(
                onPressed: _procesando ? null : _rechazar,
                child: const Text(
                  'No acepto · Elegir origen manual',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto({required this.icono, required this.titulo, required this.texto});

  final IconData icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: LayoutMetrics.space16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: LayoutMetrics.space32,
            height: LayoutMetrics.space32,
            decoration: BoxDecoration(
              color: PontiMapsTheme.iconContainer,
              borderRadius: BorderRadius.circular(LayoutMetrics.radiusControl),
            ),
            child: Icon(icono, size: 16, color: PontiMapsTheme.primary),
          ),
          const SizedBox(width: LayoutMetrics.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(titulo, style: textTheme.titleMedium),
                Text(texto, style: textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
