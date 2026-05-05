import 'package:cloud_firestore/cloud_firestore.dart';

import 'content_moderation_service.dart';

class StoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// =========================
  /// LIKE / UNLIKE (SAFE)
  /// =========================
  Future<void> toggleLike({
    required String storyId,
    required String userId,
    String userName = 'User',
  }) async {
    final ref = _db.collection('stories').doc(storyId);
    final notificationRef = _db.collection('notifications').doc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);

      final data = snap.data() as Map<String, dynamic>;

      final List likedBy = List.from(data['likedBy'] ?? []);
      int likes = (data['likes'] ?? 0);
      final ownerId = data['authorId'] as String?;
      final title = (data['title'] as String?) ?? 'your story';

      if (likedBy.contains(userId)) {
        likedBy.remove(userId);
        likes = likes - 1;
      } else {
        likedBy.add(userId);
        likes = likes + 1;

        if (ownerId != null && ownerId != userId) {
          tx.set(notificationRef, {
            'toUserId': ownerId,
            'fromUserId': userId,
            'fromUserName': userName,
            'type': 'like',
            'storyId': storyId,
            'storyTitle': title,
            'message': '$userName liked "$title"',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      tx.set(
          ref,
          {
            'likes': likes,
            'likedBy': likedBy,
          },
          SetOptions(merge: true));
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
    final storySnap = await storyRef.get();
    final storyTitle = (storySnap.data()?['title'] as String?) ?? '';
    final moderation = ContentModerationService().moderateWithSurface(
      ModerationSurface.comment,
      text,
      storyExcerpt: storyTitle,
    );
    if (!moderation.isSafe) {
      throw ArgumentError(ContentModerationService.childFriendlyWarning);
    }


    final commentRef = storyRef.collection('comments').doc();
    final notificationRef = _db.collection('notifications').doc();

    await _db.runTransaction((tx) async {
      final storySnap = await tx.get(storyRef);
      final storyData = storySnap.data() ?? {};
      final ownerId = storyData['authorId'] as String?;
      final title = (storyData['title'] as String?) ?? 'your story';

      tx.set(commentRef, {
        'userId': userId,
        'userName': userName,
        'text': text,
        'moderation': {
          'isSafe': true,
          'flagReason': null,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(
          storyRef,
          {
            'comments': FieldValue.increment(1),
          },
          SetOptions(merge: true));

      if (ownerId != null && ownerId != userId) {
        tx.set(notificationRef, {
          'toUserId': ownerId,
          'fromUserId': userId,
          'fromUserName': userName,
          'type': 'comment',
          'storyId': storyId,
          'storyTitle': title,
          'message': '$userName commented on "$title"',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
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
