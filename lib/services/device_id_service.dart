import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceIdException implements Exception {
  DeviceIdException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Identificador del teléfono para el cupón de primer viaje.
///
/// En Android lee ANDROID_ID. En iOS lee identifierForVendor.
/// El valor queda en almacenamiento cifrado y se reutiliza en cada canje.
class DeviceIdService {
  DeviceIdService._();
  static final DeviceIdService instance = DeviceIdService._();

  static const _clave = 'ringo_device_id';

  final FlutterSecureStorage _caja = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final DeviceInfoPlugin _info = DeviceInfoPlugin();
  final AndroidId _androidId = const AndroidId();

  Future<String> obtener() async {
    final guardado = (await _caja.read(key: _clave))?.trim();
    if (guardado != null && guardado.isNotEmpty) return guardado;

    final hardware = await _leerHardware();
    await _caja.write(key: _clave, value: hardware);
    return hardware;
  }

  Future<String> _leerHardware() async {
    if (Platform.isAndroid) {
      final id = (await _androidId.getId())?.trim();
      if (id == null || id.isEmpty) {
        throw DeviceIdException('No se pudo leer el identificador de este Android.');
      }
      return id;
    }
    if (Platform.isIOS) {
      final ios = await _info.iosInfo;
      final id = ios.identifierForVendor?.trim();
      if (id == null || id.isEmpty) {
        throw DeviceIdException('No se pudo leer el identificador de este iPhone.');
      }
      return id;
    }
    throw DeviceIdException('El cupón solo se puede canjear desde la app del teléfono.');
  }
}
