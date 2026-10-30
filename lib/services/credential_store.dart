import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Correo y contraseña en almacenamiento cifrado.
///
/// En Android usa EncryptedSharedPreferences. En iOS, el Keychain.
class CredentialStore {
  CredentialStore._();
  static final CredentialStore instance = CredentialStore._();

  static const _email = 'ringo_login_email';
  static const _password = 'ringo_login_password';
  static const _huella = 'ringo_login_huella';

  final FlutterSecureStorage _caja = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> guardar({
    required String email,
    required String password,
  }) async {
    await _caja.write(key: _email, value: email.trim().toLowerCase());
    await _caja.write(key: _password, value: password);
  }

  Future<({String email, String password})?> leer() async {
    final email = await _caja.read(key: _email);
    final password = await _caja.read(key: _password);
    if (email == null || email.isEmpty || password == null || password.isEmpty) {
      return null;
    }
    return (email: email, password: password);
  }

  Future<bool> huellaActiva() async {
    return await _caja.read(key: _huella) == '1';
  }

  Future<void> definirHuella(bool activa) async {
    await _caja.write(key: _huella, value: activa ? '1' : '0');
  }

  Future<void> borrar() async {
    await _caja.delete(key: _email);
    await _caja.delete(key: _password);
    await _caja.delete(key: _huella);
  }
}
