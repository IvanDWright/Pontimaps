import 'package:latlong2/latlong.dart';
import 'package:pontimaps_app/core/utils/author_hash.dart';
import 'package:pontimaps_app/core/utils/colecciones.dart';

/// Tipo de novedad que un usuario puede reportar.
enum TipoReporte { cierre, fila, altaAfluencia }

/// Reporte colaborativo ("Waze javeriano") anclado a un punto/tramo del campus.
///
/// **Anonimato visual total:** nada en este modelo identifica al autor frente
/// a los demás usuarios. No hay nombre, correo ni `uid`; [toString] y
/// [toMap] (la representación pública) no incluyen el [authorHash].
///
/// **Seudonimización para moderar:** el [authorHash] (SHA-256 irreversible del
/// `uid`, ver [calcularAuthorHash]) existe solo para que un administrador
/// pueda bloquear a quien publica reportes falsos. Se guarda **fuera del
/// documento público** (ver [toMapAutoria]) y solo lo lee el administrador y el
/// propio autor. No hay coordenadas del autor, ni historial de recorrido: la
/// [ubicacion] es la del incidente, ajustada a un tramo del grafo. Sigue siendo
/// un dato personal seudonimizado bajo la Ley 1581.
///
/// **Invariantes de vigencia**
/// * `expiraEn >= creadoEn + 60 min` y `expiraEn <= creadoEn + 180 min`.
/// * Sin confirmaciones: `expiraEn == creadoEn + 60 min` exactamente.
/// * Cada confirmación extiende la vida 30 min, con tope de 3 h desde la
///   creación (ver [confirmar]).
/// * Con `reportesNegativos >= 3` el reporte ("Falso / Ya no está") queda
///   oculto por la comunidad y deja de estar vigente.
///
/// Los parámetros (60/30/180/3) son constantes estáticas hoy y pasarán a
/// `config/appConfig` cuando exista la capa de datos.
class ReporteComunidad {
  ReporteComunidad({
    required this.id,
    required this.tipo,
    required this.ubicacion,
    required this.creadoEn,
    required this.expiraEn,
    this.authorHash,
    this.idAristaAfectada,
    this.idLugar,
    this.descripcionCorta = '',
    this.confirmaciones = 0,
    this.reportesNegativos = 0,
  })  : assert(id != '', 'id no puede estar vacío'),
        assert(confirmaciones >= 0),
        assert(reportesNegativos >= 0),
        assert(descripcionCorta.length <= maxLongitudDescripcion),
        assert(
          authorHash == null || esAuthorHashValido(authorHash),
          'authorHash debe ser un SHA-256 en hexadecimal',
        ),
        assert(
          !expiraEn.isBefore(creadoEn.add(vigenciaBase)),
          'expiraEn no puede ser anterior a creadoEn + 60 min',
        ),
        assert(
          !expiraEn.isAfter(creadoEn.add(vigenciaMaxima)),
          'expiraEn no puede superar creadoEn + 180 min',
        ),
        assert(
          confirmaciones > 0 ||
              expiraEn.isAtSameMomentAs(creadoEn.add(vigenciaBase)),
          'Sin confirmaciones, expiraEn debe ser exactamente creadoEn + 60 min',
        );

  /// Crea un reporte recién publicado por una cuenta verificada: expira
  /// exactamente a los 60 minutos. [authorHash] es obligatorio (se obtiene de
  /// `UsuarioPerfil.authorHash`); un visitante no puede publicar.
  factory ReporteComunidad.nuevo({
    required String id,
    required TipoReporte tipo,
    required LatLng ubicacion,
    required DateTime ahora,
    required String authorHash,
    String? idAristaAfectada,
    String? idLugar,
    String descripcionCorta = '',
  }) {
    if (!esAuthorHashValido(authorHash)) {
      throw ArgumentError.value(
        authorHash,
        'authorHash',
        'Debe ser un SHA-256 en hexadecimal (use calcularAuthorHash)',
      );
    }
    return ReporteComunidad(
      id: id,
      tipo: tipo,
      ubicacion: ubicacion,
      creadoEn: ahora,
      expiraEn: ahora.add(vigenciaBase),
      authorHash: authorHash,
      idAristaAfectada: idAristaAfectada,
      idLugar: idLugar,
      descripcionCorta: descripcionCorta,
    );
  }

  /// Vida de un reporte sin confirmaciones.
  static const Duration vigenciaBase = Duration(minutes: 60);

  /// Extensión por cada confirmación comunitaria.
  static const Duration extensionPorConfirmacion = Duration(minutes: 30);

  /// Vida máxima desde la creación, aun con muchas confirmaciones.
  static const Duration vigenciaMaxima = Duration(minutes: 180);

  /// Votos negativos ("Falso / Ya no está") que ocultan el reporte.
  static const int umbralOcultamiento = 3;

