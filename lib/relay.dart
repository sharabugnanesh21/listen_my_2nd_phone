import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// The cross-device relay: notifications live under `users/{uid}/events`, shared
/// by every phone signed into the same Google account.
class Relay {
  static CollectionReference<Map<String, dynamic>>? _events() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('events');
  }

  /// Live stream of the most recent forwarded events (newest first).
  static Stream<QuerySnapshot<Map<String, dynamic>>>? stream() {
    return _events()
        ?.orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  /// Deletes all forwarded events in the cloud (used when clearing history).
  static Future<void> clearRemote() async {
    final events = _events();
    if (events == null) return;
    final snap = await events.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Deletes a single forwarded event (by its shared id) from the cloud, so it
  /// disappears from the other phones too.
  static Future<void> deleteRemote(String id) async {
    final events = _events();
    if (events == null || id.isEmpty) return;
    final query = await events.where('id', isEqualTo: id).get();
    if (query.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in query.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
