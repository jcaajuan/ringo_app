import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' hide Path;
import 'theme/app_theme.dart';
import 'pago_screen.dart';
import 'ciudad.dart';
import 'models/zona_operativa.dart';
import 'services/conductores_service.dart';
import 'services/tarifas_service.dart';
import 'services/zonas_service.dart';
import 'tarifas.dart';
import 'widgets/campo_lugar.dart';
import 'widgets/monto_dual.dart';
import 'services/places_service.dart';

class LocationSelectionScreen extends StatefulWidget {
  final String tipoServicio; // 'delivery', 'mototaxi' o 'taxi'

  const LocationSelectionScreen({
    super.key,
    required this.tipoServicio,
  });

  @override
  State<LocationSelectionScreen> createState() => _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  final LatLng _initialPosition = CiudadOperacion.centro;

  LatLng? _originPoint;
  LatLng? _destinationPoint;
  RecorridoCalculado? _recorrido;
  bool _calculandoRuta = false;
  int _calculoId = 0;
  double _usdPorKm = Tarifas.usdPorKm;
  StreamSubscription<List<TarifaServicio>>? _tarifas;
  StreamSubscription<List<ZonaOperativa>>? _zonasSub;
  List<ZonaOperativa>? _zonas;
  bool _errorZonas = false;
  StreamSubscription<EstadoPresencia>? _conductoresSub;
  bool? _hayConductor;
  bool _errorConductores = false;
  bool _reintentandoConductores = false;

  /// `mototaxi`, `taxi` o `delivery`, aunque la pantalla reciba "Moto Taxi" o "carro".
  String get _servicio => ConductoresService.servicioParaSolicitud(widget.tipoServicio);

