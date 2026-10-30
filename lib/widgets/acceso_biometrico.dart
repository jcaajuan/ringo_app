import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/credential_store.dart';
import '../theme/app_theme.dart';

/// Interruptor de entrada con huella o Face ID, visible con la sesión abierta.
class AccesoBiometrico extends StatefulWidget {
  const AccesoBiometrico({super.key});

  @override
  State<AccesoBiometrico> createState() => _AccesoBiometricoState();
}

class _AccesoBiometricoState extends State<AccesoBiometrico> {
  bool _activa = false;
  bool _cargando = true;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _leer();
  }

  Future<void> _leer() async {
    final activa = await CredentialStore.instance.huellaActiva();
    if (!mounted) return;
    setState(() {
      _activa = activa;
      _cargando = false;
    });
  }

  void _aviso(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: AppColors.blackPure),
    );
  }

  Future<void> _cambiar(bool encender) async {
    if (_ocupado) return;
    if (!encender) {
      await CredentialStore.instance.definirHuella(false);
      if (mounted) setState(() => _activa = false);
      return;
    }

    final estado = await BiometricService.instance.estado();
    if (!mounted) return;
    if (estado != BiometriaEstado.lista) {
      _aviso(BiometricService.instance.mensajeDe(estado));
      setState(() => _activa = false);
      return;
    }

    var credenciales = await CredentialStore.instance.leer();
    if (!mounted) return;
    if (credenciales == null) {
      final password = await _pedirContrasena();
      if (!mounted || password == null || password.isEmpty) return;
      final email = AuthService.instance.currentUser?.email;
      if (email == null || email.isEmpty) {
        _aviso('Vuelve a iniciar sesión para activar la huella.');
        return;
      }
      setState(() => _ocupado = true);
      try {
        await AuthService.instance.iniciarSesion(email: email, password: password);
        await CredentialStore.instance.guardar(email: email, password: password);
        credenciales = (email: email, password: password);
      } on AuthException catch (error) {
        if (mounted) _aviso(error.message);
        return;
      } finally {
        if (mounted) setState(() => _ocupado = false);
      }
    }

    final bio = await BiometricService.instance.autenticar();
    if (!mounted) return;
    if (bio.mensaje != null) {
      _aviso(bio.mensaje!);
      return;
    }
    if (!bio.aceptada) return;

    await CredentialStore.instance.definirHuella(true);
    if (mounted) setState(() => _activa = true);
  }

  Future<String?> _pedirContrasena() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirma tu contraseña'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Contraseña'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Continuar'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: const Icon(Icons.fingerprint_rounded, color: AppColors.blackPure),
        title: const Text(
          'Entrar con huella',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text('Usa huella o Face ID la próxima vez que abras RinGo!'),
        value: _activa,
        onChanged: _cargando || _ocupado ? null : _cambiar,
      ),
    );
  }
}
