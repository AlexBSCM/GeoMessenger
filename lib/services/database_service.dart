import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _radiusMeters = 100.0;

  Future<String> createMessage({
    required String senderId,
    required String senderName,
    required String recipientId,
    required String text,
    required double latitude,
    required double longitude,
  }) async {
    final id = const Uuid().v4();
    final message = GeoMessage(
      id: id,
      senderId: senderId,
      senderName: senderName,
      recipientId: recipientId,
      text: text,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: _radiusMeters,
    );
    await _firestore.collection('messages').doc(id).set(message.toMap());
    return id;
  }

  Stream<GeoMessage> getIncomingMessages(String userId) {
    return _firestore
        .collection('messages')
        .where('recipientId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => GeoMessage.fromMap(doc.data())).toList())
        .asyncExpand((messages) => Stream.fromIterable(messages));
  }

  Stream<GeoMessage> getSentMessages(String userId) {
    return _firestore
        .collection('messages')
        .where('senderId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => GeoMessage.fromMap(doc.data())).toList())
        .asyncExpand((messages) => Stream.fromIterable(messages));
  }

  Future<List<GeoMessage>> getActiveGeofences(String userId) async {
    final snapshot = await _firestore
        .collection('messages')
        .where('recipientId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();
    return snapshot.docs.map((doc) => GeoMessage.fromMap(doc.data())).toList();
  }

  Future<void> markDelivered(String messageId) async {
    await _firestore.collection('messages').doc(messageId).update({
      'status': 'delivered',
      'deliveredAt': DateTime.now().toIso8601String(),
    });
  }

  Stream<List<AppUser>> getContacts(String userId) {
    return _firestore
        .collection('users')
        .where('id', isNotEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => AppUser.fromMap(doc.data())).toList());
  }

  Future<AppUser?> getUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.data()!);
  }
}
