import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'sound_service.dart';

/// Evento del viaje que avisa con notificación y sonido propio.
///
/// El nombre de [archivo] es a la vez el `.mp3` de `assets/sounds/` (primer
/// plano, con audioplayers) y el recurso `res/raw/<archivo>` del canal de
/// Android (segundo plano). El sonido es una propiedad del canal, por eso hay
/// un canal por evento.
class EventoNotificacion {
  const EventoNotificacion._(
    this.archivo,
    this.canalNombre,
    this.canalDescripcion, {
    this.esChat = false,
  });

  final String archivo;
  final String canalNombre;
  final String canalDescripcion;
  final bool esChat;

  Importance get importancia => Importance.max;

  /// Si cambias el sonido de un canal ya instalado, sube el sufijo (`_v4`):
  /// Android no permite modificar el sonido de un canal existente.
  /// `_v1` quedó mudo (canal creado antes del mp3).
  /// `_v2` quedó mudo en dispositivos con caché de canal sin sonido.
  /// `_v3` fuerza la recreación con el audio correcto.
  String get canalId => '${archivo}_v3';

  static const conductorAsignado = EventoNotificacion._(
    'ringo_conductor_asignado',
    'Conductor asignado',
    'Avisa cuando un conductor acepta tu viaje.',
  );
  static const conductorLlego = EventoNotificacion._(
    'ringo_conductor_llego',
    'El conductor llegó',
    'Avisa cuando tu conductor llega al punto de encuentro.',
  );
  static const mensaje = EventoNotificacion._(
    'ringo_mensaje',
    'Mensajes del chat',
    'Avisa de mensajes nuevos de tu conductor.',
    esChat: true,
  );
  static const viajeFinalizado = EventoNotificacion._(
    'ringo_viaje_finalizado',
    'Viaje finalizado',
    'Avisa cuando termina tu viaje.',
  );
  static const viajeCancelado = EventoNotificacion._(
    'ringo_viaje_cancelado',
    'Viaje cancelado',
    'Avisa cuando se cancela tu viaje.',
  );

  static const todos = <EventoNotificacion>[
    conductorAsignado,
    conductorLlego,
    mensaje,
    viajeFinalizado,
    viajeCancelado,
  ];
}

/// Viaje cuyo chat está abierto en pantalla: no se notifica ni suena.
class ChatActivo {
  ChatActivo._();

  static String? _viajeId;

  static String? get viajeId => _viajeId;

  static void abrir(String viajeId) => _viajeId = viajeId;

  static void cerrar(String viajeId) {
    if (_viajeId == viajeId) _viajeId = null;
  }
}

/// Notificaciones locales. El push (FCM, solo `data`) llega aunque esta
/// pantalla no esté abierta; este servicio solo lo muestra.
///
/// * Primer plano real (ciclo `resumed` y el aviso no viene de un push):
///   suena con audioplayers y el banner va al canal silencioso, para no
///   sonar dos veces.
/// * Push, segundo plano o app cerrada: el aviso va al canal del evento
///   (`ringo_*_v3`), con su mp3 de `res/raw`.
/// * Un listener de Firestore fuera de primer plano no pinta el aviso:
///   lo hace el push, para no duplicarlo.
class LocalNotificationService with WidgetsBindingObserver {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  static const _canalSilencioso = 'ringo_avisos_en_app_v2';
  static const _ventanaDuplicados = Duration(seconds: 30);

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final Map<String, DateTime> _recientes = {};

  bool _listo = false;
  bool _observando = false;
  bool _desdePush = false;
  AppLifecycleState _ciclo = AppLifecycleState.resumed;

  bool get _primerPlano => _ciclo == AppLifecycleState.resumed;

  /// El isolate de FCM no está en primer plano. La bandera impide que el
  /// observer vuelva a marcar el ciclo como `resumed` al arrancar el engine.
  void marcarSegundoPlano() {
    _desdePush = true;
    _ciclo = AppLifecycleState.paused;
  }

