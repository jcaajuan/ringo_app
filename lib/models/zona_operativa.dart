import 'package:latlong2/latlong.dart';

class ZonaOperativa {
  const ZonaOperativa({
    required this.id,
    required this.nombre,
    required this.latitud,
    required this.longitud,
    required this.radioKm,
    required this.activa,
  });

  final String id;
  final String nombre;
  final double latitud;
  final double longitud;
  final double radioKm;
  final bool activa;

  bool cubre(LatLng punto) {
    if (!activa || radioKm <= 0) return false;
    final km = const Distance().as(
      LengthUnit.Kilometer,
      LatLng(latitud, longitud),
      punto,
    );
    return km <= radioKm;
  }

  static bool cubreAlguna(List<ZonaOperativa> zonas, LatLng punto) {
    return zonas.any((zona) => zona.cubre(punto));
  }

  static ZonaOperativa? desde(String id, Map<String, dynamic> data) {
    final nombre = data['nombre'];
    final latitud = data['latitud'];
    final longitud = data['longitud'];
    final radio = data['radioKm'];
    if (nombre is! String || nombre.trim().isEmpty) return null;
    if (latitud is! num || longitud is! num || radio is! num) return null;
    if (radio <= 0) return null;
    return ZonaOperativa(
      id: id,
      nombre: nombre.trim(),
      latitud: latitud.toDouble(),
      longitud: longitud.toDouble(),
      radioKm: radio.toDouble(),
      activa: data['activa'] != false,
    );
  }
}
