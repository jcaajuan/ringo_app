import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'ciudad.dart';
import 'historial_screen.dart';
import 'location_selection_screen.dart';
import 'seguimiento_screen.dart';
import 'settings_screen.dart';
import 'services/auth_service.dart';
import 'services/viaje_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _seleccionarServicio(BuildContext context, String tipoServicio) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationSelectionScreen(tipoServicio: tipoServicio),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const RingoBrandHeader(
          fontSize: 24,
          showSubtitle: false,
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Mis viajes',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const HistorialScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => AuthService.instance.cerrarSesion(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con tipografía gruesa tipo Delivery
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 22, 18, 22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1C1C1C), Color(0xFF121212)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.blackPure.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.primaryYellow,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'MOVILIDAD URBANA',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AppColors.blackPure,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            '¿Qué necesitas hoy?',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppColors.white,
                              height: 1.15,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 16,
                                color: AppColors.primaryYellow,
                              ),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${CiudadOperacion.nombre}, ${CiudadOperacion.estado}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFD6D6D6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
                      ),
                      child: const Icon(
                        Icons.two_wheeler_rounded,
                        color: AppColors.primaryYellow,
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const _ViajeEnCurso(),
              const SizedBox(height: 8),

              const Text(
                'Servicios Disponibles',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.blackPure,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 14),

              // Lista de servicios con el botón circular de flecha negra '→'
              Expanded(
                child: ListView(
                  children: [
                    _TarjetaServicio(
                      titulo: 'Delivery',
                      subtitulo: 'Envía o recoge paquetes al instante',
                      asset: 'assets/services/delivery.png',
                      icono: Icons.local_shipping_rounded,
                      onTap: () => _seleccionarServicio(context, 'delivery'),
                    ),
                    const SizedBox(height: 14),
                    _TarjetaServicio(
                      titulo: 'Moto Taxi',
                      subtitulo: 'Viaje individual rápido en motocicleta',
                      asset: 'assets/services/mototaxi.png',
                      icono: Icons.two_wheeler_rounded,
                      onTap: () => _seleccionarServicio(context, 'mototaxi'),
                    ),
                    const SizedBox(height: 14),
                    _TarjetaServicio(
                      titulo: 'Taxi (Carro)',
                      subtitulo: 'Traslado cómodo en vehículo a tu destino',
                      asset: 'assets/services/taxi.png',
                      icono: Icons.directions_car_rounded,
                      onTap: () => _seleccionarServicio(context, 'taxi'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViajeEnCurso extends StatefulWidget {
  const _ViajeEnCurso();

  @override
  State<_ViajeEnCurso> createState() => _ViajeEnCursoState();
}

class _ViajeEnCursoState extends State<_ViajeEnCurso> {
  final Set<String> _expirados = {};

  Future<void> _expirar(ViajeActivo viaje) async {
    final creado = viaje.creadoEn;
    if (viaje.estado != 'pendiente' || creado == null || _expirados.contains(viaje.id)) return;
    if (DateTime.now().difference(creado) <= ViajeService.vigencia) return;
    _expirados.add(viaje.id);
    try {
      await ViajeService.instance.expirar(viaje.id);
    } catch (_) {
      _expirados.remove(viaje.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ViajeActivo>>(
      stream: ViajeService.instance.observarPropios(),
      builder: (context, snapshot) {
        final viajes = snapshot.data ?? const <ViajeActivo>[];
        ViajeActivo? activo;
        for (final viaje in viajes) {
          if (viaje.estado == 'pendiente') {
            _expirar(viaje);
          }
          if (activo == null && viaje.sigueAbierto) activo = viaje;
        }
        final viaje = activo;
        if (viaje == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: AppColors.blackPure,
            borderRadius: BorderRadius.circular(18),
            child: ListTile(
              title: Text(
                viaje.tituloEstado,
                style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Toca para ver el mapa',
                style: TextStyle(color: AppColors.borderGray),
              ),
              trailing: const Icon(Icons.arrow_forward_rounded, color: AppColors.primaryYellow),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SeguimientoScreen(viajeId: viaje.id),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _TarjetaServicio extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final String asset;
  final IconData icono;
  final VoidCallback onTap;

  const _TarjetaServicio({
    required this.titulo,
    required this.subtitulo,
    required this.asset,
    required this.icono,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 18.0),
            child: Row(
              children: [
                // Icono plano en negro sobre fondo amarillo vibrante
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryYellow,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Image.asset(
                    asset,
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      icono,
                      size: 30,
                      color: AppColors.blackPure,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Textos del servicio
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: AppColors.blackPure,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitulo,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.mediumGray,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Botón circular negro con flecha blanca '→' (exacto a la imagen)
                RingoCircleArrowButton(onTap: onTap, size: 44),
              ],
            ),
          ),
        ),
      ),
    );
  }
}