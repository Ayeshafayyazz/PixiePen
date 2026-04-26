import 'package:cloud_firestore/cloud_firestore.dart';

class StoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// =========================
  /// LIKE / UNLIKE (SAFE)
  /// =========================
  Future<void> toggleLike({
    required String storyId,
    required String userId,
  }) async {
    final ref = _db.collection('stories').doc(storyId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);

      final data = snap.data() as Map<String, dynamic>;

      final List likedBy = List.from(data['likedBy'] ?? []);
      int likes = (data['likes'] ?? 0);

      if (likedBy.contains(userId)) {
        likedBy.remove(userId);
        likes = likes - 1;
      } else {
        likedBy.add(userId);
        likes = likes + 1;
      }

      tx.set(ref, {
        'likes': likes,
        'likedBy': likedBy,
      }, SetOptions(merge: true));
    });
  }

  /// =========================
  /// ADD COMMENT
  /// =========================
  Future<void> addComment({
    required String storyId,
    required String userId,
    required String userName,
    required String text,
  }) async {
    final storyRef = _db.collection('stories').doc(storyId);

    final commentRef = storyRef.collection('comments').doc();

    await _db.runTransaction((tx) async {
      tx.set(commentRef, {
        'userId': userId,
        'userName': userName,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(storyRef, {
        'comments': FieldValue.increment(1),
      }, SetOptions(merge: true));
    });
  }

  /// =========================
  /// LIVE COMMENTS STREAM
  /// =========================
  Stream<QuerySnapshot> getComments(String storyId) {
    return _db
        .collection('stories')
        .doc(storyId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}