import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringo_app/theme/app_theme.dart';
import 'package:ringo_app/welcome_screen.dart';

void main() {
  testWidgets('RinGo! smoke test - WelcomeScreen se renderiza con nueva identidad de marca', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const WelcomeScreen(),
      ),
    );

    expect(find.text('DELIVERY | MOTOTAXI'), findsOneWidget);
    expect(find.text('Delivery'), findsOneWidget);
    expect(find.text('Iniciar Sesión'), findsOneWidget);
    expect(find.text('Crear Cuenta'), findsOneWidget);
  });
}
