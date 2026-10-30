import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:url_launcher/url_launcher.dart';

import 'ciudad.dart';
import 'services/chat_service.dart';
import 'services/local_notification_service.dart';
import 'services/viaje_service.dart';
import 'widgets/chat_sheet.dart';
import 'widgets/monto_dual.dart';
import 'theme/app_theme.dart';

class SeguimientoScreen extends StatefulWidget {
  const SeguimientoScreen({super.key, required this.viajeId});

  final String viajeId;

  @override
  State<SeguimientoScreen> createState() => _SeguimientoScreenState();
}

class _SeguimientoScreenState extends State<SeguimientoScreen> {
  bool _accion = false;
  bool _expirando = false;

  // Avisos (notificación + sonido) por cambios del viaje y mensajes nuevos.
  StreamSubscription<ViajeActivo?>? _avisosViaje;
  StreamSubscription<List<MensajeViaje>>? _avisosChat;
  String? _estadoPrevio;
  Set<String>? _mensajesVistos;
  ViajeActivo? _ultimoViaje;

  @override
  void initState() {
    super.initState();
    _avisosViaje = ViajeService.instance
        .observar(widget.viajeId)
        .listen(_avisarCambioDeViaje, onError: (Object _) {});
    _avisosChat = ChatService.instance
        .observar(widget.viajeId)
        .listen(_avisarMensajes, onError: (Object _) {});
  }

  @override
  void dispose() {
    _avisosViaje?.cancel();
    _avisosChat?.cancel();
    super.dispose();
  }

  /// El primer snapshot solo fija el estado previo; después avisa de cada cambio.
  void _avisarCambioDeViaje(ViajeActivo? viaje) {
    if (viaje == null) return;
    _ultimoViaje = viaje;
    final previo = _estadoPrevio;
    _estadoPrevio = viaje.estado;
    if (previo == null || previo == viaje.estado) return;

    final avisos = LocalNotificationService.instance;
    switch (viaje.estado) {
      case 'aceptado':
        final nombre = viaje.conductorNombre;
        unawaited(avisos.notificar(
          EventoNotificacion.conductorAsignado,
          viajeId: viaje.id,
          titulo: '¡Conductor asignado!',
          cuerpo: nombre == null ? 'Tu conductor va en camino.' : '$nombre va en camino.',
        ));
        break;
      case 'llego':
        unawaited(avisos.notificar(
          EventoNotificacion.conductorLlego,
          viajeId: viaje.id,
          titulo: 'Tu conductor llegó',
          cuerpo: 'Tu conductor ya está en el punto de encuentro.',
        ));
        break;
      case 'finalizado':
        final bolivares = viaje.montoBolivares;
        final monto = '\$${viaje.dolares.toStringAsFixed(2)}'
            '${bolivares == null ? '' : ' (Bs. ${bolivares.toStringAsFixed(2)})'}';
        unawaited(avisos.notificar(
          EventoNotificacion.viajeFinalizado,
          viajeId: viaje.id,
          titulo: 'Viaje finalizado',
          cuerpo: 'Total: $monto. ¡Gracias por viajar con RinGo!',
        ));
        break;
    }
  }

  /// El primer snapshot solo registra los mensajes existentes; los siguientes
  /// que no son míos disparan el aviso.
  void _avisarMensajes(List<MensajeViaje> mensajes) {
    final vistos = _mensajesVistos;
    if (vistos == null) {
      _mensajesVistos = {for (final m in mensajes) m.id};
      return;
    }
    for (final mensaje in mensajes) {
      if (!vistos.add(mensaje.id) || mensaje.esMio) continue;
      unawaited(LocalNotificationService.instance.notificar(
        EventoNotificacion.mensaje,
        viajeId: widget.viajeId,
        titulo: _ultimoViaje?.conductorNombre ?? 'Tu conductor',
        cuerpo: mensaje.texto,
        mensajeId: mensaje.id,
      ));
    }
  }

  Future<void> _cancelar() async {
    setState(() => _accion = true);
    try {
      await ViajeService.instance.cancelar(widget.viajeId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cancelar el viaje.')),
      );
    } finally {
      if (mounted) setState(() => _accion = false);
    }
  }

  Future<void> _expirarSiToca(ViajeActivo viaje) async {
    final creado = viaje.creadoEn;
    if (_expirando || viaje.estado != 'pendiente' || creado == null) return;
    if (DateTime.now().difference(creado) <= ViajeService.vigencia) return;
    _expirando = true;
    try {
      await ViajeService.instance.expirar(viaje.id);
    } catch (_) {
      _expirando = false;
    }
  }

  Future<void> _llamar(String? telefono) async {
    final numero = telefono?.trim() ?? '';
    if (numero.isEmpty) return;
    await launchUrl(Uri(scheme: 'tel', path: numero));
  }

