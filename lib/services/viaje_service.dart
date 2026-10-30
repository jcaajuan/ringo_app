import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

import '../tarifas.dart';

class ViajeActivo {
  const ViajeActivo({
    required this.id,
    required this.estado,
    required this.tipoServicio,
    required this.origen,
    required this.destino,
    required this.monto,
    required this.origenDireccion,
    required this.destinoDireccion,
    this.pasajeroNombre,
    this.conductorId,
    this.conductorNombre,
    this.conductorTelefono,
    this.vehiculoResumen,
    this.ubicacionConductor,
    this.rumboConductor,
    this.recorrido = const [],
    this.creadoEn,
    this.montoUsd,
    this.tasaCambioUsdBolivares,
    this.montoBolivares,
    this.metodoPago,
  });

  final String id;
  final String estado;
  final String tipoServicio;
  final LatLng origen;
  final LatLng destino;
  final double monto;
  final String origenDireccion;
  final String destinoDireccion;
  final String? pasajeroNombre;
  final String? conductorId;
  final String? conductorNombre;
  final String? conductorTelefono;
  final String? vehiculoResumen;
  final LatLng? ubicacionConductor;
  final double? rumboConductor;
  final List<LatLng> recorrido;
  final DateTime? creadoEn;
  final double? montoUsd;
  final double? tasaCambioUsdBolivares;
  final double? montoBolivares;
  final String? metodoPago;

  bool get esEfectivo => metodoPago == 'efectivo';

  String get etiquetaPago {
    if (metodoPago == 'efectivo') return 'Efectivo';
    if (metodoPago == 'cupon') return 'Primer viaje gratis';
    return 'Pago móvil';
  }

  double get dolares => montoUsd ?? monto;

  bool get sigueAbierto =>
      estado == 'pendiente' || estado == 'aceptado' || estado == 'llego' || estado == 'en_curso';

  bool get puedeCancelar => estado == 'pendiente' || estado == 'aceptado' || estado == 'llego';

  String get tituloEstado {
    switch (estado) {
      case 'pendiente':
        return 'Buscando un conductor cercano';
      case 'aceptado':
        return 'El conductor va en camino';
      case 'llego':
        return 'El conductor llegó';
      case 'en_curso':
        return 'Viaje en curso';
      case 'finalizado':
        return 'Viaje finalizado';
      case 'cancelado':
        return 'Viaje cancelado';
      case 'expirado':
        return 'No hubo conductor disponible';
      default:
        return estado;
    }
  }

  static ViajeActivo? desde(String id, Map<String, dynamic> data) {
    final origen = _punto(data['origen']);
    final destino = _punto(data['destino']);
    if (origen == null || destino == null) return null;
    final monto = data['monto'];
    return ViajeActivo(
      id: id,
      estado: (data['estado'] as String?) ?? 'pendiente',
      tipoServicio: (data['tipoServicio'] as String?) ?? '',
      origen: origen,
      destino: destino,
      monto: monto is num ? monto.toDouble() : 0,
      origenDireccion: (data['origenDireccion'] as String?)?.trim() ?? '',
      destinoDireccion: (data['destinoDireccion'] as String?)?.trim() ?? '',
      pasajeroNombre: _texto(data['pasajeroNombre']),
      conductorId: _texto(data['conductorId']),
      conductorNombre: _texto(data['conductorNombre']),
      conductorTelefono: _texto(data['conductorTelefono']),
      vehiculoResumen: _texto(data['vehiculoResumen']),
      ubicacionConductor: _punto(data['ubicacionConductor']),
      rumboConductor: _rumbo(data['rumboConductor']),
      recorrido: _recorrido(data['recorrido']),
      creadoEn: _fecha(data['createdAt']),
      montoUsd: _numero(data['montoUsd']),
      tasaCambioUsdBolivares: _numero(data['tasaCambioUsdBolivares']),
      montoBolivares: _numero(data['montoBolivares']),
      metodoPago: _texto(data['metodoPago']),
    );
  }

  static LatLng? _punto(dynamic value) {
    if (value is GeoPoint) return LatLng(value.latitude, value.longitude);
    return null;
  }

  static double? _rumbo(dynamic value) {
    if (value is num && value >= 0) return value.toDouble();
    return null;
  }

  static List<LatLng> _recorrido(dynamic value) {
    if (value is! Iterable) return const [];
    final puntos = <LatLng>[];
    for (final item in value) {
      final punto = _punto(item);
      if (punto != null) puntos.add(punto);
    }
    return puntos;
  }

  static double? _numero(dynamic value) {
    if (value is num && value >= 0) return value.toDouble();
    return null;
  }