  static const int maxLongitudDescripcion = 140;

  final String id;
  final TipoReporte tipo;
  final LatLng ubicacion;

  /// Seudónimo del autor para moderación. `null` cuando el reporte se leyó
  /// de la vista pública (la que ve cualquier usuario). Nunca se muestra.
  final String? authorHash;

  /// Arista del grafo afectada, si ya se conoce. Si es `null`, el grafo usa
  /// la arista más cercana a [ubicacion].
  final String? idAristaAfectada;

  /// Id del negocio o servicio al que se ancla un reporte de `fila` (RF-DIR-04):
  /// permite mostrar el nivel de fila de ese lugar. `null` si el reporte solo
  /// pertenece a un tramo del camino.
  final String? idLugar;

  /// Texto libre opcional. El MVP **no** lo captura en la interfaz (solo se
  /// elige el tipo) para evitar nombres propios o difamación; el campo existe
  /// por compatibilidad.
  final String descripcionCorta;
  final DateTime creadoEn;
  final DateTime expiraEn;
  final int confirmaciones;
  final int reportesNegativos;

  /// `true` si el reporte debe mostrarse y aplicarse en [ahora].
  ///
  /// Estricto: en `expiraEn` exacto ya no está vigente (a los 59:59 sí, a los
  /// 60:00 no). Con 3 o más votos negativos también deja de estarlo, sin
  /// importar cuántas confirmaciones tenga.
  bool estaVigente(DateTime ahora) =>
      ahora.isBefore(expiraEn) && reportesNegativos < umbralOcultamiento;

  /// Multiplicador de costo que este reporte impone a su arista.
  ///
  /// * `cierre` -> `double.infinity` (la arista queda bloqueada).
  /// * `fila` -> 1.5, `altaAfluencia` -> 1.3.
  /// * 1.0 (sin efecto) si los votos negativos superan a las confirmaciones.
  ///
  /// Para `fila` y `altaAfluencia` el resultado está en `[1.0, 1.5]`.
  double factorPenalizacion() {
    if (reportesNegativos > confirmaciones) return 1.0;
    switch (tipo) {
      case TipoReporte.cierre:
        return double.infinity;
      case TipoReporte.fila:
        return 1.5;
      case TipoReporte.altaAfluencia:
        return 1.3;
    }
  }

  /// Devuelve el reporte con una confirmación más y la vida extendida.
  ///
  /// `expiraEn' = min(creadoEn + 180 min, expiraEn + 30 min)`. Si el reporte
  /// ya no está vigente en [ahora] no se revive: se devuelve sin cambios.
  ReporteComunidad confirmar(DateTime ahora) {
    if (!estaVigente(ahora)) return this;
    final tope = creadoEn.add(vigenciaMaxima);
    final extendida = expiraEn.add(extensionPorConfirmacion);
    return copyWith(
      confirmaciones: confirmaciones + 1,
      expiraEn: extendida.isAfter(tope) ? tope : extendida,
    );
  }

  /// Devuelve el reporte con un voto negativo más ("Falso / Ya no está").
  /// No altera `expiraEn`. Al llegar a [umbralOcultamiento] queda oculto.
  ReporteComunidad negar() => copyWith(reportesNegativos: reportesNegativos + 1);

