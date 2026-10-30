import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'google_map_setup_stub.dart'
    if (dart.library.io) 'google_map_setup_io.dart';
import 'services/local_notification_service.dart';
import 'services/push_notification_service.dart';
import 'theme/app_theme.dart';
import 'welcome_screen.dart';
import 'home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await prepararGoogleMaps();

  Object? firebaseInitError;
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      Firebase.app();
    }
    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    }
  } on FirebaseException catch (e, st) {
    // Hot restart y el auto-init nativo dejan [DEFAULT] creada aunque
    // Firebase.apps aún esté vacío en Dart. Se reutiliza esa instancia.
    if (e.code == 'duplicate-app') {
      Firebase.app();
      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      }
    } else {
      firebaseInitError = e;
      debugPrint('Error al inicializar Firebase: $e\n$st');
    }
  } catch (e, st) {
    firebaseInitError = e;
    debugPrint('Error al inicializar Firebase: $e\n$st');
  }

  if (firebaseInitError == null) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Notificaciones locales + sonidos de eventos del viaje. No bloquea el arranque si falla.
  try {
    await LocalNotificationService.instance.inicializar();
  } catch (e, st) {
    debugPrint('Error al inicializar las notificaciones locales: $e\n$st');
  }

  if (firebaseInitError == null) {
    try {
      await PushNotificationService.instance.iniciar();
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        unawaited(mostrarPushLocal(message, desdePush: true));
      });
      final inicial = await FirebaseMessaging.instance.getInitialMessage();
      if (inicial != null) {
        unawaited(mostrarPushLocal(inicial, desdePush: true));
      }
    } catch (e, st) {
      debugPrint('Error al iniciar Firebase Messaging: $e\n$st');
    }
  }

  runApp(MyApp(firebaseInitError: firebaseInitError));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.firebaseInitError});

  final Object? firebaseInitError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RinGo!',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: firebaseInitError != null
          ? _FirebaseErrorScreen(error: firebaseInitError!)
          : const AuthGate(),
    );
  }
}

class _FirebaseErrorScreen extends StatelessWidget {
  const _FirebaseErrorScreen({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Firebase no se pudo iniciar.\n\n'
              'La app debe usar el proyecto ringo-backend.\n\n'
              '$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

/// Muestra Home si hay sesión; si no, la bienvenida.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const WelcomeScreen();
      },
    );
  }
}