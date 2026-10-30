import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/datos_registro.dart';
import 'services/auth_service.dart';
import 'services/credential_store.dart';
import 'theme/app_theme.dart';
import 'terms_and_conditions_screen.dart';
import 'widgets/google_sign_in_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static final _soloLetrasYEspacios = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]+$');
  static final _emailValido = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  static const _estiloCampo = TextStyle(
    fontWeight: FontWeight.w600,
    color: AppColors.blackPure,
  );
  static const _estiloCasilla = TextStyle(
    fontSize: 14.5,
    height: 1.4,
    color: AppColors.mediumGray,
    fontWeight: FontWeight.w500,
  );

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _direccionController = TextEditingController();
  final _cedulaController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  int? _diaNacimiento;
  int? _mesNacimiento;
  int? _anioNacimiento;
  bool _obscurePassword = true;
  bool _esMayorDeEdad = false;
  bool _aceptaTerminos = false;
  bool _guardando = false;
  late final TapGestureRecognizer _termsRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()..onTap = _abrirTerminos;
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _nameController.dispose();
    _direccionController.dispose();
    _cedulaController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _abrirTerminos() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TermsAndConditionsScreen(),
      ),
    );
  }

  String? _normalizarTelefonoVe(String entrada) {
    var digitos = entrada.replaceAll(RegExp(r'\D'), '');
    if (digitos.startsWith('58') && digitos.length > 10) {
      digitos = digitos.substring(2);
    }
    if (digitos.startsWith('0')) digitos = digitos.substring(1);
    if (digitos.length != 10) return null;
    final telefono = '+58$digitos';
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(telefono) ? telefono : null;
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> _registrarse() async {
    final esValido = _formKey.currentState!.validate();
    if (!esValido) {
      _mostrarError('Revisa los campos marcados e inténtalo de nuevo.');
      return;
    }
    if (!_esMayorDeEdad) {
      _mostrarError('Debes confirmar que eres mayor de 18 años de edad.');
      return;
    }
    if (!_aceptaTerminos) {
      _mostrarError('Debes aceptar los Términos y Condiciones para registrarte.');
      return;
    }
    final telefono = _normalizarTelefonoVe(_phoneController.text);
    if (telefono == null) {
      _mostrarError('Ingresa un móvil de 10 dígitos, por ejemplo 4121234567');
      return;
    }
    final fechaNacimiento = DatosRegistro.interpretarFecha(
      dia: _diaNacimiento,
      mes: _mesNacimiento,
      anio: _anioNacimiento,
    );
    if (fechaNacimiento == null ||
        !DatosRegistro.tieneMayoriaDeEdad(fechaNacimiento)) {
      _mostrarError('Debes tener al menos 18 años para registrarte.');
      return;
    }

    setState(() => _guardando = true);
    try {
      await AuthService.instance.registrar(
        nombre: _nameController.text,
        email: _emailController.text,
        telefono: telefono,
        password: _passwordController.text,
        datos: DatosRegistro(
          fechaNacimiento: fechaNacimiento,
          direccion: _direccionController.text,
          cedulaIdentidad: _cedulaController.text,
          esMayorDeEdad: _esMayorDeEdad,
        ),
      );
      await CredentialStore.instance.guardar(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (error) {
      if (!mounted) return;
      _mostrarError(error.message);
    } catch (error) {
      if (!mounted) return;
      _mostrarError('No se pudo crear la cuenta: $error');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Crear Cuenta'),
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
                const SizedBox(height: 8),
                const Center(
                  child: RingoBrandHeader(
                    fontSize: 30,
                    showSubtitle: true,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  '¡Únete a RinGo! 🛵',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.blackPure,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Completa tus datos para empezar a viajar y enviar paquetes',
                  style: TextStyle(fontSize: 15, color: AppColors.mediumGray),
                ),
                const SizedBox(height: 28),
                const GoogleSignInButton(),
                const SizedBox(height: 18),
                const SeparadorAuth(texto: 'o completa tus datos'),
                const SizedBox(height: 18),

                // Campo Nombre Completo
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 50,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(50),
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]'),
                    ),
                  ],
                  style: _estiloCampo,
                  decoration: const InputDecoration(
                    labelText: 'Nombre Completo',
                    prefixIcon: Icon(Icons.person_outline),
                    counterText: '',
                  ),
                  validator: (value) {
                    final nombre = value?.trim() ?? '';
                    if (nombre.isEmpty) {
                      return 'Por favor ingresa tu nombre completo';
                    }
                    if (nombre.length > 50) {
                      return 'El nombre no puede superar 50 caracteres';
                    }
                    if (!_soloLetrasYEspacios.hasMatch(nombre)) {
                      return 'Solo se permiten letras y espacios';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                FormField<void>(
                  validator: (_) => DatosRegistro.validarFecha(
                    dia: _diaNacimiento,
                    mes: _mesNacimiento,
                    anio: _anioNacimiento,
                  ),
                  builder: (field) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Fecha de nacimiento',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mediumGray,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _desplegableFecha(
                                etiqueta: 'Día',
                                valor: _diaNacimiento,
                                entradas: [
                                  for (var dia = 1; dia <= 31; dia++)
                                    DropdownMenuItem(
                                      value: dia,
                                      child: Text('$dia'),
                                    ),
                                ],
                                onChanged: (dia) => _cambiarFecha(
                                  field,
                                  () => _diaNacimiento = dia,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: _desplegableFecha(
                                etiqueta: 'Mes',
                                valor: _mesNacimiento,
                                entradas: [
                                  for (var mes = 1; mes <= 12; mes++)
                                    DropdownMenuItem(
                                      value: mes,
                                      child: Text(DatosRegistro.meses[mes - 1]),
                                    ),
                                ],
                                seleccionado: [
                                  for (final mes in DatosRegistro.mesesCortos)
                                    Text(mes, overflow: TextOverflow.ellipsis),
                                ],
                                onChanged: (mes) => _cambiarFecha(
                                  field,
                                  () => _mesNacimiento = mes,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: _desplegableFecha(
                                etiqueta: 'Año',
                                valor: _anioNacimiento,
                                entradas: [
                                  for (final anio in _aniosNacimiento)
                                    DropdownMenuItem(
                                      value: anio,
                                      child: Text('$anio'),
                                    ),
                                ],
                                onChanged: (anio) => _cambiarFecha(
                                  field,
                                  () => _anioNacimiento = anio,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (field.hasError)
                          Padding(
                            padding: const EdgeInsets.only(left: 16, top: 6),
                            child: Text(
                              field.errorText!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _direccionController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 120,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(120),
                  ],
                  style: _estiloCampo,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
                    prefixIcon: Icon(Icons.home_outlined),
                    counterText: '',
                  ),
                  validator: DatosRegistro.validarDireccion,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _cedulaController,
                  keyboardType: TextInputType.number,
                  maxLength: 9,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  style: _estiloCampo,
                  decoration: const InputDecoration(
                    labelText: 'Cédula de identidad',
                    hintText: '12345678',
                    prefixIcon: Icon(Icons.badge_outlined),
                    counterText: '',
                  ),
                  validator: DatosRegistro.validarCedula,
                ),
                const SizedBox(height: 16),

                // Campo Correo Electrónico
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  maxLength: 80,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(80),
                  ],
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.blackPure),
                  decoration: const InputDecoration(
                    labelText: 'Correo Electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                    counterText: '',
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) {
                      return 'Por favor ingresa tu correo electrónico';
                    }
                    if (email.length > 80) {
                      return 'El correo no puede superar 80 caracteres';
                    }
                    if (!_emailValido.hasMatch(email)) {
                      return 'Ingresa un correo electrónico válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.blackPure),
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    hintText: '4121234567',
                    prefixIcon: Icon(Icons.phone_outlined),
                    prefixText: '+58 ',
                    prefixStyle: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.blackPure,
                    ),
                    counterText: '',
                  ),
                  validator: (value) {
                    if (_normalizarTelefonoVe(value ?? '') == null) {
                      return 'Ingresa un móvil de 10 dígitos, por ejemplo 4121234567';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Campo Contraseña
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  maxLength: 32,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(32),
                  ],
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.blackPure),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    counterText: '',
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
                    final password = value ?? '';
                    if (password.isEmpty) {
                      return 'Por favor ingresa una contraseña';
                    }
                    if (password.length < 6) {
                      return 'La contraseña debe tener al menos 6 caracteres';
                    }
                    if (password.length > 32) {
                      return 'La contraseña no puede superar 32 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                _casillaConfirmacion(
                  valor: _esMayorDeEdad,
                  onChanged: (valor) => setState(() => _esMayorDeEdad = valor),
                  texto: const Text(
                    'Confirmo que soy mayor de 18 años de edad',
                    style: _estiloCasilla,
                  ),
                ),
                _casillaConfirmacion(
                  valor: _aceptaTerminos,
                  onChanged: (valor) => setState(() => _aceptaTerminos = valor),
                  texto: Text.rich(
                    TextSpan(
                      style: _estiloCasilla,
                      children: [
                        const TextSpan(text: 'Al registrarte, aceptas nuestros '),
                        TextSpan(
                          text: 'Términos y Condiciones',
                          style: const TextStyle(
                            color: AppColors.blackPure,
                            fontWeight: FontWeight.w800,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primaryYellow,
                            decorationThickness: 2,
                          ),
                          recognizer: _termsRecognizer,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Botón Registrarse (Amarillo vibrante con texto negro)
                ElevatedButton(
                  onPressed: _guardando ? null : _registrarse,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryYellow,
                    foregroundColor: AppColors.blackPure,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _guardando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Text(
                          'Registrarme',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _cambiarFecha(FormFieldState<void> field, VoidCallback asignar) {
    setState(asignar);
    if (!field.hasError) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) field.validate();
    });
  }

  List<int> get _aniosNacimiento {
    final actual = DateTime.now().year;
    return [for (var anio = actual; anio >= actual - 100; anio--) anio];
  }

  Widget _casillaConfirmacion({
    required bool valor,
    required ValueChanged<bool> onChanged,
    required Widget texto,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: valor,
          activeColor: AppColors.blackPure,
          checkColor: AppColors.primaryYellow,
          onChanged: (value) => onChanged(value ?? false),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: texto,
          ),
        ),
      ],
    );
  }

  Widget _desplegableFecha({
    required String etiqueta,
    required int? valor,
    required List<DropdownMenuItem<int>> entradas,
    List<Widget>? seleccionado,
    required ValueChanged<int?> onChanged,
  }) {
    return InputDecorator(
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: valor,
          hint: Text(
            etiqueta,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.mediumGray,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.blackPure),
          dropdownColor: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          menuMaxHeight: 280,
          style: _estiloCampo.copyWith(fontSize: 15),
          selectedItemBuilder: seleccionado == null
              ? null
              : (context) => [
                    for (final item in seleccionado)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: DefaultTextStyle.merge(
                          style: _estiloCampo.copyWith(fontSize: 15),
                          child: item,
                        ),
                      ),
                  ],
          items: entradas,
          onChanged: onChanged,
        ),
      ),
    );
  }
}