  /// Representación **pública** (la que ve cualquier usuario, incluso un
  /// visitante). Fechas en milisegundos UTC; la capa de datos las convierte a
  /// `Timestamp`. **No incluye el `authorHash`** ni ningún dato del autor.
  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'tipo': tipo.name,
        'lat': ubicacion.latitude,
        'lng': ubicacion.longitude,
        'idAristaAfectada': idAristaAfectada,
        if (idLugar != null) 'idLugar': idLugar,
        'descripcionCorta': descripcionCorta,
        'creadoEn': creadoEn.toUtc().millisecondsSinceEpoch,
        'expiraEn': expiraEn.toUtc().millisecondsSinceEpoch,
        'confirmaciones': confirmaciones,
        'reportesNegativos': reportesNegativos,
      };

  /// Registro **privado** de autoría (documento aparte, legible solo por el
  /// administrador y por el autor). `null` si este reporte no conoce su autor.
  Map<String, Object?>? toMapAutoria() {
    final hash = authorHash;
    if (hash == null) return null;
    return <String, Object?>{'idReporte': id, 'authorHash': hash};
  }

  /// Reconstruye un reporte desde la representación pública [map]. El
  /// [authorHash] llega aparte (solo un administrador o el autor lo leen).
  /// Lanza [FormatException] si falta un campo, tiene un tipo incorrecto o
  /// viola los invariantes de vigencia (los `assert` no existen en release, y
  /// estos datos vienen de la red).
  factory ReporteComunidad.fromMap(
    Map<String, Object?> map, {
    String? authorHash,
  }) {
    T campo<T>(String clave) {
      final valor = map[clave];
      if (valor is! T) {
        throw FormatException('Campo "$clave" ausente o inválido en el reporte');
      }
      return valor;
    }

    final tipoNombre = campo<String>('tipo');
    final tipo = TipoReporte.values.where((t) => t.name == tipoNombre);
    if (tipo.isEmpty) {
      throw FormatException('Tipo de reporte desconocido: $tipoNombre');
    }
    final idArista = map['idAristaAfectada'];
    if (idArista != null && idArista is! String) {
      throw const FormatException('Campo "idAristaAfectada" inválido');
    }
    final idLugar = map['idLugar'];
    if (idLugar != null && idLugar is! String) {
      throw const FormatException('Campo "idLugar" inválido');
    }
    final descripcion = (map['descripcionCorta'] as String?) ?? '';
    final creado = DateTime.fromMillisecondsSinceEpoch(
      campo<int>('creadoEn'),
      isUtc: true,
    );
    final expira = DateTime.fromMillisecondsSinceEpoch(
      campo<int>('expiraEn'),
      isUtc: true,
    );
    final confirmaciones = campo<int>('confirmaciones');
    final negativos = campo<int>('reportesNegativos');

    final invalido = campo<String>('id').isEmpty ||
        confirmaciones < 0 ||
        negativos < 0 ||
        descripcion.length > maxLongitudDescripcion ||
        (authorHash != null && !esAuthorHashValido(authorHash)) ||
        expira.isBefore(creado.add(vigenciaBase)) ||
        expira.isAfter(creado.add(vigenciaMaxima)) ||
        (confirmaciones == 0 && !expira.isAtSameMomentAs(creado.add(vigenciaBase)));
    if (invalido) {
      throw const FormatException('Reporte con valores fuera de los invariantes');
    }

    return ReporteComunidad(
      id: campo<String>('id'),
      tipo: tipo.first,
      ubicacion: LatLng(
        campo<num>('lat').toDouble(),
        campo<num>('lng').toDouble(),
      ),
      authorHash: authorHash,
      idAristaAfectada: idArista as String?,
      idLugar: idLugar as String?,
      descripcionCorta: descripcion,
      creadoEn: creado,
      expiraEn: expira,
      confirmaciones: confirmaciones,
      reportesNegativos: negativos,
    );
  }

  /// Copia sin el [authorHash]: la vista que se entrega a la UI y a los demás
  /// usuarios.
  ReporteComunidad sinAutor() => copyWith(authorHash: null);

  ReporteComunidad copyWith({
    String? id,
    TipoReporte? tipo,
    LatLng? ubicacion,
    Object? authorHash = sinCambio,
    Object? idAristaAfectada = sinCambio,
    Object? idLugar = sinCambio,
    String? descripcionCorta,
    DateTime? creadoEn,
    DateTime? expiraEn,
    int? confirmaciones,
    int? reportesNegativos,
  }) {
    return ReporteComunidad(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      ubicacion: ubicacion ?? this.ubicacion,
      authorHash: identical(authorHash, sinCambio)
          ? this.authorHash
          : authorHash as String?,
      idAristaAfectada: identical(idAristaAfectada, sinCambio)
          ? this.idAristaAfectada
          : idAristaAfectada as String?,
      idLugar: identical(idLugar, sinCambio) ? this.idLugar : idLugar as String?,
      descripcionCorta: descripcionCorta ?? this.descripcionCorta,
      creadoEn: creadoEn ?? this.creadoEn,
      expiraEn: expiraEn ?? this.expiraEn,
      confirmaciones: confirmaciones ?? this.confirmaciones,
      reportesNegativos: reportesNegativos ?? this.reportesNegativos,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReporteComunidad &&
          other.id == id &&
          other.tipo == tipo &&
          other.ubicacion == ubicacion &&
          other.authorHash == authorHash &&
          other.idAristaAfectada == idAristaAfectada &&
          other.idLugar == idLugar &&
          other.descripcionCorta == descripcionCorta &&
          other.creadoEn == creadoEn &&
          other.expiraEn == expiraEn &&
          other.confirmaciones == confirmaciones &&
          other.reportesNegativos == reportesNegativos;

  @override
  int get hashCode => Object.hash(
        id,
        tipo,
        ubicacion,
        authorHash,
        idAristaAfectada,
        idLugar,
        descripcionCorta,
        creadoEn,
        expiraEn,
        confirmaciones,
        reportesNegativos,
      );

  // No imprime el authorHash: evita que acabe en logs.
  @override
  String toString() =>
      'ReporteComunidad($id, ${tipo.name}, +$confirmaciones/-$reportesNegativos)';
}
