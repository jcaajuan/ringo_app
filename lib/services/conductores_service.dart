import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Resultado de la escucha de `presencia`.
///
/// [hayAlguno] queda en `false` cuando la consulta falla: no se confirma un
/// viaje sin saber si hay conductores, y [codigoError] permite reintentar.
class EstadoPresencia {
  const EstadoPresencia({
    this.hayAlguno,
    this.codigoError,
    this.reintentando = false,
  });

  /// `null` mientras no llega una respuesta del servidor.
  final bool? hayAlguno;
  final String? codigoError;
  final bool reintentando;

  bool get fallo => codigoError != null;
}

/// Hay al menos un conductor conectado.
///
/// Lee `presencia/{conductorId}`. El tipo sale de `vehiculo.tipo` o
/// `tipoVehiculo`. Si el documento solo trae `conectado` y `actualizadoEn`,
/// el tipo se lee de `conductores/{conductorId}.vehiculo.tipo`.
///
/// El conductor cuenta como conectado si `disponible` es true, si
/// `estadoOperativo` es `conectado` o si `conectado` es true.
/// Moto taxi solo cuenta `moto`. Taxi cuenta `carro`, `auto` o `vehiculo`
/// (el perfil no tiene que decir "taxi"). Delivery cuenta moto y carro.
/// "mototaxi" no se acepta por contener la palabra "taxi".
class ConductoresService {
  ConductoresService._();
  static final ConductoresService instance = ConductoresService._();

  final Map<String, String> _tipoPorConductor = {};

  /// Valor que guarda la solicitud: `mototaxi`, `taxi` o `delivery`.
  ///
  /// "Moto Taxi" y `moto` quedan en `mototaxi` antes de mirar `taxi`,
  /// así que esa palabra no se cuela dentro de "mototaxi". "Taxi (Carro)"
  /// y `carro` quedan en `taxi`.
  static String servicioParaSolicitud(String tipoServicio) {
    final servicio = instance._servicioCanonico(tipoServicio);
    return servicio.isEmpty ? tipoServicio.trim().toLowerCase() : servicio;
  }

  Stream<EstadoPresencia> hayAlgunoEnLinea(String tipoServicio) {
    late StreamController<EstadoPresencia> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;
    Timer? espera;
    var intento = 0;
    var vivo = true;
    var reconectando = false;
    var generacion = 0;

    void soltar() {
      sub?.cancel();
      sub = null;
    }

    late final void Function() escuchar;

    void fallar(Object error, StackTrace stack) {
      registrarFalloConsulta(error, stack);
      if (controller.isClosed) return;
      final codigo = codigoFirestore(error);
      final transitorio = _esTransitorio(codigo);
      controller.add(EstadoPresencia(
        hayAlguno: false,
        codigoError: codigo,
        reintentando: transitorio,
      ));
      if (!transitorio || reconectando || !vivo) return;
      reconectando = true;
      intento = intento < 4 ? intento + 1 : 4;
      espera?.cancel();
      espera = Timer(Duration(seconds: 1 << intento), () {
        reconectando = false;
        if (!vivo || controller.isClosed) return;
        escuchar();
      });
    }

    escuchar = () {
      if (!vivo || controller.isClosed) return;
      soltar();
      final esta = ++generacion;
      var ticket = 0;
      sub = FirebaseFirestore.instance
          .collection('presencia')
          .snapshots(includeMetadataChanges: true)
          .handleError(fallar)
          .listen((snap) async {
        if (controller.isClosed || esta != generacion) return;
        final mio = ++ticket;
        try {
          final hay = await _evaluar(snap, tipoServicio);
          if (hay == null || mio != ticket || esta != generacion || controller.isClosed) return;
          intento = 0;
          reconectando = false;
          espera?.cancel();
          espera = null;
          controller.add(EstadoPresencia(hayAlguno: hay));
        } catch (error, stack) {
          if (mio != ticket || esta != generacion || controller.isClosed) return;
          fallar(error, stack);
        }
      });
    };

    controller = StreamController<EstadoPresencia>(
      onListen: escuchar,
      onCancel: () {
        vivo = false;
        espera?.cancel();
        soltar();
      },
    );
    return controller.stream;
  }

