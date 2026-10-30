import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringo_app/models/zona_operativa.dart';

void main() {
  const elTigre = ZonaOperativa(
    id: 'tigre',
    nombre: 'El Tigre',
    latitud: 8.887,
    longitud: -64.252,
    radioKm: 25,
    activa: true,
  );

  test('origen y destino dentro de la zona están cubiertos', () {
    expect(ZonaOperativa.cubreAlguna([elTigre], const LatLng(8.89, -64.25)), isTrue);
    expect(ZonaOperativa.cubreAlguna([elTigre], const LatLng(8.88, -64.26)), isTrue);
  });

  test('un destino fuera del radio no está cubierto', () {
    expect(ZonaOperativa.cubreAlguna([elTigre], const LatLng(10.4806, -66.9036)), isFalse);
    expect(ZonaOperativa.cubreAlguna(const [], const LatLng(8.887, -64.252)), isFalse);
  });
}
