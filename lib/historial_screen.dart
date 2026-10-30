import 'package:flutter/material.dart';

import 'seguimiento_screen.dart';
import 'services/viaje_service.dart';
import 'widgets/monto_dual.dart';
import 'theme/app_theme.dart';

class HistorialScreen extends StatelessWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(title: const Text('Mis viajes')),
      body: StreamBuilder<List<ViajeActivo>>(
        stream: ViajeService.instance.observarPropios(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final viajes = snapshot.data!;
          if (viajes.isEmpty) {
            return const Center(child: Text('Todavía no tienes viajes.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: viajes.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final viaje = viajes[index];
              return Card(
                child: ListTile(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        viaje.tituloEstado,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      MontoDual(
                        usd: viaje.dolares,
                        bolivaresFijos: viaje.montoBolivares,
                        tasaViva: false,
                        alineacion: CrossAxisAlignment.start,
                      ),
                      Text(
                        viaje.etiquetaPago,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${_lugar(viaje.origenDireccion)}\n${_lugar(viaje.destinoDireccion)}',
                  ),
                  isThreeLine: true,
                  onTap: viaje.sigueAbierto
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => SeguimientoScreen(viajeId: viaje.id),
                            ),
                          );
                        }
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _lugar(String texto) => texto.trim().isEmpty ? 'Punto en el mapa' : texto.trim();
}
