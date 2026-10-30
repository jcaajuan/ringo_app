// Archivo de configuración de Firebase para Ringo App (proyecto ringo-backend)
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions no está configurado para Linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions no es compatible con esta plataforma.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBM4iKru9sL9lpe7BKm8NH-HS6kvO7LsZ0',
    appId: '1:698427665450:web:52a93309bad3c4c02e2753',
    messagingSenderId: '698427665450',
    projectId: 'ringo-backend',
    authDomain: 'ringo-backend.firebaseapp.com',
    storageBucket: 'ringo-backend.firebasestorage.app',
    measurementId: 'G-VXRDQ14BGL',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBM4iKru9sL9lpe7BKm8NH-HS6kvO7LsZ0',
    appId: '1:698427665450:web:52a93309bad3c4c02e2753',
    messagingSenderId: '698427665450',
    projectId: 'ringo-backend',
    storageBucket: 'ringo-backend.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBM4iKru9sL9lpe7BKm8NH-HS6kvO7LsZ0',
    appId: '1:698427665450:web:52a93309bad3c4c02e2753',
    messagingSenderId: '698427665450',
    projectId: 'ringo-backend',
    storageBucket: 'ringo-backend.firebasestorage.app',
    iosBundleId: 'com.example.ringoApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBM4iKru9sL9lpe7BKm8NH-HS6kvO7LsZ0',
    appId: '1:698427665450:web:52a93309bad3c4c02e2753',
    messagingSenderId: '698427665450',
    projectId: 'ringo-backend',
    storageBucket: 'ringo-backend.firebasestorage.app',
    iosBundleId: 'com.example.ringoApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBM4iKru9sL9lpe7BKm8NH-HS6kvO7LsZ0',
    appId: '1:698427665450:web:52a93309bad3c4c02e2753',
    messagingSenderId: '698427665450',
    projectId: 'ringo-backend',
    authDomain: 'ringo-backend.firebaseapp.com',
    storageBucket: 'ringo-backend.firebasestorage.app',
    measurementId: 'G-VXRDQ14BGL',
  );
}
