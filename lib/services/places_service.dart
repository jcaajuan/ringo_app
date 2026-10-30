import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../ciudad.dart';

class SugerenciaLugar {
  const SugerenciaLugar({
    required this.titulo,
    required this.detalle,
    required this.direccion,
    required this.punto,
  });

  final String titulo;
  final String detalle;
  final String direccion;
  final LatLng punto;

  LugarElegido get elegido => LugarElegido(direccion: direccion, punto: punto);
}

class LugarElegido {
  const LugarElegido({
    required this.direccion,
    required this.punto,
  });

  final String direccion;
  final LatLng punto;
}

class ResultadoSugerencias {
  const ResultadoSugerencias(this.lugares, {this.error});

  final List<SugerenciaLugar> lugares;
  final String? error;

  static const vacio = ResultadoSugerencias([]);
}

class PlacesService {
  PlacesService({http.Client? cliente}) : _cliente = cliente ?? http.Client();

  static final PlacesService instance = PlacesService();

  final http.Client _cliente;
  static const _espera = Duration(seconds: 8);
  static const _agente = 'RinGo/1.0 (address search)';

  /// Nominatim ya incluye latitud y longitud. No hace falta una segunda consulta.
  Future<ResultadoSugerencias> autocompletar(String texto) async {
    final consulta = texto.trim();
    if (consulta.length < 2) return ResultadoSugerencias.vacio;

    const centro = CiudadOperacion.centro;
    const margen = 0.15;
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': consulta,
      'format': 'jsonv2',
      'limit': '5',
      'addressdetails': '1',
      'countrycodes': 've',
      'viewbox':
          '${centro.longitude - margen},${centro.latitude + margen},${centro.longitude + margen},${centro.latitude - margen}',
      'bounded': '0',
    });

    try {
      final respuesta = await _cliente.get(uri, headers: const {
        'User-Agent': _agente,
        'Accept-Language': 'es',
      }).timeout(_espera);
      if (respuesta.statusCode != 200) {
        return const ResultadoSugerencias([], error: 'No se pudieron buscar direcciones.');
      }
      return leerSugerencias(jsonDecode(respuesta.body));
    } catch (_) {
      return const ResultadoSugerencias([], error: 'No se pudieron buscar direcciones.');
    }
  }
}

ResultadoSugerencias leerSugerencias(dynamic cuerpo) {
  if (cuerpo is! List) {
    return const ResultadoSugerencias([], error: 'No se pudieron buscar direcciones.');
  }

  final lugares = <SugerenciaLugar>[];
  for (final item in cuerpo) {
    if (item is! Map) continue;
    final punto = _punto(item['lat'], item['lon']);
    final direccion = item['display_name'];
    if (punto == null || direccion is! String || direccion.trim().isEmpty) continue;

    final nombre = item['name'];
    final titulo = nombre is String && nombre.trim().isNotEmpty
        ? nombre.trim()
        : direccion.split(',').first.trim();
    final resto = direccion.split(',');
    final detalle = resto.length > 1 ? resto.sublist(1).join(',').trim() : '';

    lugares.add(
      SugerenciaLugar(
        titulo: titulo,
        detalle: detalle,
        direccion: direccion.trim(),
        punto: punto,
      ),
    );
  }
  return ResultadoSugerencias(lugares);
}

LatLng? _punto(dynamic latitud, dynamic longitud) {
  final lat = double.tryParse('$latitud');
  final lng = double.tryParse('$longitud');
  if (lat == null || lng == null) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  return LatLng(lat, lng);
}
