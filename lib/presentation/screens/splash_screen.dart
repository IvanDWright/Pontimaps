import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/providers.dart';
import 'package:pontimaps_app/presentation/widgets/brand_mark.dart';

/// Pantalla de arranque (S01): lee el consentimiento guardado y decide el
/// destino. Si falta el consentimiento → `PermissionScreen`; si ya está
/// resuelto → mapa en modo visitante de solo lectura. No pide ningún permiso.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _resolver();
  }

  Future<void> _resolver() async {
    final consentimiento = ref.read(consentControllerProvider);
    await consentimiento.cargar();
    if (!mounted) return;
    context.go(consentimiento.estado.resuelto ? '/mapa' : '/permiso');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(LayoutMetrics.screenMargin),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const BrandMark(),
                const SizedBox(height: LayoutMetrics.space24),
                Text('PontiMaps', style: textTheme.titleLarge),
                const SizedBox(height: LayoutMetrics.space8),
                Text(
                  'La Pontimaps · El Waze del campus Javeriano',
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: LayoutMetrics.space24),
                const CircularProgressIndicator(semanticsLabel: 'Cargando'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
