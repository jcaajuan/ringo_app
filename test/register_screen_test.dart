import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringo_app/register_screen.dart';
import 'package:ringo_app/theme/app_theme.dart';

void main() {
  testWidgets('el registro pide los datos nuevos y ambas confirmaciones', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const RegisterScreen(),
      ),
    );

    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Nombre Completo'), findsOneWidget);
    expect(find.text('Fecha de nacimiento'), findsOneWidget);
    expect(find.text('Día'), findsOneWidget);
    expect(find.text('Mes'), findsOneWidget);
    expect(find.text('Año'), findsOneWidget);
    expect(find.text('Dirección'), findsOneWidget);
    expect(find.text('Cédula de identidad'), findsOneWidget);
    expect(find.text('Correo Electrónico'), findsOneWidget);
    expect(find.text('Teléfono'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Confirmo que soy mayor de 18 años de edad'), findsOneWidget);
    expect(find.textContaining('Términos y Condiciones'), findsOneWidget);
    expect(find.text('Registrarme'), findsOneWidget);

    await tester.tap(find.text('Registrarme'));
    await tester.pump();
    expect(
      find.text('Revisa los campos marcados e inténtalo de nuevo.'),
      findsOneWidget,
    );

    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Ana Perez');
    await tester.enterText(campos.at(1), 'Calle Bolivar 12');
    await tester.enterText(campos.at(2), '12345678');
    await tester.enterText(campos.at(3), 'ana@correo.com');
    await tester.enterText(campos.at(4), '4121234567');
    await tester.enterText(campos.at(5), 'secreto');
    await tester.pump(const Duration(seconds: 5));
    await _elegir(tester, 0, '15');
    await _elegir(tester, 1, 'Enero');
    await _elegir(tester, 2, '2000');

    await tester.ensureVisible(find.text('Registrarme'));
    await tester.tap(find.text('Registrarme'));
    await tester.pump();
    expect(
      find.text('Debes confirmar que eres mayor de 18 años de edad.'),
      findsOneWidget,
    );

    await _cerrarAviso(tester);
    await tester.ensureVisible(find.byType(Checkbox).first);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isTrue);
    await tester.ensureVisible(find.text('Registrarme'));
    await tester.tap(find.text('Registrarme'));
    await tester.pump();
    expect(
      find.text('Debes aceptar los Términos y Condiciones para registrarte.'),
      findsOneWidget,
    );
  });
}

Future<void> _cerrarAviso(WidgetTester tester) async {
  ScaffoldMessenger.of(tester.element(find.byType(Scaffold))).hideCurrentSnackBar();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _elegir(WidgetTester tester, int indice, String opcion) async {
  final boton = find.byType(DropdownButton<int>).at(indice);
  await tester.ensureVisible(boton);
  await tester.tap(boton);
  await tester.pumpAndSettle();
  final menu = find.byType(ListView).last;
  await tester.scrollUntilVisible(
    find.text(opcion),
    64,
    scrollable: find.descendant(of: menu, matching: find.byType(Scrollable)),
  );
  await tester.tap(find.text(opcion).last);
  await tester.pumpAndSettle();
}
