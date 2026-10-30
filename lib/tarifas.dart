import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Tarifa de RinGo! en El Tigre: USD 0.90 por kilómetro de recorrido.
class Tarifas {
  static const double usdPorKm = 0.90;
  static const double kmMinimo = 1.0;

  static double distanciaLineaRectaKm(LatLng origen, LatLng destino) {
    return const Distance().as(LengthUnit.Kilometer, origen, destino);
  }

  static double cobrarKm(double distanciaKm) {
    if (distanciaKm <= 0) return kmMinimo;
    return distanciaKm < kmMinimo ? kmMinimo : distanciaKm;
  }

  static double montoUsd(double distanciaKm, {double? usdPorKm}) {
    final km = cobrarKm(distanciaKm);
    final tarifa = usdPorKm ?? Tarifas.usdPorKm;
    return double.parse((km * tarifa).toStringAsFixed(2));
  }

  static String formatearUsd(double monto) => '\$${monto.toStringAsFixed(2)}';

  static double bolivares(double usd, double vesPorDolar) {
    return double.parse((usd * vesPorDolar).toStringAsFixed(2));
  }

  static String formatearVes(double montoBs) => 'Bs. ${montoBs.toStringAsFixed(2)}';

  static String formatearEquivalente(double usd, double? vesPorDolar, {String sufijo = ''}) {
    final dolares = '${formatearUsd(usd)}$sufijo';
    if (vesPorDolar == null || vesPorDolar <= 0) return dolares;
    return '$dolares · ${formatearVes(bolivares(usd, vesPorDolar))}$sufijo';
  }

  static String formatearKm(double km) => '${km.toStringAsFixed(2)} km';
}

class RecorridoCalculado {
  const RecorridoCalculado({
    required this.distanciaKm,
    required this.puntosRuta,
    required this.esRutaVial,
  });

  final double distanciaKm;
  final List<LatLng> puntosRuta;
  final bool esRutaVial;

  double get montoUsd => Tarifas.montoUsd(distanciaKm);
}

/// Distancia por calles (OSRM). Si falla, usa línea recta.
Future<RecorridoCalculado> calcularRecorrido(LatLng origen, LatLng destino) async {
  final linea = [
    origen,
    destino,
  ];
  final kmRecta = Tarifas.distanciaLineaRectaKm(origen, destino);

  try {
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${origen.longitude},${origen.latitude};'
      '${destino.longitude},${destino.latitude}'
      '?overview=full&geometries=geojson',
    );
    final response = await http.get(
      uri,
      headers: {'User-Agent': 'com.example.ringo_app'},
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      return RecorridoCalculado(distanciaKm: kmRecta, puntosRuta: linea, esRutaVial: false);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      return RecorridoCalculado(distanciaKm: kmRecta, puntosRuta: linea, esRutaVial: false);
    }

    final route = routes.first as Map<String, dynamic>;
    final meters = (route['distance'] as num?)?.toDouble() ?? 0;
    final km = meters / 1000.0;

    final geometry = route['geometry'] as Map<String, dynamic>?;
    final coords = geometry?['coordinates'] as List<dynamic>?;
    final puntos = <LatLng>[];
    if (coords != null) {
      for (final c in coords) {
        if (c is List && c.length >= 2) {
          puntos.add(LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()));
        }
      }
    }

    return RecorridoCalculado(
      distanciaKm: km > 0 ? km : kmRecta,
      puntosRuta: puntos.length >= 2 ? puntos : linea,
      esRutaVial: puntos.length >= 2,
    );
  } catch (_) {
    return RecorridoCalculado(distanciaKm: kmRecta, puntosRuta: linea, esRutaVial: false);
  }
}
