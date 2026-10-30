import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/zona_operativa.dart';

class ZonasService {
  ZonasService._();
  static final ZonasService instance = ZonasService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<ZonaOperativa>> observarActivas() {
    return _db.collection('operating_zones').snapshots().map((snap) {
      final zonas = <ZonaOperativa>[];
      for (final doc in snap.docs) {
        final zona = ZonaOperativa.desde(doc.id, doc.data());
        if (zona != null && zona.activa) zonas.add(zona);
      }
      return zonas;
    });
  }
}
