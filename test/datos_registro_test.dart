import 'package:flutter_test/flutter_test.dart';
import 'package:ringo_app/models/datos_registro.dart';

void main() {
  final hoy = DateTime(2026, 10, 28);

  test('acepta una fecha de quien ya cumplió 18 años', () {
    expect(
      DatosRegistro.validarFecha(dia: 28, mes: 10, anio: 2008, hoy: hoy),
      isNull,
    );
    expect(
      DatosRegistro.tieneMayoriaDeEdad(DateTime(2008, 10, 28), hoy),
      isTrue,
    );
  });

  test('rechaza a quien cumple 18 mañana', () {
    expect(
      DatosRegistro.validarFecha(dia: 29, mes: 10, anio: 2008, hoy: hoy),
      'Debes tener al menos 18 años para registrarte',
    );
  });

  test('rechaza el 31 de febrero y una fecha incompleta', () {
    expect(
      DatosRegistro.interpretarFecha(dia: 31, mes: 2, anio: 2000),
      isNull,
    );
    expect(
      DatosRegistro.validarFecha(dia: 1, mes: null, anio: 2000, hoy: hoy),
      'Selecciona el día, el mes y el año de nacimiento',
    );
  });

  test('valida dirección y cédula', () {
    expect(DatosRegistro.validarDireccion('  '), isNotNull);
    expect(DatosRegistro.validarDireccion('Calle 5, casa 12'), isNull);
    expect(DatosRegistro.validarCedula('12.345.678'), isNull);
    expect(DatosRegistro.normalizarCedula('V-12.345.678'), '12345678');
    expect(DatosRegistro.validarCedula('123'), isNotNull);
  });
}