  Future<void> _abrirChat(ViajeActivo viaje) {
    return ChatSheet.mostrar(
      context,
      viajeId: viaje.id,
      titulo: viaje.conductorNombre ?? 'Conductor',
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ViajeActivo?>(
      stream: ViajeService.instance.observar(widget.viajeId),
      builder: (context, snapshot) {
        final viaje = snapshot.data;
        if (viaje != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _expirarSiToca(viaje));
        }
        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            title: const Text('Tu viaje'),
          ),
          body: viaje == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    _Mapa(viaje: viaje),
                    Positioned.fill(
                      child: _Panel(
                        viaje: viaje,
                        ocupado: _accion,
                        onCancelar: viaje.puedeCancelar ? _cancelar : null,
                        onLlamar: viaje.conductorTelefono == null
                            ? null
                            : () => _llamar(viaje.conductorTelefono),
                        onChat: viaje.conductorId == null ? null : () => _abrirChat(viaje),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _Mapa extends StatefulWidget {
  const _Mapa({required this.viaje});

  final ViajeActivo viaje;

  @override
  State<_Mapa> createState() => _MapaState();
}

class _MapaState extends State<_Mapa> {
  gmaps.GoogleMapController? _mapa;
  bool _seguir = true;
  bool _movimientoPropio = false;
  String? _ultimaPosicion;

  @override
  void didUpdateWidget(covariant _Mapa oldWidget) {
    super.didUpdateWidget(oldWidget);
    _acercarConductor();
  }

  List<gmaps.LatLng> _trazado() {
    final viaje = widget.viaje;
    final puntos = <gmaps.LatLng>[
      for (final punto in viaje.recorrido)
        gmaps.LatLng(punto.latitude, punto.longitude),
    ];
    final actual = viaje.ubicacionConductor;
    if (actual == null) return puntos;
    final marca = gmaps.LatLng(actual.latitude, actual.longitude);
    if (puntos.isEmpty ||
        puntos.last.latitude != marca.latitude ||
        puntos.last.longitude != marca.longitude) {
      puntos.add(marca);
    }
    return puntos;
  }

  void _acercarConductor() {
    final actual = widget.viaje.ubicacionConductor;
    final mapa = _mapa;
    if (!_seguir || actual == null || mapa == null) return;
    final firma = '${actual.latitude.toStringAsFixed(5)},${actual.longitude.toStringAsFixed(5)}';
    if (firma == _ultimaPosicion) return;
    _ultimaPosicion = firma;
    _movimientoPropio = true;
    mapa.animateCamera(
      gmaps.CameraUpdate.newLatLng(gmaps.LatLng(actual.latitude, actual.longitude)),
    );
  }

  void _volverASeguir() {
    setState(() => _seguir = true);
    _ultimaPosicion = null;
    _acercarConductor();
  }

  @override
  Widget build(BuildContext context) {
    final viaje = widget.viaje;
    final conductor = viaje.ubicacionConductor;
    final trazado = _trazado();
    final centro = conductor ?? viaje.origen;
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(
          child: ColoredBox(color: AppColors.lightBackground),
        ),
        Positioned.fill(
          child: gmaps.GoogleMap(
          initialCameraPosition: gmaps.CameraPosition(
            target: gmaps.LatLng(centro.latitude, centro.longitude),
            zoom: CiudadOperacion.zoomInicial,
          ),
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          onMapCreated: (controller) {
            _mapa = controller;
            _acercarConductor();
          },
          onCameraMoveStarted: () {
            if (_movimientoPropio) return;
            if (_seguir) setState(() => _seguir = false);
          },
          onCameraIdle: () => _movimientoPropio = false,
          polylines: {
            if (trazado.length >= 2)
              gmaps.Polyline(
                polylineId: const gmaps.PolylineId('recorrido'),
                points: trazado,
                color: AppColors.lightBlueRoute,
                width: 6,
                jointType: gmaps.JointType.round,
                startCap: gmaps.Cap.roundCap,
                endCap: gmaps.Cap.roundCap,
              ),
          },
          markers: {
            gmaps.Marker(
              markerId: const gmaps.MarkerId('origen'),
              position: gmaps.LatLng(viaje.origen.latitude, viaje.origen.longitude),
              icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueYellow),
            ),
            gmaps.Marker(
              markerId: const gmaps.MarkerId('destino'),
              position: gmaps.LatLng(viaje.destino.latitude, viaje.destino.longitude),
              icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueRed),
            ),
            if (conductor != null)
              gmaps.Marker(
                markerId: const gmaps.MarkerId('conductor'),
                position: gmaps.LatLng(conductor.latitude, conductor.longitude),
                rotation: viaje.rumboConductor ?? 0,
                flat: true,
                anchor: const Offset(0.5, 0.5),
                icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueAzure),
                infoWindow: gmaps.InfoWindow(title: viaje.conductorNombre ?? 'Conductor'),
              ),
          },
          ),
        ),
        // Arriba: el panel deslizable cubre la parte baja del mapa.
        Positioned(
          right: 12,
          top: 12,
          child: FloatingActionButton.small(
            heroTag: 'seguir-conductor',
            backgroundColor: _seguir ? AppColors.primaryYellow : AppColors.white,
            foregroundColor: AppColors.blackPure,
            onPressed: _volverASeguir,
            child: const Icon(Icons.navigation_rounded),
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.viaje,
    required this.ocupado,
    required this.onCancelar,
    required this.onLlamar,
    required this.onChat,
  });

  final ViajeActivo viaje;
  final bool ocupado;
  final VoidCallback? onCancelar;
  final VoidCallback? onLlamar;
  final VoidCallback? onChat;

  /// Resumen del viaje como hoja deslizable sobre el mapa (igual que en
  /// ringo_driver): se arrastra hacia abajo hasta dejar solo el handle y el
  /// título, y hacia arriba para ver todo el detalle.
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.3,
      minChildSize: 0.15,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Material(
          color: AppColors.white,
          elevation: 8,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.borderGray,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text(
              viaje.tituloEstado,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              _tipo(viaje.tipoServicio),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            MontoDual(
              usd: viaje.dolares,
              bolivaresFijos: viaje.montoBolivares,
              tasaViva: false,
              alineacion: CrossAxisAlignment.start,
            ),
            const SizedBox(height: 4),
            Text(
              viaje.esEfectivo ? 'Pago en efectivo al conductor' : 'Pago móvil ya confirmado',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (viaje.conductorNombre != null) ...[
              const SizedBox(height: 6),
              Text(viaje.conductorNombre!),
              if (viaje.vehiculoResumen != null) Text(viaje.vehiculoResumen!),
            ],
            const SizedBox(height: 8),
            Text('Origen: ${_lugar(viaje.origenDireccion, viaje.origen)}'),
            Text('Destino: ${_lugar(viaje.destinoDireccion, viaje.destino)}'),
            if (viaje.estado == 'pendiente')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Si en 5 minutos nadie acepta, la solicitud se cierra.',
                  style: TextStyle(color: AppColors.mediumGray),
                ),
              ),
            if (onChat != null || onLlamar != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (onChat != null)
                    Expanded(
                      child: _BotonAccionViaje(
                        icono: Icons.chat_bubble_rounded,
                        texto: 'Chat',
                        fondo: AppColors.primaryYellow,
                        tinta: AppColors.blackPure,
                        onPressed: onChat,
                      ),
                    ),
                  if (onChat != null && onLlamar != null) const SizedBox(width: 12),
                  if (onLlamar != null)
                    Expanded(
                      child: _BotonAccionViaje(
                        icono: Icons.call_rounded,
                        texto: 'Llamar',
                        fondo: AppColors.blackPure,
                        tinta: AppColors.white,
                        onPressed: onLlamar,
                      ),
                    ),
                ],
              ),
            ],
            if (onCancelar != null) ...[
              const SizedBox(height: 12),
              _BotonCancelarViaje(onPressed: ocupado ? null : onCancelar),
            ],
            ],
          ),
        );
      },
    );
  }

  String _tipo(String tipo) {
    switch (tipo) {
      case 'delivery':
        return 'Delivery';
      case 'mototaxi':
        return 'Moto Taxi';
      case 'taxi':
        return 'Taxi';
      default:
        return tipo;
    }
  }

  String _lugar(String direccion, dynamic punto) {
    if (direccion.trim().isNotEmpty) return direccion.trim();
    return '${punto.latitude.toStringAsFixed(5)}, ${punto.longitude.toStringAsFixed(5)}';
  }
}

class _BotonAccionViaje extends StatelessWidget {
  const _BotonAccionViaje({
    required this.icono,
    required this.texto,
    required this.fondo,
    required this.tinta,
    required this.onPressed,
  });

  final IconData icono;
  final String texto;
  final Color fondo;
  final Color tinta;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackPure.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icono, size: 20, color: tinta),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    texto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tinta,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BotonCancelarViaje extends StatelessWidget {
  const _BotonCancelarViaje({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    const alerta = Color(0xFFFF3B30);
    final activo = onPressed != null;
    return Opacity(
      opacity: activo ? 1 : 0.45,
      child: Material(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: alerta.withValues(alpha: 0.45)),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.close_rounded, size: 18, color: alerta),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Cancelar viaje',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: alerta,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
