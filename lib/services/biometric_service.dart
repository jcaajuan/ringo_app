import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Estado del sensor de huella o Face ID en este dispositivo.
enum BiometriaEstado {
  lista,
  sinSensor,
  sinHuellas,
  noDisponible,
}

class BiometriaResultado {
  const BiometriaResultado._({required this.aceptada, this.mensaje});

  const BiometriaResultado.aceptada() : this._(aceptada: true);

  const BiometriaResultado.cancelada() : this._(aceptada: false);

  const BiometriaResultado.error(String mensaje) : this._(aceptada: false, mensaje: mensaje);

  final bool aceptada;

  /// Null si el usuario canceló. Con texto, hay que mostrarlo.
  final String? mensaje;
}

class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();

  Future<BiometriaEstado> estado() async {
    if (kIsWeb) return BiometriaEstado.noDisponible;
    try {
      final soportado = await _auth.isDeviceSupported();
      if (!soportado) return BiometriaEstado.sinSensor;
      final puede = await _auth.canCheckBiometrics;
      if (!puede) return BiometriaEstado.sinHuellas;
      return BiometriaEstado.lista;
    } on PlatformException {
      return BiometriaEstado.noDisponible;
    }
  }

  String mensajeDe(BiometriaEstado estado) {
    switch (estado) {
      case BiometriaEstado.lista:
        return '';
      case BiometriaEstado.sinSensor:
        return 'Este dispositivo no tiene sensor de huella ni Face ID.';
      case BiometriaEstado.sinHuellas:
        return 'No hay huellas ni un rostro registrado. Agrégalos en los ajustes del teléfono.';
      case BiometriaEstado.noDisponible:
        return 'La biometría no está disponible en este dispositivo.';
    }
  }

  /// Pide huella o Face ID. Cancelar no es un error.
  Future<BiometriaResultado> autenticar() async {
    final actual = await estado();
    if (actual != BiometriaEstado.lista) {
      return BiometriaResultado.error(mensajeDe(actual));
    }
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Confirma tu identidad para entrar a RinGo!',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!ok) return const BiometriaResultado.cancelada();
      return const BiometriaResultado.aceptada();
    } on PlatformException catch (error) {
      return BiometriaResultado.error(_mensaje(error.code));
    } catch (error) {
      return BiometriaResultado.error('No se pudo usar la biometría: $error');
    }
  }

  String _mensaje(String code) {
    switch (code) {
      case 'NotAvailable':
      case 'no_fragment_activity':
        return 'Este dispositivo no tiene sensor de huella ni Face ID.';
      case 'NotEnrolled':
      case 'PasscodeNotSet':
        return 'No hay huellas ni un rostro registrado. Agrégalos en los ajustes del teléfono.';
      case 'LockedOut':
      case 'PermanentlyLockedOut':
        return 'Demasiados intentos. Desbloquea el teléfono con tu PIN e inténtalo de nuevo.';
      default:
        return 'No se pudo verificar la huella o el rostro.';
    }
  }
}
