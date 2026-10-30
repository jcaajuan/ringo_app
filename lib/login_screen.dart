import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'register_screen.dart';
import 'widgets/google_sign_in_button.dart';
import 'services/auth_service.dart';
import 'services/biometric_service.dart';
import 'services/credential_store.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _huellaLista = false;

  @override
  void initState() {
    super.initState();
    _prepararHuella();
  }

  Future<void> _prepararHuella() async {
    final activa = await CredentialStore.instance.huellaActiva();
    final guardadas = await CredentialStore.instance.leer();
    if (!activa || guardadas == null) return;
    final estado = await BiometricService.instance.estado();
    if (!mounted) return;
    if (estado != BiometriaEstado.lista) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(BiometricService.instance.mensajeDe(estado))),
      );
      return;
    }
    setState(() => _huellaLista = true);
  }

  Future<void> _entrarConHuella() async {
    setState(() => _isLoading = true);
    try {
      final bio = await BiometricService.instance.autenticar();
      if (!mounted) return;
      if (bio.mensaje != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(bio.mensaje!)));
        return;
      }
      if (!bio.aceptada) return;
      final credenciales = await CredentialStore.instance.leer();
      if (credenciales == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay credenciales guardadas. Entra con tu contraseña.')),
        );
        return;
      }
      await AuthService.instance.iniciarSesion(
        email: credenciales.email,
        password: credenciales.password,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (error) {
      await CredentialStore.instance.definirHuella(false);
      if (!mounted) return;
      setState(() => _huellaLista = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${error.message} Vuelve a entrar con tu contraseña.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo entrar con huella: $error')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.iniciarSesion(
        email: _emailController.text,
        password: _passwordController.text,
      );
      await CredentialStore.instance.guardar(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      // AuthGate en main.dart muestra Home al detectar la sesión.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Crear cuenta',
            textColor: AppColors.primaryYellow,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RegisterScreen()),
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo iniciar sesión: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Iniciar Sesión'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const Center(
                  child: RingoBrandHeader(
                    fontSize: 32,
                    showSubtitle: true,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  '¡Hola de nuevo! 👋',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.blackPure,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ingresa tus credenciales para continuar en RinGo!',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.mediumGray,
                  ),
                ),
                const SizedBox(height: 28),
                const GoogleSignInButton(),
                const SizedBox(height: 18),
                const SeparadorAuth(texto: 'o entra con tu correo'),
                const SizedBox(height: 18),

                // Campo Correo Electrónico
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.blackPure),
                  decoration: const InputDecoration(
                    labelText: 'Correo Electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa tu correo';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Ingresa un correo electrónico válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Campo Contraseña
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.blackPure),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa tu contraseña';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // Botón Iniciar Sesión (Amarillo vibrante con texto negro)
                ElevatedButton(
                  onPressed: _isLoading ? null : _iniciarSesion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryYellow,
                    foregroundColor: AppColors.blackPure,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: AppColors.blackPure,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Ingresar',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                ),
                if (_huellaLista) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _entrarConHuella,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text(
                      'Entrar con huella',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Enlace hacia la pantalla de registro
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '¿No tienes una cuenta? ',
                      style: TextStyle(color: AppColors.mediumGray, fontWeight: FontWeight.w500),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Regístrate aquí',
                        style: TextStyle(
                          color: AppColors.blackPure,
                          fontWeight: FontWeight.w900,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}