  /// Código de Firestore (`permission-denied`, `unavailable`, …) o el tipo del error.
  static String codigoFirestore(Object error) {
    if (error is FirebaseException) return error.code;
    if (error is TimeoutException) return 'deadline-exceeded';
    if (error is FormatException || error is TypeError) return 'parsing';
    return error.runtimeType.toString();
  }

  static bool _esTransitorio(String codigo) {
    switch (codigo) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'aborted':
      case 'resource-exhausted':
      case 'cancelled':
      case 'internal':
      case 'unknown':
      case 'data-loss':
      case 'SocketException':
      case 'ClientException':
      case 'HttpException':
      case 'HandshakeException':
        return true;
      default:
        return false;
    }
  }

  /// Imprime el fallo tal cual, clasificado, para distinguirlo en la consola del dispositivo.
  static void registrarFalloConsulta(Object error, StackTrace stack) {
    final codigo = codigoFirestore(error);
    final firebase = error is FirebaseException
        ? 'plugin=${error.plugin} code=${error.code} message=${error.message}'
        : 'no es FirebaseException';
    debugPrint(
      'Firestore presencia error code: $codigo\n'
      'destino: Cloud Firestore colección "presencia" '
      '(proyecto ringo-backend, firestore.googleapis.com; sin localhost ni 127.0.0.1)\n'
      'lectura: firestore.rules permite leer presencia si request.auth != null\n'
      'clasificación: ${_clasificarFallo(error)}\n'
      'tipo: ${error.runtimeType}\n'
      'firebase: $firebase\n'
      'error: $error\n'
      '$stack',
    );
  }

  static String _clasificarFallo(Object error) {
    if (error is TimeoutException) return 'timeout';
    if (error is FormatException || error is TypeError) return 'parsing de datos';
    if (error is FirebaseException) {
      switch (error.code) {
        case 'deadline-exceeded':
          return 'timeout (Firestore deadline-exceeded)';
        case 'unavailable':
          return 'red o servicio no disponible (no es un 404)';
        case 'not-found':
          return 'HTTP-equivalente 404 (not-found)';
        case 'permission-denied':
        case 'unauthenticated':
          return 'acceso denegado (${error.code}); la consulta llegó al servidor';
        case 'internal':
        case 'unknown':
        case 'aborted':
        case 'data-loss':
          return 'error de servidor, equivalente a HTTP 5xx (${error.code})';
        default:
          return 'FirebaseException code=${error.code}';
      }
    }
    final texto = error.toString().toLowerCase();
    final tipo = error.runtimeType.toString();
    if (tipo == 'SocketException' ||
        tipo == 'ClientException' ||
        tipo == 'HttpException' ||
        tipo == 'HandshakeException' ||
        texto.contains('socketexception') ||
        texto.contains('failed host lookup') ||
        texto.contains('network')) {
      return 'fallo de red (el host de Firestore no respondió; no es localhost)';
    }
    if (texto.contains('timeoutexception') || texto.contains('timed out')) {
      return 'timeout';
    }
    if (texto.contains('formatexception') || texto.contains('type \'') || texto.contains('is not a subtype')) {
      return 'parsing de datos';
    }
    return 'error no clasificado; ver el detalle de abajo';
  }

  /// `null` cuando el resultado vacío viene solo de la caché local.
  Future<bool?> _evaluar(QuerySnapshot<Map<String, dynamic>> snap, String tipoServicio) async {
    final origen = snap.metadata.isFromCache ? 'caché' : 'servidor';
    var enLinea = 0;
    final descartes = <String, int>{};

    final servicio = _servicioCanonico(tipoServicio);
    debugPrint(
      'presencia: snapshot $origen servicioRecibido="$tipoServicio" '
      'servicioNormalizado=$servicio documentos=${snap.docs.length}',
    );
    for (final doc in snap.docs) {
      final data = doc.data();
      final vehiculoMap = _vehiculoMap(data);
      var tipoLeido = _tipoLeido(data);
      var tipo = _tipoNormalizado(tipoLeido);
      var origenTipo = 'presencia';
      final apagado = _motivoApagado(data);
      if (apagado == null && !_esMoto(tipo) && !_esCarro(tipo)) {
        final fallback = await _tipoDesdeConductor(doc.id);
        tipoLeido = fallback ?? tipoLeido;
        tipo = _tipoNormalizado(tipoLeido);
        origenTipo = 'conductores/${doc.id}.vehiculo.tipo';
      }
      final motivo = apagado ?? _motivoDescarte(tipo, tipoServicio);
      final coords = _coords(data);
      if (motivo == null) enLinea++;
      descartes[motivo ?? 'en línea'] = (descartes[motivo ?? 'en línea'] ?? 0) + 1;
      debugPrint(
        'presencia/${doc.id} ${motivo == null ? 'EN LÍNEA' : 'DESCARTADO'} ($origen)\n'
        '  documento=$data\n'
        '  disponible=${data['disponible']} estadoOperativo=${data['estadoOperativo']} '
        'conectado=${data['conectado']} (${data['conectado']?.runtimeType})\n'
        '  vehiculo=$vehiculoMap tipoLeido=$tipoLeido tipoNormalizado=$tipo origenTipo=$origenTipo\n'
        '  claves=${data.keys.toList()}\n'
        '  razon=${motivo ?? 'cuenta para $servicio'}$coords',
      );
    }

    debugPrint(
      'presencia: $origen documentos=${snap.docs.length} enLinea=$enLinea '
      'descartes=$descartes',
    );

    if (snap.docs.isEmpty) {
      debugPrint(
        'presencia: 0 documentos para $tipoServicio. '
        'Se espera vehiculo.tipo y disponible, estadoOperativo o conectado.',
      );
    }

    if (snap.metadata.isFromCache && enLinea == 0) {
      debugPrint(
        'presencia: la caché no tiene conductores de $tipoServicio; '
        'se espera la respuesta del servidor antes de mostrar el aviso.',
      );
      return null;
    }
    return enLinea > 0;
  }

  /// Tipo en `conductores/{id}` cuando `presencia` no trae `vehiculo` ni `tipo`.
  Future<Object?> _tipoDesdeConductor(String conductorId) async {
    final cache = _tipoPorConductor[conductorId];
    if (cache != null) return cache;
    try {
      final snap = await FirebaseFirestore.instance.collection('conductores').doc(conductorId).get();
      final data = snap.data();
      final vehiculo = data?['vehiculo'];
      final crudo = vehiculo is Map
          ? vehiculo['tipo']
          : vehiculo is String
              ? vehiculo
              : data?['tipoVehiculo'] ?? data?['tipo_vehiculo'] ?? data?['tipo'];
      final tipo = _tipoNormalizado(crudo);
      debugPrint(
        'presencia/$conductorId fallback conductores/$conductorId '
        'vehiculo.tipo=$crudo normalizado=$tipo',
      );
      if (tipo.isNotEmpty) _tipoPorConductor[conductorId] = tipo;
      return crudo;
    } on FirebaseException catch (error) {
      debugPrint(
        'presencia/$conductorId fallback conductores/$conductorId '
        'error code=${error.code}',
      );
      return null;
    }
  }

  /// `null` si [tipoNormalizado] aplica al servicio.
  ///
  /// La comparación es el texto completo, ya en minúsculas y sin espacios:
  /// - `moto` vale para mototaxi y delivery, y no para taxi.
  /// - `carro`, `auto` y `vehiculo` valen para taxi y delivery, y no para mototaxi.
  ///
  /// Un taxi no exige que el perfil diga "taxi". `carro` cuenta. "mototaxi"
  /// no cuenta como taxi aunque incluya esas cuatro letras.
  String? _motivoDescarte(String tipoNormalizado, String tipoServicio) {
    final servicio = _servicioCanonico(tipoServicio);
    final esMoto = _esMoto(tipoNormalizado);
    final esCarro = _esCarro(tipoNormalizado);
    if (!esMoto && !esCarro) {
      return 'conectado, sin tipo de vehículo en presencia ni en conductores.vehiculo.tipo '
          '(tipoNormalizado=$tipoNormalizado)';
    }
    switch (servicio) {
      case 'mototaxi':
        if (esMoto) return null;
        return 'rechazado: mototaxi solo admite vehiculo moto (es $tipoNormalizado)';
      case 'taxi':
        if (esCarro) return null;
        return 'rechazado: taxi solo admite carro, auto o vehiculo (es $tipoNormalizado)';
      case 'delivery':
        if (esMoto || esCarro) return null;
        return 'rechazado: delivery no admite $tipoNormalizado';
      default:
        return 'servicio no reconocido: $tipoServicio';
    }
  }

  /// En línea si `disponible` es true, `estadoOperativo` es "conectado"
  /// o `conectado` es true. Basta con una de las tres.
  String? _motivoApagado(Map<String, dynamic> data) {
    if (_boolFlexible(data['disponible']) == true) return null;
    if (_normalizar(data['estadoOperativo']) == 'conectado') return null;
    if (_boolFlexible(data['conectado']) == true) return null;
    return 'apagado '
        'disponible=${data['disponible']} '
        'estadoOperativo=${data['estadoOperativo']} '
        'conectado=${data['conectado']}';
  }

  Map<String, dynamic>? _vehiculoMap(Map<String, dynamic> doc) {
    final vehiculo = doc['vehiculo'];
    if (vehiculo is Map<String, dynamic>) return vehiculo;
    if (vehiculo is Map) {
      return vehiculo.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  /// `vehiculo.tipo` tiene prioridad. Si `vehiculo` es un texto, ese texto es
  /// el tipo. Luego `tipoVehiculo`, `tipo_vehiculo` y `tipo`.
  Object? _tipoLeido(Map<String, dynamic> doc) {
    final vehiculo = doc['vehiculo'];
    if (vehiculo is String) return vehiculo;
    final vehiculoMap = _vehiculoMap(doc);
    return vehiculoMap?['tipo'] ?? doc['tipoVehiculo'] ?? doc['tipo_vehiculo'] ?? doc['tipo'];
  }

  /// Minúsculas, sin espacios extremos y sin tildes.
  String _normalizar(Object? valor) {
    final texto = valor?.toString().trim().toLowerCase() ?? '';
    const origen = 'áéíóúüñ';
    const destino = 'aeiouun';
    final buffer = StringBuffer();
    for (final char in texto.split('')) {
      final i = origen.indexOf(char);
      buffer.write(i >= 0 ? destino[i] : char);
    }
    return buffer.toString();
  }

  /// Minúsculas y sin espacios extremos. No parte el texto: "mototaxi"
  /// sigue distinto de "taxi" y de "moto".
  String _tipoNormalizado(Object? valor) => _normalizar(valor);

  bool _esMoto(String tipoNormalizado) {
    switch (tipoNormalizado) {
      case 'moto':
      case 'motocicleta':
        return true;
      default:
        return false;
    }
  }

  /// El perfil de un carro dice `carro`, `auto` o `vehiculo`. No hace falta
  /// que diga `taxi`. `automovil` es el mismo vehículo.
  bool _esCarro(String tipoNormalizado) {
    switch (tipoNormalizado) {
      case 'carro':
      case 'auto':
      case 'vehiculo':
      case 'automovil':
        return true;
      default:
        return false;
    }
  }

  /// "Moto Taxi" / moto_taxi / moto -> mototaxi.
  /// "Taxi (Carro)" / carro / taxicarro -> taxi.
  /// "Delivery" -> delivery.
  String _servicioCanonico(String tipoServicio) {
    final compacto = _compacto(tipoServicio);
    if (compacto == 'delivery') return 'delivery';
    if (compacto == 'moto' || compacto == 'mototaxi' || compacto == 'motocicleta') {
      return 'mototaxi';
    }
    if (compacto == 'taxi' ||
        compacto == 'carro' ||
        compacto == 'taxicarro' ||
        compacto == 'auto' ||
        compacto == 'vehiculo') {
      return 'taxi';
    }
    return '';
  }

  String _compacto(Object? valor) => _normalizar(valor).replaceAll(RegExp(r'[^a-z]'), '');

  bool? _boolFlexible(Object? valor) {
    if (valor is bool) return valor;
    if (valor is num) {
      if (valor == 1) return true;
      if (valor == 0) return false;
      return null;
    }
    if (valor is String) {
      final texto = _normalizar(valor);
      if (texto == 'true' || texto == '1' || texto == 'conectado' || texto == 'online') {
        return true;
      }
      if (texto == 'false' || texto == '0' || texto == 'desconectado' || texto == 'offline') {
        return false;
      }
    }
    return null;
  }

  String _coords(Map<String, dynamic> data) {
    final lat = data['latitud'] ?? data['lat'];
    final lng = data['longitud'] ?? data['lng'] ?? data['lon'];
    if (lat == null && lng == null) {
      return ' coords=ausentes (presencia no guarda la ubicación)';
    }
    return ' lat=$lat lng=$lng';
  }
}
