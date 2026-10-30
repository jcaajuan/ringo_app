import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/datos_registro.dart';
import 'google_auth_service.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  static String _normalizarEmail(String email) => email.trim().toLowerCase();

  Future<void> iniciarSesion({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _normalizarEmail(email),
        password: password.trim(),
      );
    } catch (e) {
      throw AuthException._from(e);
    }
  }

  Future<void> registrar({
    required String nombre,
    required String email,
    required String telefono,
    required String password,
    required DatosRegistro datos,
  }) async {
    final direccion = datos.direccion.trim();
    final cedula = DatosRegistro.normalizarCedula(datos.cedulaIdentidad);
    if (DatosRegistro.validarDireccion(direccion) != null ||
        DatosRegistro.validarCedula(cedula) != null ||
        !datos.esMayorDeEdad ||
        !DatosRegistro.tieneMayoriaDeEdad(datos.fechaNacimiento)) {
      throw AuthException(
        'Completa tus datos y confirma que eres mayor de 18 años.',
      );
    }

    UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: _normalizarEmail(email),
        password: password.trim(),
      );
    } catch (e) {
      throw AuthException._from(e);
    }

    final user = cred.user;
    if (user == null) {
      throw AuthException('No se pudo crear la cuenta. Intenta de nuevo.');
    }

    try {
      await user.updateDisplayName(nombre.trim());
    } catch (e) {
      debugPrint('No se pudo actualizar el nombre: $e');
    }

    final nacimiento = datos.fechaNacimiento;
    try {
      await _db.collection('usuarios').doc(user.uid).set({
        'nombre': nombre.trim(),
        'email': _normalizarEmail(email),
        'telefono': telefono.trim(),
        'fechaNacimiento': Timestamp.fromDate(DateTime.utc(
          nacimiento.year,
          nacimiento.month,
          nacimiento.day,
        )),
        'direccion': direccion,
        'cedulaIdentidad': cedula,
        'esMayorDeEdad': datos.esMayorDeEdad,
        'telefonoVerificado': true,
        'rol': 'cliente',
        'ciudad': 'El Tigre',
        'estado': 'Anzoátegui',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // La cuenta de Auth ya existe; no bloquear el ingreso por reglas de Firestore.
      debugPrint('Perfil no guardado en Firestore: $e');
    }
  }

  Future<void> cerrarSesion() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        await _db.collection('usuarios').doc(uid).update({
          'fcmToken': FieldValue.delete(),
        });
      } catch (_) {
        // Si el perfil aún no existe, no hay token que borrar.
      }
    }
    await GoogleAuthService.instance.cerrar();
    await _auth.signOut();
  }
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  factory AuthException._from(Object e) {
    if (e is FirebaseAuthException) {
      return AuthException(_mensajeAuth(e.code, e.message));
    }
    if (e is FirebaseException) {
      return AuthException(_mensajeAuth(e.code, e.message));
    }
    final text = e.toString();
    final match = RegExp(r'auth/([a-z0-9._-]+)').firstMatch(text);
    if (match != null) {
      return AuthException(_mensajeAuth(match.group(1)!, text));
    }
    return AuthException(text);
  }

  static String _mensajeAuth(String code, String? detalle) {
    switch (code.replaceAll('_', '-')) {
      case 'invalid-email':
        return 'El correo electrónico no es válido.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada.';
      case 'user-not-found':
        return 'No hay una cuenta con ese correo en RinGo!. Usa Crear cuenta.';
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Correo o contraseña no coinciden. Si te registraste antes de conectar Firebase, crea la cuenta otra vez.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo. Prueba iniciar sesión.';
      case 'weak-password':
        return 'La contraseña es muy débil. Usa al menos 6 caracteres.';
      case 'network-request-failed':
        return 'Sin conexión. Revisa tu internet e intenta de nuevo.';
      case 'operation-not-allowed':
        return 'El inicio de sesión por correo no está habilitado en Firebase.';
      case 'unauthorized-domain':
        return 'Este dominio no está autorizado. En Firebase: Authentication → Settings → Authorized domains, agrega localhost.';
      case 'api-key-not-valid':
      case 'api-key-not-valid.-please-pass-a-valid-api-key.':
      case 'invalid-api-key':
      case 'app-not-authorized':
      case 'configuration-not-found':
        return 'La app no está conectada al proyecto Firebase correcto (debe ser ringo-backend). Revisa firebase_options.dart.';
      case 'permission-denied':
        return 'Firestore bloqueó el perfil. Publica reglas que permitan a cada usuario escribir en usuarios/{suUid}.';
      case 'no-app':
        return 'Firebase no se inicializó. Revisa la configuración web del proyecto ringo-backend.';
      default:
        return detalle?.isNotEmpty == true
            ? detalle!
            : 'No se pudo completar la operación ($code).';
    }
  }

  @override
  String toString() => message;
}