  bool _isSelectingOrigin = true;
  gmaps.BitmapDescriptor? _iconoOrigen;
  gmaps.BitmapDescriptor? _iconoDestino;
  gmaps.GoogleMapController? _mapa;
  final _campoOrigen = GlobalKey<CampoLugarState>();
  final _campoDestino = GlobalKey<CampoLugarState>();
  String _origenDireccion = '';
  String _destinoDireccion = '';
  bool _ubicando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepararIconos());
    _tarifas = TarifasService.instance.observar().listen((lista) {
      if (!mounted) return;
      setState(() => _usdPorKm = TarifaServicio.de(lista, _servicio));
    });
    _zonasSub = ZonasService.instance.observarActivas().listen(
      (lista) {
        if (!mounted) return;
        setState(() {
          _zonas = lista;
          _errorZonas = false;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _errorZonas = true);
      },
    );
    _escucharConductores();
  }

  void _escucharConductores() {
    _conductoresSub?.cancel();
    debugPrint('presencia: LocationSelectionScreen escucha servicio="$_servicio"');
    _conductoresSub = ConductoresService.instance.hayAlgunoEnLinea(_servicio).listen(
      (estado) {
        if (!mounted) return;
        debugPrint(
          'presencia: servicio="$_servicio" '
          'hayConductor=${estado.hayAlguno} error=${estado.codigoError}',
        );
        setState(() {
          _hayConductor = estado.hayAlguno;
          _errorConductores = estado.fallo;
          _reintentandoConductores = estado.reintentando;
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        ConductoresService.registrarFalloConsulta(error, stackTrace);
        if (!mounted) return;
        setState(() {
          _hayConductor = false;
          _errorConductores = true;
          _reintentandoConductores = false;
        });
      },
    );
  }

  void _reintentarConductores() {
    setState(() => _reintentandoConductores = true);
    _escucharConductores();
  }

  @override
  void dispose() {
    _tarifas?.cancel();
    _zonasSub?.cancel();
    _conductoresSub?.cancel();
    _mapa?.dispose();
    super.dispose();
  }

  bool _dentroDeCobertura(LatLng punto) {
    final zonas = _zonas;
    if (zonas == null) return false;
    return ZonaOperativa.cubreAlguna(zonas, punto);
  }

  double get _monto => Tarifas.montoUsd(_recorrido!.distanciaKm, usdPorKm: _usdPorKm);

  Future<void> _prepararIconos() async {
    if (!mounted) return;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final origen = await _dibujarMarcador(
      ratio: ratio,
      size: const Size(40, 40),
      draw: _dibujarOrigen,
    );
    final destino = await _dibujarMarcador(
      ratio: ratio,
      size: const Size(44, 50),
      draw: _dibujarDestino,
    );
    if (!mounted) return;
    setState(() {
      _iconoOrigen = origen;
      _iconoDestino = destino;
    });
  }

  void _onMapTapped(gmaps.LatLng position) {
    FocusScope.of(context).unfocus();
    final punto = LatLng(position.latitude, position.longitude);
    const etiqueta = puntoSeleccionadoEnMapa;
    final fijarOrigen = _isSelectingOrigin;
    setState(() {
      if (fijarOrigen) {
        _originPoint = punto;
        _origenDireccion = etiqueta;
        _isSelectingOrigin = false;
      } else {
        _destinationPoint = punto;
        _destinoDireccion = etiqueta;
      }
    });
    final campo = fijarOrigen ? _campoOrigen : _campoDestino;
    campo.currentState?.mostrar(etiqueta);
    _centrar(punto);
    _recalcularRecorrido();
  }

  void _aviso(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: AppColors.blackPure),
    );
  }

  LocationSettings _ajustesUbicacion({bool forzarGestorAndroid = false}) {
    const espera = Duration(seconds: 10);
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        forceLocationManager: forzarGestorAndroid,
        intervalDuration: const Duration(seconds: 1),
        timeLimit: espera,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: espera,
    );
  }

  Future<bool> _asegurarPermisoUbicacion() async {
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.unableToDetermine) {
      permiso = await Geolocator.requestPermission();
    }
    if (!mounted) return false;
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.unableToDetermine) {
      _aviso('Necesitamos permiso de ubicación para marcar el origen.');
      return false;
    }
    if (permiso == LocationPermission.deniedForever) {
      _aviso('El permiso de ubicación está bloqueado. Actívalo en los ajustes del teléfono.');
      return false;
    }
    return permiso == LocationPermission.always ||
        permiso == LocationPermission.whileInUse;
  }

  bool _errorDePermisoOGps(Object error) {
    return error is LocationServiceDisabledException ||
        error is PermissionDefinitionsNotFoundException ||
        error is PermissionDeniedException;
  }

  Future<Position> _obtenerPosicion() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: _ajustesUbicacion(),
      );
    } catch (error, stack) {
      debugPrint('Geolocator.getCurrentPosition falló: $error');
      debugPrint('$stack');
      if (_errorDePermisoOGps(error)) rethrow;
    }

    try {
      final ultima = await Geolocator.getLastKnownPosition();
      if (ultima != null) return ultima;
      debugPrint('Geolocator.getLastKnownPosition no tenía una posición guardada.');
    } catch (error, stack) {
      debugPrint('Geolocator.getLastKnownPosition falló: $error');
      debugPrint('$stack');
      if (_errorDePermisoOGps(error)) rethrow;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: _ajustesUbicacion(forzarGestorAndroid: true),
        );
      } catch (error, stack) {
        debugPrint('Geolocator.getCurrentPosition (LocationManager) falló: $error');
        debugPrint('$stack');
        if (_errorDePermisoOGps(error)) rethrow;
      }
    }

    throw StateError('No hay una posición disponible.');
  }

  Future<void> _usarUbicacionActual() async {
    if (_ubicando) return;
    setState(() => _ubicando = true);
    try {
      final gpsActivo = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!gpsActivo) {
        _aviso('Activa el GPS del teléfono para usar tu ubicación.');
        return;
      }
      if (!await _asegurarPermisoUbicacion()) return;
      if (!mounted) return;

      final posicion = await _obtenerPosicion();
      if (!mounted) return;
      final punto = LatLng(posicion.latitude, posicion.longitude);
      setState(() {
        _originPoint = punto;
        _origenDireccion = tuUbicacionActual;
        if (_destinationPoint == null) _isSelectingOrigin = false;
      });
      _campoOrigen.currentState?.mostrar(tuUbicacionActual);
      _centrar(punto);
      _recalcularRecorrido();
    } on LocationServiceDisabledException catch (error, stack) {
      debugPrint('Ubicación: el GPS está apagado. $error');
      debugPrint('$stack');
      if (!mounted) return;
      _aviso('Activa el GPS del teléfono para usar tu ubicación.');
    } on PermissionDefinitionsNotFoundException catch (error, stack) {
      debugPrint('Ubicación: faltan ACCESS_FINE_LOCATION o ACCESS_COARSE_LOCATION. $error');
      debugPrint('$stack');
      if (!mounted) return;
      _aviso('La app no tiene permiso de ubicación. Vuelve a instalarla.');
    } on PermissionDeniedException catch (error, stack) {
      debugPrint('Ubicación: permiso denegado. $error');
      debugPrint('$stack');
      if (!mounted) return;
      _aviso('Necesitamos permiso de ubicación para marcar el origen.');
    } catch (error, stack) {
      debugPrint('Ubicación: no se pudo leer la posición. $error');
      debugPrint('$stack');
      if (!mounted) return;
      _aviso('No se pudo obtener tu ubicación. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _ubicando = false);
    }
  }

  void _usarOrigen(LugarElegido lugar) {
    setState(() {
      _originPoint = lugar.punto;
      _origenDireccion = lugar.direccion;
      if (_destinationPoint == null) _isSelectingOrigin = false;
    });
    _centrar(lugar.punto);
    _recalcularRecorrido();
  }

  void _usarDestino(LugarElegido lugar) {
    setState(() {
      _destinationPoint = lugar.punto;
      _destinoDireccion = lugar.direccion;
    });
    _centrar(lugar.punto);
    _recalcularRecorrido();
  }

  void _limpiarOrigen() {
    setState(() {
      _originPoint = null;
      _origenDireccion = '';
    });
    _recalcularRecorrido();
  }

  void _limpiarDestino() {
    setState(() {
      _destinationPoint = null;
      _destinoDireccion = '';
    });
    _recalcularRecorrido();
  }

  void _centrar(LatLng punto) {
    _mapa?.animateCamera(
      gmaps.CameraUpdate.newLatLngZoom(_aGoogle(punto), 16),
    );
  }

  Future<void> _recalcularRecorrido() async {
    final origen = _originPoint;
    final destino = _destinationPoint;
    if (origen == null || destino == null) {
      setState(() {
        _recorrido = null;
        _calculandoRuta = false;
      });
      return;
    }

    final id = ++_calculoId;
    setState(() => _calculandoRuta = true);
    final resultado = await calcularRecorrido(origen, destino);
    if (!mounted || id != _calculoId) return;
    setState(() {
      _recorrido = resultado;
      _calculandoRuta = false;
    });
  }

  String get _tituloPantalla {
    switch (_servicio) {
      case 'delivery':
        return 'Punto de Recogida y Entrega';
      case 'mototaxi':
        return 'Moto Taxi - Tu Ruta';
      case 'taxi':
        return 'Taxi - Tu Ruta';
      default:
        return 'Seleccionar Ubicación';
    }
  }

  String get _avisoSinConductor {
    switch (_servicio) {
      case 'mototaxi':
        return 'No hay motos en línea en este momento.';
      case 'taxi':
        return 'No hay carros en línea en este momento.';
      default:
        return 'No hay conductores en línea en este momento.';
    }
  }

  String get _labelOrigen {
    return _servicio == 'delivery'
        ? 'Punto de Recogida (Pickup)'
        : 'Origen (Tu ubicación)';
  }

  String get _labelDestino {
    return _servicio == 'delivery'
        ? 'Punto de Entrega (Cliente)'
        : 'Destino del Viaje';
  }

  gmaps.LatLng _aGoogle(LatLng punto) {
    return gmaps.LatLng(punto.latitude, punto.longitude);
  }

  Set<gmaps.Marker> _generarMarcadores() {
    final markers = <gmaps.Marker>{};

    if (_originPoint != null) {
      markers.add(
        gmaps.Marker(
          markerId: const gmaps.MarkerId('origen'),
          position: _aGoogle(_originPoint!),
          icon: _iconoOrigen ??
              gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueYellow),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    if (_destinationPoint != null) {
      markers.add(
        gmaps.Marker(
          markerId: const gmaps.MarkerId('destino'),
          position: _aGoogle(_destinationPoint!),
          icon: _iconoDestino ??
              gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueRed),
          anchor: const Offset(0.5, 1),
        ),
      );
    }

    return markers;
  }

  Set<gmaps.Polyline> _generarRuta(List<LatLng> puntosRuta) {
    if (puntosRuta.length < 2) return {};
    final points = puntosRuta.map(_aGoogle).toList();
    return {
      gmaps.Polyline(
        polylineId: const gmaps.PolylineId('ruta-borde'),
        points: points,
        color: Colors.black.withValues(alpha: 0.15),
        width: 9,
        jointType: gmaps.JointType.round,
        startCap: gmaps.Cap.roundCap,
        endCap: gmaps.Cap.roundCap,
        zIndex: 0,
      ),
      gmaps.Polyline(
        polylineId: const gmaps.PolylineId('ruta'),
        points: points,
        color: AppColors.lightBlueRoute,
        width: 5,
        jointType: gmaps.JointType.round,
        startCap: gmaps.Cap.roundCap,
        endCap: gmaps.Cap.roundCap,
        zIndex: 1,
      ),
    };
  }

  void _confirmarRuta() {
    final origen = _originPoint;
    final destino = _destinationPoint;
    if (origen == null || destino == null || _recorrido == null) return;
    if (_errorZonas || _zonas == null) return;
    if (!_dentroDeCobertura(origen) || !_dentroDeCobertura(destino)) return;
    if (_hayConductor != true || _errorConductores) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PagoScreen(
          tipoServicio: _servicio,
          origen: _originPoint,
          destino: _destinationPoint,
          distanciaKm: _recorrido!.distanciaKm,
          montoUsd: _monto,
          tarifaPorKm: _usdPorKm,
          origenDireccion: _origenDireccion,
          destinoDireccion: _destinoDireccion,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final puntosRuta = _recorrido?.puntosRuta ??
        [
          if (_originPoint != null) _originPoint!,
          if (_destinationPoint != null) _destinationPoint!,
        ];
    final origen = _originPoint;
    final destino = _destinationPoint;
    final coberturaLista = _zonas != null && !_errorZonas;
    final fuera = coberturaLista &&
        ((origen != null && !_dentroDeCobertura(origen)) ||
            (destino != null && !_dentroDeCobertura(destino)));
    final listo = origen != null &&
        destino != null &&
        _recorrido != null &&
        !_calculandoRuta &&
        coberturaLista &&
        !fuera &&
        _hayConductor == true &&
        !_errorConductores;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          _tituloPantalla,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: ColoredBox(color: AppColors.lightBackground),
          ),
          Positioned.fill(
            child: gmaps.GoogleMap(
            initialCameraPosition: gmaps.CameraPosition(
              target: _aGoogle(_initialPosition),
              zoom: CiudadOperacion.zoomInicial,
            ),
            onMapCreated: (controlador) => _mapa = controlador,
            onTap: _onMapTapped,
            markers: _generarMarcadores(),
            polylines: _generarRuta(puntosRuta),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            padding: const EdgeInsets.fromLTRB(12, 210, 12, 160),
            circles: _circulosCobertura(),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CampoLugar(
                      key: _campoOrigen,
                      etiqueta: _labelOrigen,
                      icono: const Icon(Icons.trip_origin, color: AppColors.blackPure, size: 22),
                      activo: _isSelectingOrigin,
                      onEnfocado: () => setState(() => _isSelectingOrigin = true),
                      onElegido: _usarOrigen,
                      onVacio: _limpiarOrigen,
                      onUbicacionActual: _usarUbicacionActual,
                      cargandoUbicacion: _ubicando,
                    ),
                    const SizedBox(height: 8),
                    CampoLugar(
                      key: _campoDestino,
                      etiqueta: _labelDestino,
                      icono: const Icon(Icons.location_on, color: AppColors.blackPure, size: 24),
                      activo: !_isSelectingOrigin,
                      onEnfocado: () => setState(() => _isSelectingOrigin = false),
                      onElegido: _usarDestino,
                      onVacio: _limpiarDestino,
                    ),
                    if (_calculandoRuta || _recorrido != null) ...[
                      Divider(height: 1, color: AppColors.borderGray.withValues(alpha: 0.6)),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: _calculandoRuta
                            ? const Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Calculando recorrido y tarifa...',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  const Icon(Icons.route_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          Tarifas.formatearKm(_recorrido!.distanciaKm),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            color: AppColors.mediumGray,
                                          ),
                                        ),
                                        MontoDual(
                                          usd: _monto,
                                          alineacion: CrossAxisAlignment.start,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                            color: AppColors.blackPure,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (fuera)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.blackPure,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Por el momento, Ringo no ofrece servicio en esta zona',
                      style: TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                  )
                else if (_hayConductor == false || _errorConductores)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.blackPure,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _errorConductores
                              ? 'No se pudo comprobar si hay conductores en línea.'
                              : _avisoSinConductor,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                        if (_errorConductores)
                          TextButton(
                            onPressed: _reintentarConductores,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primaryYellow,
                              padding: const EdgeInsets.fromLTRB(0, 8, 12, 0),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              _reintentandoConductores ? 'Reintentando…' : 'Reintentar',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                      ],
                    ),
                  )
                else if (_errorZonas)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.blackPure,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'No se pudo comprobar la cobertura.',
                      style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryYellow,
                foregroundColor: AppColors.blackPure,
                disabledBackgroundColor: AppColors.borderGray,
                disabledForegroundColor: AppColors.mediumGray,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: listo ? 4 : 0,
              ),
              onPressed: listo ? _confirmarRuta : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Confirmar',
                    style:  TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (listo) ...[
                    const SizedBox(width: 8),
                    MontoDual(
                      usd: _monto,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.blackPure,
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 22),
                ],
              ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Set<gmaps.Circle> _circulosCobertura() {
    final zonas = _zonas;
    if (zonas == null) return {};
    return {
      for (final zona in zonas)
        gmaps.Circle(
          circleId: gmaps.CircleId(zona.id),
          center: gmaps.LatLng(zona.latitud, zona.longitud),
          radius: zona.radioKm * 1000,
          fillColor: AppColors.primaryYellow.withValues(alpha: 0.12),
          strokeColor: AppColors.blackPure.withValues(alpha: 0.35),
          strokeWidth: 2,
        ),
    };
  }
}

