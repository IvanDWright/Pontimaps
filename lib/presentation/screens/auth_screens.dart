import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pontimaps_app/core/constants/layout_metrics.dart';
import 'package:pontimaps_app/core/providers.dart';
import 'package:pontimaps_app/core/routing/rutas.dart';
import 'package:pontimaps_app/core/theme/pontimaps_theme.dart';
import 'package:pontimaps_app/core/utils/password_policy.dart';
import 'package:pontimaps_app/data/auth_repository.dart';
import 'package:pontimaps_app/models/horario_usuario.dart';
import 'package:pontimaps_app/presentation/widgets/brand_mark.dart';

/// Puerta de entrada (S02): iniciar sesión, registrarse o **continuar como
/// Visitante**. El visitante no crea usuario ni sesión (ni anónima) en Firebase:
/// solo se recuerda la elección en el dispositivo (Path 0B).
class AuthGateScreen extends ConsumerWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(LayoutMetrics.screenMargin),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: LayoutMetrics.space24),
                const Center(child: BrandMark()),
                const SizedBox(height: LayoutMetrics.space24),
                Text(
                  'Bienvenido a PontiMaps',
                  style: textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: LayoutMetrics.space8),
                Text(
                  'Con tu cuenta institucional puedes reportar novedades y guardar tu horario. '
                  'Como visitante ves el mapa y las rutas en solo lectura.',
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: LayoutMetrics.space32),
                FilledButton(
                  onPressed: () => context.push(Rutas.login),
                  child: const Text('Iniciar sesión'),
                ),
                const SizedBox(height: LayoutMetrics.space8),
                OutlinedButton(
                  onPressed: () => context.push(Rutas.registro),
                  child: const Text('Registrarme'),
                ),
                const SizedBox(height: LayoutMetrics.space8),
                TextButton(
                  onPressed: () async {
                    await ref.read(consentControllerProvider).elegirVisitante();
                    if (context.mounted) context.go(Rutas.mapa);
                  },
                  child: const Text('Continuar como Visitante'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de contraseña con botón para mostrar u ocultar.
class _CampoContrasena extends StatefulWidget {
  const _CampoContrasena({
    required this.controlador,
    required this.etiqueta,
    required this.onChanged,
  });

  final TextEditingController controlador;
  final String etiqueta;
  final VoidCallback onChanged;

  @override
  State<_CampoContrasena> createState() => _CampoContrasenaState();
}

class _CampoContrasenaState extends State<_CampoContrasena> {
  bool _oculta = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controlador,
      obscureText: _oculta,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: (_) => widget.onChanged(),
      decoration: InputDecoration(
        labelText: widget.etiqueta,
        suffixIcon: IconButton(
          tooltip: _oculta ? 'Mostrar contraseña' : 'Ocultar contraseña',
          icon: Icon(
            _oculta ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _oculta = !_oculta),
        ),
      ),
    );
  }
}

