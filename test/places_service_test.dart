import 'package:flutter_test/flutter_test.dart';
import 'package:ringo_app/services/places_service.dart';

void main() {
  test('lee nombre y coordenadas de Nominatim', () {
    final resultado = leerSugerencias([
      {
        'name': 'Plaza Bolívar',
        'display_name': 'Plaza Bolívar, El Tigre, Anzoátegui, Venezuela',
        'lat': '8.8875',
        'lon': '-64.2531',
      },
    ]);

    expect(resultado.error, isNull);
    expect(resultado.lugares, hasLength(1));
    final lugar = resultado.lugares.single;
    expect(lugar.titulo, 'Plaza Bolívar');
    expect(lugar.detalle, 'El Tigre, Anzoátegui, Venezuela');
    expect(lugar.punto.latitude, 8.8875);
    expect(lugar.punto.longitude, -64.2531);
    expect(lugar.elegido.punto.latitude, 8.8875);
  });

  test('una búsqueda vacía no es un error', () {
    final resultado = leerSugerencias([]);
    expect(resultado.error, isNull);
    expect(resultado.lugares, isEmpty);
  });

  test('ignora resultados sin coordenada', () {
    final resultado = leerSugerencias([
      {'name': 'Sin punto', 'display_name': 'Sin punto', 'lat': 'no', 'lon': '-64'},
    ]);
    expect(resultado.lugares, isEmpty);
  });
}
