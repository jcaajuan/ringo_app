import 'package:cloud_firestore/cloud_firestore.dart';

/// Bolívares por dólar, leídos de `settings/exchange_rate`.
class TasaCambio {
  const TasaCambio({required this.vesRate, this.actualizadoEn});

  final double vesRate;
  final DateTime? actualizadoEn;

  static TasaCambio? desde(Map<String, dynamic>? data) {
    final tasa = data?['vesRate'];
    if (tasa is! num || tasa <= 0) return null;
    return TasaCambio(vesRate: tasa.toDouble(), actualizadoEn: _fecha(data?['actualizadoEn']));
  }

  static DateTime? _fecha(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class ExchangeRateService {
  ExchangeRateService._();
  static final ExchangeRateService instance = ExchangeRateService._();

  Stream<TasaCambio?> observar() {
    try {
      return FirebaseFirestore.instance.collection('settings').doc('exchange_rate').snapshots().map(
            (snap) => TasaCambio.desde(snap.data()),
          );
    } catch (_) {
      return Stream.value(null);
    }
  }
}