  static bool get _soportaNotificaciones =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Llamar una vez tras `Firebase.initializeApp`. Nunca lanza.
  Future<void> inicializar() async {
    try {
      if (!_observando) {
        _observando = true;
        WidgetsBinding.instance.addObserver(this);
        if (!_desdePush) {
          _ciclo = WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
        }
      }
      if (_listo || !_soportaNotificaciones) return;

      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestSoundPermission: true,
            requestBadgePermission: true,
            defaultPresentAlert: true,
            defaultPresentSound: true,
            defaultPresentBanner: true,
            defaultPresentList: true,
          ),
        ),
      );

      final ios = _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);

      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        for (final evento in EventoNotificacion.todos) {
          await android.createNotificationChannel(
            AndroidNotificationChannel(
              evento.canalId,
              evento.canalNombre,
              description: evento.canalDescripcion,
              importance: evento.importancia,
              playSound: true,
              sound: RawResourceAndroidNotificationSound(evento.archivo),
              audioAttributesUsage: AudioAttributesUsage.notification,
              enableVibration: true,
            ),
          );
        }
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            _canalSilencioso,
            'Avisos dentro de la app',
            description: 'Banners con la app abierta (el sonido lo reproduce la app).',
            importance: Importance.high,
            playSound: false,
            enableVibration: false,
          ),
        );
        // Android 13+: pide POST_NOTIFICATIONS sin bloquear el arranque.
        unawaited(android.requestNotificationsPermission());
      }
      _listo = true;
    } catch (error, stack) {
      debugPrint('No se pudieron iniciar las notificaciones locales: $error\n$stack');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_desdePush) return;
    _ciclo = state;
  }

  /// Avisa de [evento] para [viajeId]. [mensajeId] distingue los mensajes del
  /// chat; el resto de eventos se deduplican por viaje y tipo.
  Future<void> notificar(
    EventoNotificacion evento, {
    required String viajeId,
    required String titulo,
    required String cuerpo,
    String? mensajeId,
    bool desdePush = false,
  }) async {
    try {
      final enPrimerPlanoReal = _primerPlano && !desdePush;
      if (evento.esChat && enPrimerPlanoReal && ChatActivo.viajeId == viajeId) return;
      // Fuera de primer plano el aviso lo pinta el handler de FCM.
      if (!enPrimerPlanoReal && !desdePush) return;
      final clave = evento.esChat
          ? '$viajeId:${evento.archivo}:${mensajeId ?? cuerpo}'
          : '$viajeId:${evento.archivo}';
      if (!_esNuevo(clave)) return;

      final id = _idDe(clave);
      // El canal silencioso solo cabe en primer plano real, y solo si
      // audioplayers llegó a sonar. Push, segundo plano y app cerrada
      // entran al canal del evento, con su archivo de res/raw.
      if (enPrimerPlanoReal) {
        final sonoEnApp = await SoundService.instance.reproducir(evento.archivo);
        if (sonoEnApp && _primerPlano && !desdePush) {
          await _mostrar(
            id: id,
            titulo: titulo,
            cuerpo: cuerpo,
            android: const AndroidNotificationDetails(
              _canalSilencioso,
              'Avisos dentro de la app',
              importance: Importance.high,
              priority: Priority.high,
              playSound: false,
              enableVibration: false,
            ),
            sonar: false,
          );
          return;
        }
      }

      await _mostrar(
        id: id,
        titulo: titulo,
        cuerpo: cuerpo,
        android: AndroidNotificationDetails(
          evento.canalId,
          evento.canalNombre,
          channelDescription: evento.canalDescripcion,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(evento.archivo),
          audioAttributesUsage: AudioAttributesUsage.notification,
          enableVibration: true,
          visibility: NotificationVisibility.public,
        ),
        sonar: true,
      );
    } catch (error) {
      debugPrint('No se pudo notificar ${evento.archivo}: $error');
    }
  }

  Future<void> _mostrar({
    required int id,
    required String titulo,
    required String cuerpo,
    required AndroidNotificationDetails android,
    required bool sonar,
  }) async {
    if (!_listo) return;
    await _plugin.show(
      id,
      titulo,
      cuerpo,
      NotificationDetails(
        android: android,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: sonar,
          presentBanner: true,
          presentList: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
    );
  }

  bool _esNuevo(String clave) {
    final ahora = DateTime.now();
    _recientes.removeWhere((_, visto) => ahora.difference(visto) > _ventanaDuplicados);
    if (_recientes.containsKey(clave)) return false;
    _recientes[clave] = ahora;
    return true;
  }

  int _idDe(String clave) => clave.hashCode & 0x7fffffff;
}
