import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme/app_theme.dart';
import 'services/cupon_service.dart';
import 'services/device_id_service.dart';
import 'services/exchange_rate_service.dart';
import 'services/viaje_service.dart';
import 'seguimiento_screen.dart';
import 'tarifas.dart';
import 'widgets/campo_lugar.dart';
import 'widgets/monto_dual.dart';

class PagoScreen extends StatefulWidget {
  final String tipoServicio;
  final LatLng? origen;
  final LatLng? destino;
  final double distanciaKm;
  final double montoUsd;
  final double tarifaPorKm;
  final String origenDireccion;
  final String destinoDireccion;

  const PagoScreen({
    super.key,
    required this.tipoServicio,
    required this.origen,
    required this.destino,
    required this.distanciaKm,
    required this.montoUsd,
    required this.tarifaPorKm,
    this.origenDireccion = '',
    this.destinoDireccion = '',
  });

  @override
  State<PagoScreen> createState() => _PagoScreenState();
}

class _PagoScreenState extends State<PagoScreen> {
  static const String _bancoNombre = 'Venezolano de Crédito';
  static const String _bancoCodigo = '0104';
  static const String _cedula = '27700797';
  static const String _telefono = '0412-8584111';

  final TextEditingController _refController = TextEditingController();
  final TextEditingController _origenController = TextEditingController();
  final TextEditingController _destinoController = TextEditingController();
  final TextEditingController _cuponController = TextEditingController();
  bool _isVerifying = false;
  bool _aplicandoCupon = false;
  bool _cuponAplicado = false;
  bool _datosCopiados = false;
  bool _efectivo = false;

  String _pistaReferencia(String direccion, String ejemplo) {
    final texto = direccion.trim();
    if (texto.isEmpty) return ejemplo;
    return texto;
  }

  String _direccionGuardada(TextEditingController controller, String original) {
    final nota = controller.text.trim();
    final base = original.trim() == puntoSeleccionadoEnMapa ? '' : original.trim();
    if (nota.isEmpty) return base;
    if (base.isEmpty || base == nota) return nota;
    return '$base · $nota';
  }

  @override
  void dispose() {
    _refController.dispose();
    _origenController.dispose();
    _destinoController.dispose();
    _cuponController.dispose();
    super.dispose();
  }

  /// `delivery` y `mototaxi` aceptan PRIMERVIAJE. Taxi no.
  String? get _servicioCupon {
    final compacto = widget.tipoServicio.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    if (compacto == 'delivery') return 'delivery';
    if (compacto == 'mototaxi' || compacto == 'moto') return 'mototaxi';
    return null;
  }

  // Nombre legible del servicio para mostrar en UI
  String get _nombreServicioLegible {
    final servicio = widget.tipoServicio.toLowerCase().replaceAll(' ', '');
    switch (servicio) {
      case 'delivery':
        return 'DELIVERY / PICKUP';
      case 'mototaxi':
        return 'MOTO TAXI';
      case 'taxi':
        return 'TAXI (CARRO)';
      default:
        return widget.tipoServicio.toUpperCase();
    }
  }

  double get _montoEstimado => _cuponAplicado ? 0 : widget.montoUsd;

  /// Formato listo para pegar en la app del banco (código, teléfono, cédula, monto en Bs).
  String _datosPagoMovil(double bolivares) {
    final telefonoDigitos = _telefono.replaceAll(RegExp(r'[^0-9]'), '');
    return '$_bancoCodigo\n$telefonoDigitos\n$_cedula\n${bolivares.toStringAsFixed(2)}';
  }

