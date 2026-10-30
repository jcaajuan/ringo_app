import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

Future<void> prepararGoogleMaps() async {
  if (kIsWeb || !Platform.isAndroid) return;
  final maps = GoogleMapsFlutterPlatform.instance;
  if (maps is! GoogleMapsFlutterAndroid) return;
  // La vista híbrida evita el mapa en blanco cuando hay paneles encima.
  maps.useAndroidViewSurface = true;
  try {
    await maps.initializeWithRenderer(AndroidMapRenderer.latest);
  } catch (error) {
    debugPrint('Renderer de Google Maps: $error');
  }
}
