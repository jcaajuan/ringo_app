import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class GoogleAuthException implements Exception {
  GoogleAuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Datos públicos del usuario después de entrar con Google.
class PerfilGoogle {
  const PerfilGoogle({
    required this.uid,
    required this.email,
    required this.nombre,
    required this.fotoUrl,
    required this.esNuevo,
    this.avisoServidor,
  });

  final String uid;
  final String email;
  final String nombre;
  final String fotoUrl;
  final bool esNuevo;

  /// El ingreso en Firebase ya ocurrió, pero el servidor no guardó `usuarios`.
  final String? avisoServidor;
}

/// Inicio de sesión con Google y sesión de Firebase Auth.
class GoogleAuthService {
  GoogleAuthService._();
  static final GoogleAuthService instance = GoogleAuthService._();

  final GoogleSignIn _google = GoogleSignIn(scopes: const ['email', 'profile']);
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Abre el selector de Google, crea la sesión de Firebase y sincroniza el perfil.
  /// Devuelve null si la persona cierra el selector.
  Future<PerfilGoogle?> entrar() async {
    final GoogleSignInAccount? cuenta;
    try {
      cuenta = await _google.signIn();
    } on PlatformException catch (error) {
      if (_cancelado(error.code)) return null;
      throw GoogleAuthException(_mensajePlataforma(error));
    }
    if (cuenta == null) return null;

    final tokens = await cuenta.authentication;
    if ((tokens.idToken == null || tokens.idToken!.isEmpty) &&
        (tokens.accessToken == null || tokens.accessToken!.isEmpty)) {
      throw GoogleAuthException(
        'Google no entregó el token. En Firebase activa el proveedor Google y descarga de nuevo google-services.json con el SHA-1 de la app.',
      );
    }

    try {
      final credencial = GoogleAuthProvider.credential(
        accessToken: tokens.accessToken,
        idToken: tokens.idToken,
      );
      final ingreso = await _auth.signInWithCredential(credencial);
      final user = ingreso.user;
      if (user == null) {
        throw GoogleAuthException('No se pudo abrir la sesión de Firebase.');
      }

      final nombre = user.displayName ?? cuenta.displayName ?? '';
      final email = user.email ?? cuenta.email;
      final foto = user.photoURL ?? cuenta.photoUrl ?? '';
      final esNuevoLocal = await _guardarPerfilLocal(
        uid: user.uid,
        email: email,
        nombre: nombre,
        fotoUrl: foto,
      );

      final idTokenFirebase = await user.getIdToken();
      if (idTokenFirebase == null || idTokenFirebase.isEmpty) {
        return PerfilGoogle(
          uid: user.uid,
          email: email,
          nombre: nombre,
          fotoUrl: foto,
          esNuevo: esNuevoLocal,
          avisoServidor: 'La sesión quedó abierta, pero no se pudo enviar el token al servidor.',
        );
      }

      final remoto = await _sincronizarServidor(idTokenFirebase);
      return PerfilGoogle(
        uid: user.uid,
        email: email,
        nombre: nombre,
        fotoUrl: foto,
        esNuevo: remoto?.esNuevo ?? esNuevoLocal,
        avisoServidor: remoto == null
            ? 'La sesión quedó abierta. El servidor no pudo guardar el perfil todavía.'
            : null,
      );
    } on GoogleAuthException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw GoogleAuthException(_mensajeFirebase(error));
    }
  }

  /// Cierra la cuenta de Google elegida para que el próximo ingreso muestre el selector.
  Future<void> cerrar() async {
    try {
      await _google.signOut();
    } catch (error) {
      debugPrint('No se pudo cerrar Google Sign-In: $error');
    }
  }

  Future<bool> _guardarPerfilLocal({
    required String uid,
    required String email,
    required String nombre,
    required String fotoUrl,
  }) async {
    final ref = _db.collection('usuarios').doc(uid);
    final previo = await ref.get();
    final nuevo = !previo.exists;
    await ref.set({
      'uid': uid,
      'email': email,
      'nombre': nombre,
      'displayName': nombre,
      'photoURL': fotoUrl,
      'proveedor': 'google',
      'rol': 'cliente',
      if (nuevo) 'telefono': '',
      if (nuevo) 'ciudad': 'El Tigre',
      if (nuevo) 'estado': 'Anzoátegui',
      if (nuevo) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return nuevo;
  }

  Future<({bool esNuevo})?> _sincronizarServidor(String idToken) async {
    try {
      final respuesta = await http
          .post(
            Uri.parse('$kApiBaseUrl/api/auth/google'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'idToken': idToken}),
          )
          .timeout(const Duration(seconds: 30));
      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(respuesta.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}
      if (respuesta.statusCode < 200 || respuesta.statusCode >= 300 || data['success'] != true) {
        debugPrint('Perfil Google no guardado en el servidor: ${respuesta.statusCode} ${respuesta.body}');
        return null;
      }
      return (esNuevo: data['isNewUser'] == true);
    } catch (error) {
      debugPrint('No se alcanzó /api/auth/google: $error');
      return null;
    }
  }

  bool _cancelado(String code) {
    return code == 'sign_in_canceled' || code == 'sign_in_cancelled' || code == 'canceled';
  }

  String _mensajePlataforma(PlatformException error) {
    if (error.code == 'network_error') {
      return 'Sin conexión. Revisa tu internet e intenta de nuevo.';
    }
    if (error.code == 'sign_in_failed') {
      return 'Google rechazó el ingreso. Activa el proveedor Google en Firebase y registra el SHA-1 de la app.';
    }
    return 'No se pudo continuar con Google.';
  }

  String _mensajeFirebase(FirebaseAuthException error) {
    switch (error.code) {
      case 'account-exists-with-different-credential':
        return 'Ese correo ya tiene una cuenta con otro método. Entra con tu contraseña.';
      case 'invalid-credential':
        return 'La credencial de Google no es válida. Intenta de nuevo.';
      case 'network-request-failed':
        return 'Sin conexión. Revisa tu internet e intenta de nuevo.';
      default:
        return 'No se pudo iniciar la sesión con Google.';
    }
  }
}
