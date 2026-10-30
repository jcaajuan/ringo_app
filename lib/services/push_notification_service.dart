import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../firebase_options.dart';
import 'local_notification_service.dart';

/// Recibe el push data-only con la app en segundo plano o cerrada.
///
/// Tiene que ser una función de nivel superior y registrarse antes de
/// `runApp`. No depende de que la pantalla de seguimiento esté montada:
/// el backend manda el aviso y aquí se pinta el canal local del evento.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  LocalNotificationService.instance.marcarSegundoPlano();
  await LocalNotificationService.instance.inicializar();
  await mostrarPushLocal(message, desdePush: true);
}

EventoNotificacion? _eventoDe(String? tipo) {
  return switch (tipo) {
    'conductor_asignado' => EventoNotificacion.conductorAsignado,
    'conductor_llego' => EventoNotificacion.conductorLlego,
    'viaje_finalizado' => EventoNotificacion.viajeFinalizado,
    'viaje_cancelado' => EventoNotificacion.viajeCancelado,
    'mensaje' || 'mensaje_chat' => EventoNotificacion.mensaje,
    _ => null,
  };
}

Future<void> mostrarPushLocal(RemoteMessage message, {required bool desdePush}) async {
  final data = message.data;
  final evento = _eventoDe(data['tipo']);
  if (evento == null) return;
  final titulo = data['titulo'] ?? 'RinGo!';
  final cuerpo = data['cuerpo'] ?? '';
  if (titulo.isEmpty && cuerpo.isEmpty) return;
  await LocalNotificationService.instance.notificar(
    evento,
    viajeId: data['viajeId'] ?? titulo,
    titulo: titulo,
    cuerpo: cuerpo.isEmpty ? titulo : cuerpo,
    mensajeId: data['mensajeId'],
    desdePush: desdePush,
  );
}

/// Guarda `usuarios/{uid}.fcmToken` al iniciar sesión y muestra el push
/// data-only con la app abierta, en cualquier pantalla.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static bool get _soportado =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  StreamSubscription<User?>? _sesion;
  String? _uid;

  Future<void> iniciar() async {
    if (!_soportado || _sesion != null) return;
    final messaging = FirebaseMessaging.instance;
    try {
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );
    } catch (error) {
      debugPrint('No se pudo pedir permiso de push: $error');
    }

    FirebaseMessaging.onMessage.listen((message) {
      unawaited(mostrarPushLocal(message, desdePush: false));
    });
    messaging.onTokenRefresh.listen((token) {
      final uid = _uid;
      if (uid == null) return;
      unawaited(_guardar(uid, token));
    });
    _sesion = FirebaseAuth.instance.authStateChanges().listen((user) {
      _uid = user?.uid;
      if (user == null) return;
      unawaited(_guardarTokenActual(user.uid));
    });
  }

  Future<void> _guardarTokenActual(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty || _uid != uid) return;
      await _guardar(uid, token);
    } catch (error) {
      debugPrint('No se pudo leer el token FCM: $error');
    }
  }

  Future<void> _guardar(String uid, String token) async {
    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set(
        {
          'fcmToken': token,
          'fcmTokenActualizadoEn': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (error) {
      debugPrint('No se pudo guardar el token FCM: $error');
    }
  }
}