  Future<void> _copiarDatosPagoMovil() async {
    final tasa = await ExchangeRateService.instance.observar().first;
    final vesPorDolar = tasa?.vesRate;
    if (vesPorDolar == null || vesPorDolar <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay tasa en bolívares para copiar el monto.'),
          backgroundColor: AppColors.blackPure,
        ),
      );
      return;
    }
    final bolivares = Tarifas.bolivares(_montoEstimado, vesPorDolar);
    await Clipboard.setData(ClipboardData(text: _datosPagoMovil(bolivares)));
    if (!mounted) return;
    setState(() => _datosCopiados = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Datos copiados. Pégalos en tu app del banco.'),
        backgroundColor: AppColors.blackPure,
      ),
    );
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _datosCopiados = false);
    });
  }

  Future<void> _verificarPago() async {
    final ref = _refController.text.trim();
    if (ref.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa la referencia de pago'),
          backgroundColor: AppColors.blackPure,
        ),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      // Consulta en la colección 'pagos' cargada por MacroDroid o bot bancario
      final query = await FirebaseFirestore.instance
          .collection('pagos')
          .where('referencia', isEqualTo: ref)
          .get();

      if (query.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Referencia no encontrada aún. Verifica e intenta de nuevo.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final pagoDoc = query.docs.first;
      final pagoData = pagoDoc.data();
      if (pagoData['usado'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Esta referencia ya fue utilizada.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      if (!mounted) return;
      if (widget.origen == null || widget.destino == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Falta origen o destino. Vuelve al mapa e intenta de nuevo.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final viajeId = await ViajeService.instance.crearSolicitud(
        tipoServicio: widget.tipoServicio,
        origen: widget.origen!,
        destino: widget.destino!,
        origenDireccion: _direccionGuardada(_origenController, widget.origenDireccion),
        destinoDireccion: _direccionGuardada(_destinoController, widget.destinoDireccion),
        monto: _montoEstimado,
        distanciaKm: widget.distanciaKm,
        tarifaPorKm: widget.tarifaPorKm,
        referenciaPago: ref,
        metodoPago: 'digital',
      );

      await pagoDoc.reference.update({
        'usado': true,
        'viajeId': viajeId,
      });

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => SeguimientoScreen(viajeId: viajeId)),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      final texto = e.toString();
      final mensaje = texto.contains('permission-denied')
          ? 'Firestore bloqueó la consulta. En Firebase Console → Firestore → Rules, publica las reglas de ringo_app/firestore.rules y pulsa Publish.'
          : 'Error al consultar pago: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _aplicarCupon() async {
    final codigo = _cuponController.text.trim().toUpperCase();
    if (codigo != CuponService.codigoPrimerViaje) {
      _aviso('Escribe el código PRIMERVIAJE.');
      return;
    }
    final servicio = _servicioCupon;
    if (servicio == null) {
      _aviso('El cupón Primer Viaje Gratis solo aplica a delivery y mototaxi.');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _aviso('Inicia sesión para usar el cupón.');
      return;
    }

    setState(() => _aplicandoCupon = true);
    try {
      final deviceId = await DeviceIdService.instance.obtener();
      await CuponService.instance.reclamarPrimerViaje(
        userId: user.uid,
        deviceId: deviceId,
        serviceType: servicio,
      );
      if (!mounted) return;
      setState(() => _cuponAplicado = true);
      _aviso('Cupón aplicado. Este viaje queda gratis.');
    } on CuponException catch (error) {
      _aviso(error.message);
    } on DeviceIdException catch (error) {
      _aviso(error.message);
    } catch (error) {
      _aviso('No se pudo aplicar el cupón. $error');
    } finally {
      if (mounted) setState(() => _aplicandoCupon = false);
    }
  }

  Future<void> _confirmarCupon() async {
    if (widget.origen == null || widget.destino == null) {
      _aviso('Falta origen o destino. Vuelve al mapa e intenta de nuevo.');
      return;
    }
    setState(() => _isVerifying = true);
    try {
      final viajeId = await ViajeService.instance.crearSolicitud(
        tipoServicio: widget.tipoServicio,
        origen: widget.origen!,
        destino: widget.destino!,
        origenDireccion: _direccionGuardada(_origenController, widget.origenDireccion),
        destinoDireccion: _direccionGuardada(_destinoController, widget.destinoDireccion),
        monto: 0,
        montoOriginalUsd: widget.montoUsd,
        distanciaKm: widget.distanciaKm,
        tarifaPorKm: widget.tarifaPorKm,
        metodoPago: 'cupon',
        referenciaPago: CuponService.codigoPrimerViaje,
        cupon: CuponService.codigoPrimerViaje,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => SeguimientoScreen(viajeId: viajeId)),
        (route) => route.isFirst,
      );
    } catch (e) {
      _aviso('No se pudo solicitar el viaje. $e');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _aviso(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: AppColors.blackPure),
    );
  }

  Future<void> _solicitarEfectivo() async {
    if (widget.origen == null || widget.destino == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Falta origen o destino. Vuelve al mapa e intenta de nuevo.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    setState(() => _isVerifying = true);
    try {
      final viajeId = await ViajeService.instance.crearSolicitud(
        tipoServicio: widget.tipoServicio,
        origen: widget.origen!,
        destino: widget.destino!,
        origenDireccion: _direccionGuardada(_origenController, widget.origenDireccion),
        destinoDireccion: _direccionGuardada(_destinoController, widget.destinoDireccion),
        monto: _montoEstimado,
        distanciaKm: widget.distanciaKm,
        tarifaPorKm: widget.tarifaPorKm,
        metodoPago: 'efectivo',
        referenciaPago: '',
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => SeguimientoScreen(viajeId: viajeId)),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo solicitar el viaje. $e')),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Detalle y Pago'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Resumen del Servicio (Tarjeta Blanca con acento)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Modalidad:',
                          style: TextStyle(color: AppColors.mediumGray, fontWeight: FontWeight.w600),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryYellow.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _nombreServicioLegible,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: AppColors.blackPure,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Recorrido: ${Tarifas.formatearKm(widget.distanciaKm)}',
                      style: const TextStyle(color: AppColors.mediumGray, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const Divider(height: 24, color: AppColors.borderGray),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total a pagar:',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.blackPure),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (_cuponAplicado)
                              MontoDual(
                                usd: widget.montoUsd,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.mediumGray,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            MontoDual(
                              usd: _montoEstimado,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: AppColors.blackPure,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              _SeccionCupon(
                controller: _cuponController,
                aplicado: _cuponAplicado,
                cargando: _aplicandoCupon,
                habilitado: _servicioCupon != null,
                onAplicar: _aplicarCupon,
              ),

              if (!_cuponAplicado) ...[
              const SizedBox(height: 20),

              const Text(
                '¿Cómo vas a pagar?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _OpcionPago(
                      titulo: 'Pago móvil',
                      icono: Icons.phone_android_rounded,
                      activo: !_efectivo,
                      onTap: _isVerifying ? null : () => setState(() => _efectivo = false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _OpcionPago(
                      titulo: 'Efectivo',
                      icono: Icons.payments_outlined,
                      activo: _efectivo,
                      onTap: _isVerifying ? null : () => setState(() => _efectivo = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _efectivo
                    ? 'Pagarás el total al conductor al terminar. La plataforma retiene el 40%.'
                    : 'Transfiere el total y escribe la referencia para confirmar el viaje.',
                style: const TextStyle(color: AppColors.mediumGray, height: 1.35),
              ),

              const SizedBox(height: 20),

              if (!_efectivo) ...[
              Container(
                padding: const EdgeInsets.all(22.0),
                decoration: BoxDecoration(
                  color: AppColors.blackPure,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryYellow,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.payment_rounded, color: AppColors.blackPure, size: 16),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Datos para Pago Móvil',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('• Banco: $_bancoNombre ($_bancoCodigo)', style: TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    const Text('• Cédula: V-$_cedula', style: TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    const Text('• Teléfono: $_telefono', style: TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _copiarDatosPagoMovil,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryYellow,
                          foregroundColor: AppColors.blackPure,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        icon: Icon(
                          _datosCopiados ? Icons.check_rounded : Icons.copy_rounded,
                          size: 20,
                        ),
                        label: Text(
                          _datosCopiados ? '¡Copiado!' : 'Copiar datos de pago',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ],
              ],

              const SizedBox(height: 24),

              TextFormField(
                controller: _origenController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Referencia del origen',
                  hintText: _pistaReferencia(
                    widget.origenDireccion,
                    'Ej. Plaza Bolívar, puerta azul',
                  ),
                  prefixIcon: const Icon(Icons.trip_origin),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _destinoController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Referencia del destino',
                  hintText: _pistaReferencia(
                    widget.destinoDireccion,
                    'Ej. Terminal, entrada principal',
                  ),
                  prefixIcon: const Icon(Icons.place_outlined),
                ),
              ),
              if (!_cuponAplicado && !_efectivo) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _refController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.blackPure),
                  decoration: const InputDecoration(
                    labelText: 'Número de Referencia',
                    hintText: 'Ej. 000906940279',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryYellow,
                    foregroundColor: AppColors.blackPure,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isVerifying
                      ? null
                      : (_cuponAplicado
                          ? _confirmarCupon
                          : (_efectivo ? _solicitarEfectivo : _verificarPago)),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: AppColors.blackPure,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _cuponAplicado
                                  ? 'Confirmar viaje gratis'
                                  : (_efectivo ? 'Solicitar y pagar en efectivo' : 'Verificar y Procesar Pago'),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _cuponAplicado
                                  ? Icons.card_giftcard_rounded
                                  : (_efectivo ? Icons.payments_outlined : Icons.check_rounded),
                              size: 20,
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeccionCupon extends StatelessWidget {
  const _SeccionCupon({
    required this.controller,
    required this.aplicado,
    required this.cargando,
    required this.habilitado,
    required this.onAplicar,
  });

  final TextEditingController controller;
  final bool aplicado;
  final bool cargando;
  final bool habilitado;
  final VoidCallback onAplicar;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: aplicado ? AppColors.primaryYellow : AppColors.borderGray,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cupón Primer Viaje Gratis',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            habilitado
                ? 'PRIMERVIAJE este cupon deja en 0\$ el costo de este servicio. cupon valido para un solo uso'
                : 'Este cupón solo aplica a delivery y mototaxi.',
            style: const TextStyle(color: AppColors.mediumGray, height: 1.35),
          ),
          if (habilitado && !aplicado) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              enabled: !cargando,
              decoration: const InputDecoration(
                labelText: 'Código',
                hintText: 'PRIMERVIAJE',
                prefixIcon: Icon(Icons.local_offer_outlined),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: cargando ? null : onAplicar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blackPure,
                  foregroundColor: AppColors.primaryYellow,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: cargando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primaryYellow),
                      )
                    : const Text('Aplicar cupón', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
          if (aplicado) ...[
            const SizedBox(height: 10),
            const Text(
              'PRIMERVIAJE aplicado. El total de este viaje es 0.',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ],
      ),
    );
  }
}

class _OpcionPago extends StatelessWidget {
  const _OpcionPago({
    required this.titulo,
    required this.icono,
    required this.activo,
    required this.onTap,
  });

  final String titulo;
  final IconData icono;
  final bool activo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: activo ? AppColors.primaryYellow : AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: activo ? AppColors.primaryYellow : AppColors.borderGray),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: 18, color: AppColors.blackPure),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  titulo,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}