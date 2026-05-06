import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/firestore_keys.dart';

class StoryCoreService {
  StoryCoreService({FirebaseFirestore? firestore})
      : db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore db;

  DocumentReference<Map<String, dynamic>> storyRef(String storyId) {
    return db.collection(FirestoreCollections.stories).doc(storyId);
  }

  DocumentReference<Map<String, dynamic>> userRef(String userId) {
    return db.collection(FirestoreCollections.users).doc(userId);
  }

  static int readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static bool notificationsEnabled(Map<String, dynamic>? userData) {
    return userData?[FirestoreStoryFields.notificationsEnabled] != false;
  }
}
