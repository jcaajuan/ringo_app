import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class CuponException implements Exception {
  CuponException(this.message);
  final String message;

  @override
  String toString() => message;
}

class CuponCanje {
  const CuponCanje({required this.discountPercent, required this.serviceType});

  final int discountPercent;
  final String serviceType;
}

class CuponService {
  CuponService._();
  static final CuponService instance = CuponService._();

  static const codigoPrimerViaje = 'PRIMERVIAJE';

  Future<CuponCanje> reclamarPrimerViaje({
    required String userId,
    required String deviceId,
    required String serviceType,
  }) async {
    final cuerpo = <String, String>{
      'userId': userId,
      'deviceId': deviceId,
      'serviceType': serviceType,
      'code': codigoPrimerViaje,
    };
    final data = await _post('/api/coupons/claim', cuerpo);
    if (data['success'] != true || data['discountPercent'] != 100) {
      throw CuponException('No se pudo aplicar el cupón.');
    }
    return CuponCanje(discountPercent: 100, serviceType: serviceType);
  }

  Future<Map<String, dynamic>> _post(String ruta, Map<String, String> cuerpo) async {
    final url = '$kApiBaseUrl$ruta';
    final http.Response respuesta;
    try {
      respuesta = await http
          .post(
            Uri.parse(url),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(cuerpo),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw CuponException('El servidor no respondió. Intenta de nuevo.');
    } catch (_) {
      throw CuponException('No hay conexión con el servidor. Comprueba tu internet.');
    }

    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(respuesta.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {
      data = {};
    }

    if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
      final mensaje = data['message'];
      throw CuponException(
        mensaje is String && mensaje.isNotEmpty ? mensaje : 'No se pudo aplicar el cupón.',
      );
    }
    return data;
  }
}
