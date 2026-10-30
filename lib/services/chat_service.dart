import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MensajeViaje {
  const MensajeViaje({required this.id, required this.autorId, required this.texto});

  final String id;
  final String autorId;
  final String texto;

  bool get esMio => autorId == FirebaseAuth.instance.currentUser?.uid;
}

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<MensajeViaje>> observar(String viajeId) {
    return _db
        .collection('viajes')
        .doc(viajeId)
        .collection('mensajes')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) {
      return [
        for (final doc in snap.docs)
          MensajeViaje(
            id: doc.id,
            autorId: (doc.data()['autorId'] as String?) ??
                (doc.data()['senderId'] as String?) ??
                '',
            texto: (doc.data()['texto'] as String?) ?? '',
          ),
      ];
    });
  }

  Future<void> enviar(String viajeId, String texto) async {
    final user = FirebaseAuth.instance.currentUser;
    final limpio = texto.trim();
    if (user == null || limpio.isEmpty) return;
    await _db.collection('viajes').doc(viajeId).collection('mensajes').add({
      'autorId': user.uid,
      'texto': limpio.length > 400 ? limpio.substring(0, 400) : limpio,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
