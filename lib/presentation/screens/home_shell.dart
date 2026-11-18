import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/providers.dart';
import 'package:pontimaps_app/presentation/screens/directory_screen.dart';
import 'package:pontimaps_app/presentation/screens/map_home_screen.dart';
import 'package:pontimaps_app/presentation/screens/more_screen.dart';

/// Marco de la app con la barra inferior `Mapa · Directorio · Más`.
///
/// Las tres pestañas se mantienen vivas (`IndexedStack`): al volver al mapa no se
/// pierde la ruta en curso ni el destino elegido.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shell = ref.watch(shellControllerProvider);
    return ListenableBuilder(
      listenable: shell,
      builder: (context, _) => Scaffold(
        body: IndexedStack(
          index: shell.pestana,
          children: const <Widget>[
            MapHomeScreen(),
            DirectoryScreen(),
            MoreScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.pestana,
          onDestinationSelected: shell.irAPestana,
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Mapa',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'Directorio',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz),
              label: 'Más',
            ),
          ],
        ),
      ),
    );
  }
}