Future<gmaps.BitmapDescriptor> _dibujarMarcador({
  required double ratio,
  required Size size,
  required void Function(Canvas canvas, Size size) draw,
}) async {
  final width = (size.width * ratio).ceil();
  final height = (size.height * ratio).ceil();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(ratio);
  draw(canvas, size);
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return gmaps.BitmapDescriptor.bytes(
    data!.buffer.asUint8List(),
    imagePixelRatio: ratio,
  );
}

void _dibujarOrigen(Canvas canvas, Size size) {
  final center = Offset(size.width / 2, size.height / 2);
  canvas.drawCircle(
    center.translate(0, 1),
    16,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
  );
  canvas.drawCircle(center, 16, Paint()..color = AppColors.blackPure);
  canvas.drawCircle(center, 11, Paint()..color = AppColors.primaryYellow);
  canvas.drawCircle(center, 4.5, Paint()..color = AppColors.blackPure);
}

void _dibujarDestino(Canvas canvas, Size size) {
  final cx = size.width / 2;
  const headR = 14.0;
  final head = Offset(cx, headR + 2);

  canvas.drawCircle(
    head.translate(0, 2),
    headR,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
  );

  final pin = Path()
    ..moveTo(cx - 7, head.dy + 8)
    ..lineTo(cx, size.height - 2)
    ..lineTo(cx + 7, head.dy + 8)
    ..close();
  final negro = Paint()..color = AppColors.blackPure;
  canvas.drawPath(pin, negro);
  canvas.drawCircle(head, headR, negro);
  canvas.drawCircle(head, 6, Paint()..color = AppColors.primaryYellow);
}
