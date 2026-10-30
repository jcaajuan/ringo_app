import 'package:cloud_firestore/cloud_firestore.dart';

import '../tarifas.dart';

/// Precio por kilómetro leído de `service_rates/{id}`.
class TarifaServicio {
  const TarifaServicio({
    required this.id,
    required this.nombre,
    required this.ratePerKm,
  });

  final String id;
  final String nombre;
  final double ratePerKm;

  static const predeterminadas = <TarifaServicio>[
    TarifaServicio(id: 'mototaxi', nombre: 'Mototaxi', ratePerKm: Tarifas.usdPorKm),
    TarifaServicio(id: 'delivery', nombre: 'Delivery', ratePerKm: Tarifas.usdPorKm),
    TarifaServicio(id: 'taxi', nombre: 'Automóvil', ratePerKm: Tarifas.usdPorKm),
  ];

  static double de(List<TarifaServicio> tarifas, String id) {
    for (final tarifa in tarifas) {
      if (tarifa.id == id) return tarifa.ratePerKm;
    }
    return Tarifas.usdPorKm;
  }

  static TarifaServicio? desde(String id, Map<String, dynamic> data) {
    final nombre = data['nombre'];
    final tarifa = data['ratePerKm'];
    if (nombre is! String || tarifa is! num || tarifa <= 0) return null;
    return TarifaServicio(id: id, nombre: nombre.trim(), ratePerKm: tarifa.toDouble());
  }
}

class TarifasService {
  TarifasService._();
  static final TarifasService instance = TarifasService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<TarifaServicio>> observar() {
    return _db.collection('service_rates').snapshots().map((snap) {
      final tarifas = <TarifaServicio>[];
      for (final doc in snap.docs) {
        final tarifa = TarifaServicio.desde(doc.id, doc.data());
        if (tarifa != null) tarifas.add(tarifa);
      }
      if (tarifas.isEmpty) return TarifaServicio.predeterminadas;
      return tarifas;
    });
  }
}