/// Iniciar sesión (S05). El error es siempre el mismo si el correo no existe o
/// la contraseña es incorrecta: no revela qué cuentas existen.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _correo = TextEditingController();
  final TextEditingController _contrasena = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  bool get _completo =>
      _correo.text.trim().isNotEmpty && _contrasena.text.isNotEmpty;

  Future<void> _entrar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    final auth = ref.read(authRepositoryProvider);
    try {
      await auth.iniciarSesion(
        correo: _correo.text,
        contrasena: _contrasena.text,
      );
      if (!mounted) return;
      final cuenta = auth.actual;
      context.go(
        cuenta != null && !cuenta.emailVerified ? Rutas.verificar : Rutas.mapa,
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(LayoutMetrics.screenMargin),
          children: <Widget>[
            TextField(
              controller: _correo,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Correo institucional',
              ),
            ),
            const SizedBox(height: LayoutMetrics.space16),
            _CampoContrasena(
              controlador: _contrasena,
              etiqueta: 'Contraseña',
              onChanged: () => setState(() {}),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: LayoutMetrics.space16),
              Text(
                _error!,
                style: textTheme.bodyMedium?.copyWith(
                  color: PontiMapsTheme.error,
                ),
              ),
            ],
            const SizedBox(height: LayoutMetrics.space24),
            FilledButton(
              onPressed: _completo && !_cargando ? _entrar : null,
              child: Text(_cargando ? 'Entrando…' : 'Iniciar sesión'),
            ),
            const SizedBox(height: LayoutMetrics.space8),
            TextButton(
              onPressed: () => context.pushReplacement(Rutas.registro),
              child: const Text('No tengo cuenta · Registrarme'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Registro (S03): solo `@javeriana.edu.co`, contraseña fuerte con la lista de
/// requisitos ✓/✗, tipo de usuario (sin «Administrador») y autorización del
/// tratamiento de datos (Ley 1581). Luego se envía el enlace de verificación.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _correo = TextEditingController();
  final TextEditingController _contrasena = TextEditingController();
  final TextEditingController _confirmacion = TextEditingController();
  RolUsuario _tipo = RolUsuario.estudiante;
  bool _autoriza = false;
  bool _cargando = false;
  String? _error;

  static const List<RolUsuario> _tiposPermitidos = <RolUsuario>[
    RolUsuario.estudiante,
    RolUsuario.profesor,
    RolUsuario.administrativo,
  ];

  static String _nombreTipo(RolUsuario rol) {
    switch (rol) {
      case RolUsuario.estudiante:
        return 'Estudiante';
      case RolUsuario.profesor:
        return 'Profesor';
      case RolUsuario.administrativo:
        return 'Personal administrativo';
      case RolUsuario.admin:
      case RolUsuario.invitado:
        return '';
    }
  }

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  bool get _correoValido => UsuarioPerfil.esCorreoInstitucional(_correo.text);

  bool get _coinciden =>
      _contrasena.text.isNotEmpty && _contrasena.text == _confirmacion.text;

  bool get _puedeCrear =>
      _correoValido &&
      contrasenaValida(_contrasena.text, correo: _correo.text) &&
      _coinciden &&
      _autoriza &&
      !_cargando;

  Future<void> _crear() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .registrar(
            correo: _correo.text,
            contrasena: _contrasena.text,
            tipo: _tipo,
          );
      if (mounted) context.go(Rutas.verificar);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cumplidos = requisitosCumplidos(
      _contrasena.text,
      correo: _correo.text,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Registrarme')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(LayoutMetrics.screenMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                controller: _correo,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Correo institucional',
                  hintText: 'usuario@javeriana.edu.co',
                  errorText: _correo.text.isNotEmpty && !_correoValido
                      ? ErrorAuth.correoNoInstitucional.mensaje
                      : null,
                ),
              ),
              const SizedBox(height: LayoutMetrics.space16),
              _CampoContrasena(
                controlador: _contrasena,
                etiqueta: 'Contraseña',
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: LayoutMetrics.space8),
              for (final requisito in RequisitoContrasena.values)
                _Requisito(
                  requisito: requisito,
                  cumplido: cumplidos.contains(requisito),
                ),
              const SizedBox(height: LayoutMetrics.space16),
              _CampoContrasena(
                controlador: _confirmacion,
                etiqueta: 'Confirmar contraseña',
                onChanged: () => setState(() {}),
              ),
              if (_confirmacion.text.isNotEmpty && !_coinciden)
                Padding(
                  padding: const EdgeInsets.only(top: LayoutMetrics.space8),
                  child: Text(
                    'Las contraseñas no coinciden.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: PontiMapsTheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: LayoutMetrics.space16),
              DropdownButtonFormField<RolUsuario>(
                initialValue: _tipo,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipo de usuario'),
                items: <DropdownMenuItem<RolUsuario>>[
                  for (final rol in _tiposPermitidos)
                    DropdownMenuItem<RolUsuario>(
                      value: rol,
                      child: Text(_nombreTipo(rol)),
                    ),
                ],
                onChanged: (valor) =>
                    setState(() => _tipo = valor ?? RolUsuario.estudiante),
              ),
              const SizedBox(height: LayoutMetrics.space8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _autoriza,
                onChanged: (valor) =>
                    setState(() => _autoriza = valor ?? false),
                title: const Text(
                  'Autorizo el tratamiento de mis datos para usar PontiMaps (Ley 1581 de 2012). '
                  'Los reportes que publique serán anónimos para los demás usuarios.',
                ),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: LayoutMetrics.space8),
                Text(
                  _error!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: PontiMapsTheme.error,
                  ),
                ),
              ],
              const SizedBox(height: LayoutMetrics.space16),
              FilledButton(
                onPressed: _puedeCrear ? _crear : null,
                child: Text(_cargando ? 'Creando cuenta…' : 'Crear cuenta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una línea de la lista de requisitos: icono distinto + texto (no solo color).
class _Requisito extends StatelessWidget {
  const _Requisito({required this.requisito, required this.cumplido});

  final RequisitoContrasena requisito;
  final bool cumplido;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      label: '${requisito.texto}: ${cumplido ? 'cumplido' : 'pendiente'}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(
                cumplido ? Icons.check_circle : Icons.cancel_outlined,
                size: 24,
                color: cumplido
                    ? PontiMapsTheme.success
                    : PontiMapsTheme.textSecondary,
              ),
            ),
            const SizedBox(width: LayoutMetrics.space8),
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  requisito.texto,
                  style: textTheme.bodySmall?.copyWith(
                    color: cumplido
                        ? PontiMapsTheme.success
                        : PontiMapsTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Espera de verificación (S04): el enlace nativo de Firebase Auth llega al
/// correo. «Ya verifiqué mi correo» vuelve a leer la cuenta (`reload()`); «Reenviar
/// enlace» espera 60 s entre envíos.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  static const int _esperaSegundos = 60;

  Timer? _temporizador;
  int _espera = 0;
  bool _cargando = false;
  String? _mensaje;
  bool _mensajeEsError = false;

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  void _mostrar(String texto, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _mensaje = texto;
      _mensajeEsError = error;
    });
  }

  Future<void> _yaVerifique() async {
    setState(() => _cargando = true);
    try {
      final cuenta = await ref.read(authRepositoryProvider).recargar();
      if (!mounted) return;
      if (cuenta?.emailVerified == true) {
        context.go(Rutas.mapa);
      } else {
        _mostrar(
          'Aún no está verificado. Abre el enlace que te enviamos al correo e inténtalo de nuevo.',
          error: true,
        );
      }
    } on AuthException catch (e) {
      _mostrar(e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _reenviar() async {
    try {
      await ref.read(authRepositoryProvider).reenviarVerificacion();
      _mostrar('Enviamos un nuevo enlace a tu correo.');
      setState(() => _espera = _esperaSegundos);
      _temporizador?.cancel();
      _temporizador = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _espera--);
        if (_espera <= 0) t.cancel();
      });
    } on AuthException catch (e) {
      _mostrar(e.mensaje, error: true);
    }
  }

  Future<void> _cambiarCorreo() async {
    await ref.read(authRepositoryProvider).cerrarSesion();
    if (mounted) context.go(Rutas.acceso);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final auth = ref.watch(authRepositoryProvider);
    final cuenta = auth.actual;
    return Scaffold(
      appBar: AppBar(title: const Text('Revisa tu correo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(LayoutMetrics.screenMargin),
          children: <Widget>[
            const Icon(
              Icons.mark_email_unread_outlined,
              size: 48,
              color: PontiMapsTheme.primary,
            ),
            const SizedBox(height: LayoutMetrics.space16),
            Text(
              cuenta == null
                  ? 'Inicia sesión para verificar tu correo.'
                  : 'Te enviamos un enlace de verificación a ${cuenta.correoEnmascarado}. '
                        'Ábrelo y vuelve aquí.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: LayoutMetrics.space8),
            Text(
              'Hasta verificar tu correo solo puedes ver el mapa (solo lectura). '
              'Si no llega, revisa la carpeta de correo no deseado.',
              style: textTheme.bodySmall,
            ),
            if (_mensaje != null) ...<Widget>[
              const SizedBox(height: LayoutMetrics.space16),
              Text(
                _mensaje!,
                style: textTheme.bodyMedium?.copyWith(
                  color: _mensajeEsError
                      ? PontiMapsTheme.error
                      : PontiMapsTheme.success,
                ),
              ),
            ],
            const SizedBox(height: LayoutMetrics.space24),
            FilledButton(
              onPressed: cuenta == null || _cargando ? null : _yaVerifique,
              child: const Text('Ya verifiqué mi correo'),
            ),
            const SizedBox(height: LayoutMetrics.space8),
            OutlinedButton(
              onPressed: cuenta == null || _espera > 0 ? null : _reenviar,
              child: Text(
                _espera > 0
                    ? 'Reenviar enlace (en $_espera s)'
                    : 'Reenviar enlace',
              ),
            ),
            if (auth is InMemoryAuthRepository) ...<Widget>[
              const SizedBox(height: LayoutMetrics.space8),
              OutlinedButton(
                onPressed: () {
                  auth.simularEnlaceDeVerificacion();
                  _mostrar(
                    'Enlace simulado (solo demostración). Toca «Ya verifiqué mi correo».',
                  );
                },
                child: const Text(
                  'Simular enlace de verificación (solo demostración)',
                ),
              ),
            ],
            const SizedBox(height: LayoutMetrics.space8),
            TextButton(
              onPressed: _cambiarCorreo,
              child: const Text('Cambiar correo'),
            ),
            TextButton(
              onPressed: () => context.go(Rutas.mapa),
              child: const Text('Continuar sin verificar (solo lectura)'),
            ),
          ],
        ),
      ),
    );
  }
}