  static String? _texto(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static DateTime? _fecha(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class ViajeService {
  ViajeService._();
  static final ViajeService instance = ViajeService._();

  static const vigencia = Duration(minutes: 5);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> crearSolicitud({
    required String tipoServicio,
    required LatLng origen,
    required LatLng destino,
    required String origenDireccion,
    required String destinoDireccion,
    required double monto,
    required double distanciaKm,
    required double tarifaPorKm,
    required String metodoPago,
    required String referenciaPago,
    String? cupon,
    double? montoOriginalUsd,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Debes iniciar sesión para solicitar un servicio.');
    }
    final servicio = tipoServicio.trim();
    if (servicio != 'mototaxi' && servicio != 'taxi' && servicio != 'delivery') {
      throw StateError('El tipo de servicio no es válido.');
    }

    var nombre = user.displayName ?? '';
    var telefono = '';
    try {
      final perfil = await _db.collection('usuarios').doc(user.uid).get();
      final data = perfil.data();
      final nombrePerfil = data?['nombre'];
      final telefonoPerfil = data?['telefono'];
      if (nombrePerfil is String && nombrePerfil.trim().isNotEmpty) {
        nombre = nombrePerfil.trim();
      }
      if (telefonoPerfil is String) telefono = telefonoPerfil.trim();
    } catch (_) {}

    double? tasa;
    try {
      final tasaDoc = await _db.collection('settings').doc('exchange_rate').get();
      final tasaRaw = tasaDoc.data()?['vesRate'];
      if (tasaRaw is num && tasaRaw > 0) tasa = tasaRaw.toDouble();
    } catch (_) {}
    final bolivares = tasa == null ? null : Tarifas.bolivares(monto, tasa);

    final doc = await _db.collection('viajes').add({
      'userId': user.uid,
      'email': user.email,
      'pasajeroNombre': nombre,
      'pasajeroTelefono': telefono,
      'tipoServicio': servicio,
      'origen': GeoPoint(origen.latitude, origen.longitude),
      'destino': GeoPoint(destino.latitude, destino.longitude),
      'origenDireccion': origenDireccion.trim(),
      'destinoDireccion': destinoDireccion.trim(),
      'monto': monto,
      'montoUsd': monto,
      if (montoOriginalUsd != null) 'montoOriginalUsd': montoOriginalUsd,
      if (cupon != null && cupon.trim().isNotEmpty) 'cupon': cupon.trim(),
      if (cupon != null && cupon.trim().isNotEmpty) 'descuentoPorcentaje': 100,
      if (tasa != null) 'tasaCambioUsdBolivares': tasa,
      if (bolivares != null) 'montoBolivares': bolivares,
      'moneda': 'USD',
      'distanciaKm': distanciaKm,
      'tarifaPorKmUsd': tarifaPorKm,
      'referenciaPago': referenciaPago,
      'metodoPago': metodoPago == 'efectivo'
          ? 'efectivo'
          : metodoPago == 'cupon'
              ? 'cupon'
              : 'digital',
      'estado': 'pendiente',
      'ciudad': 'El Tigre',
      'estadoVenezuela': 'Anzoátegui',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  /// Escucha el viaje abierto. Cada snapshot trae la posición, el rumbo
  /// y los vértices del recorrido que publica la app del conductor.
  Stream<ViajeActivo?> observar(String viajeId) {
    return _db.collection('viajes').doc(viajeId).snapshots().map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return ViajeActivo.desde(snap.id, data);
    });
  }

  Stream<List<ViajeActivo>> observarPropios() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db.collection('viajes').where('userId', isEqualTo: uid).limit(30).snapshots().map((snap) {
      final viajes = <ViajeActivo>[];
      for (final doc in snap.docs) {
        final viaje = ViajeActivo.desde(doc.id, doc.data());
        if (viaje != null) viajes.add(viaje);
      }
      viajes.sort((a, b) {
        final fa = a.creadoEn;
        final fb = b.creadoEn;
        if (fa == null && fb == null) return 0;
        if (fa == null) return 1;
        if (fb == null) return -1;
        return fb.compareTo(fa);
      });
      return viajes;
    });
  }

  Future<void> cancelar(String viajeId) {
    return _db.collection('viajes').doc(viajeId).update({
      'estado': 'cancelado',
      'canceladoPor': 'pasajero',
      'canceladoAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> expirar(String viajeId) {
    return _db.collection('viajes').doc(viajeId).update({
      'estado': 'expirado',
      'expiradoAt': FieldValue.serverTimestamp(),
    });
  }
}
