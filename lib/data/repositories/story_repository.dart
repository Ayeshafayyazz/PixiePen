import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../firestore_keys.dart';
import '../../services/content_moderation_service.dart';
import '../../services/gemini_service.dart';
import '../../services/story_core_service.dart';

class StoryRepository {
  StoryRepository({FirebaseFirestore? firestore})
      : _core = StoryCoreService(firestore: firestore);

  final StoryCoreService _core;
  final GeminiService _geminiService = GeminiService();

  Stream<QuerySnapshot<Map<String, dynamic>>> fetchStories({
    String? authorId,
    String? status,
    String? parentEmail,
  }) {
    Query<Map<String, dynamic>> query =
        _core.db.collection(FirestoreCollections.stories);
    if (authorId != null && authorId.isNotEmpty) {
      query = query.where(FirestoreStoryFields.authorId, isEqualTo: authorId);
    }
    if (status != null && status.isNotEmpty) {
      query = query.where(FirestoreStoryFields.status, isEqualTo: status);
    }
    if (parentEmail != null && parentEmail.isNotEmpty) {
      query = query.where('parentEmail', isEqualTo: parentEmail);
    }
    return query.snapshots();
  }

  Future<void> createStory({
    required Map<String, dynamic> data,
    String? storyId,
  }) async {
    if (storyId != null && storyId.isNotEmpty) {
      await _core.storyRef(storyId).set(data, SetOptions(merge: true));
      return;
    }
    await _core.db.collection(FirestoreCollections.stories).add(data);
  }

  Future<void> updateStory({
    required String storyId,
    required Map<String, dynamic> data,
  }) async {
    await _core.storyRef(storyId).set(data, SetOptions(merge: true));
  }

  Future<void> deleteStory(String storyId) async {
    await _core.storyRef(storyId).delete();
  }

  Future<void> toggleLike({
    required String storyId,
    required String userId,
    required String userName,
  }) async {
    final storyRef = _core.storyRef(storyId);
    final notificationRef =
        _core.db.collection(FirestoreCollections.notifications).doc();
    final likeEventRef = _core.db
        .collection(FirestoreCollections.storyLikes)
        .doc('${storyId}_$userId');

    await _core.db.runTransaction((tx) async {
      final snap = await tx.get(storyRef);
      final data = snap.data() as Map<String, dynamic>;

      final List likedBy = List.from(data[FirestoreStoryFields.likedBy] ?? []);
      int likes = StoryCoreService.readInt(data[FirestoreStoryFields.likes]);
      final ownerId = data[FirestoreStoryFields.authorId] as String?;
      final title =
          (data[FirestoreStoryFields.title] as String?) ?? 'your story';
      DocumentSnapshot<Map<String, dynamic>>? ownerSnap;
      if (ownerId != null && ownerId != userId) {
        ownerSnap = await tx.get(_core.userRef(ownerId));
      }

      if (likedBy.contains(userId)) {
        likedBy.remove(userId);
        likes--;
        tx.delete(likeEventRef);
      } else {
        likedBy.add(userId);
        likes++;
        if (ownerId != null) {
          tx.set(likeEventRef, {
            FirestoreStoryFields.storyId: storyId,
            FirestoreStoryFields.authorId: ownerId,
            FirestoreStoryFields.userId: userId,
            FirestoreStoryFields.userName: userName,
            FirestoreStoryFields.createdAt: FieldValue.serverTimestamp(),
          });
        }

        if (ownerId != null &&
            ownerId != userId &&
            StoryCoreService.notificationsEnabled(ownerSnap?.data())) {
          tx.set(notificationRef, {
            'toUserId': ownerId,
            'fromUserId': userId,
            'fromUserName': userName,
            'type': 'like',
            FirestoreStoryFields.storyId: storyId,
            'storyTitle': title,
            'message': '$userName liked "$title"',
            'isRead': false,
            FirestoreStoryFields.createdAt: FieldValue.serverTimestamp(),
          });
        }
      }

      tx.set(
        storyRef,
        {
          FirestoreStoryFields.likes: likes,
          FirestoreStoryFields.likedBy: likedBy,
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<bool> toggleSave({
    required String storyId,
    required String userId,
  }) async {
    final storyRef = _core.storyRef(storyId);
    final savedRef = _core.db
        .collection(FirestoreCollections.savedStories)
        .doc('${userId}_$storyId');
    final userRef = _core.userRef(userId);
    var isNowSaved = false;

    await _core.db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final savedStoryIds =
          ((userSnap.data()?[FirestoreStoryFields.savedStoryIds] as List?) ??
                  const [])
              .whereType<String>()
              .toList();
      final isSaved = savedStoryIds.contains(storyId);

      if (isSaved) {
        isNowSaved = false;
        tx.set(
          userRef,
          {
            FirestoreStoryFields.savedStoryIds:
                FieldValue.arrayRemove([storyId]),
          },
          SetOptions(merge: true),
        );
      } else {
        isNowSaved = true;
        tx.set(
          userRef,
          {
            FirestoreStoryFields.savedStoryIds:
                FieldValue.arrayUnion([storyId]),
          },
          SetOptions(merge: true),
        );
      }
    });

    try {
      if (!isNowSaved) {
        await savedRef.delete();
        await storyRef.set(
          {
            FirestoreStoryFields.saves: FieldValue.increment(-1),
            FirestoreStoryFields.savedBy: FieldValue.arrayRemove([userId]),
          },
          SetOptions(merge: true),
        );
      } else {
        final storySnap = await storyRef.get();
        final data = storySnap.data();
        if (data == null) {
          throw StateError('This story is no longer available.');
        }
        await savedRef.set({
          FirestoreStoryFields.storyId: storyId,
          FirestoreStoryFields.userId: userId,
          FirestoreStoryFields.authorId:
              data[FirestoreStoryFields.authorId] as String?,
          'storyTitle': data[FirestoreStoryFields.title] as String? ?? 'Untitled',
          FirestoreStoryFields.authorName:
              data[FirestoreStoryFields.authorName] as String? ?? 'Unknown',
          FirestoreStoryFields.coverUrl:
              data[FirestoreStoryFields.coverUrl] as String? ?? '',
          'savedAt': FieldValue.serverTimestamp(),
        });
        await storyRef.set(
          {
            FirestoreStoryFields.saves: FieldValue.increment(1),
            FirestoreStoryFields.savedBy: FieldValue.arrayUnion([userId]),
          },
          SetOptions(merge: true),
        );
      }
    } catch (error) {
      debugPrint('Saved story mirror update skipped: $error');
    }

    return isNowSaved;
  }

  Future<void> addComment({
    required String storyId,
    required String userId,
    required String userName,
    required String text,
  }) async {
    final storyRef = _core.storyRef(storyId);
    final storySnap = await storyRef.get();
    final storyTitle =
        (storySnap.data()?[FirestoreStoryFields.title] as String?) ?? '';
    final moderation = ContentModerationService().moderateWithSurface(
      ModerationSurface.comment,
      text,
      storyExcerpt: storyTitle,
    );
    if (!moderation.isSafe) {
      throw ArgumentError(ContentModerationService.childFriendlyWarning);
    }
    final geminiSafe = await _geminiService.moderateContent(text);
    if (!geminiSafe) {
      throw ArgumentError(ContentModerationService.childFriendlyWarning);
    }

    final commentRef = storyRef.collection(FirestoreCollections.comments).doc();
    final notificationRef =
        _core.db.collection(FirestoreCollections.notifications).doc();

    await _core.db.runTransaction((tx) async {
      final storySnap = await tx.get(storyRef);
      final storyData = storySnap.data() ?? {};
      final ownerId = storyData[FirestoreStoryFields.authorId] as String?;
      final title =
          (storyData[FirestoreStoryFields.title] as String?) ?? 'your story';
      DocumentSnapshot<Map<String, dynamic>>? ownerSnap;
      if (ownerId != null && ownerId != userId) {
        ownerSnap = await tx.get(_core.userRef(ownerId));
      }

      tx.set(commentRef, {
        FirestoreStoryFields.userId: userId,
        FirestoreStoryFields.userName: userName,
        FirestoreStoryFields.text: text,
        FirestoreStoryFields.moderation: {
          FirestoreStoryFields.isSafe: true,
          FirestoreStoryFields.flagReason: null,
        },
        FirestoreStoryFields.createdAt: FieldValue.serverTimestamp(),
      });

      tx.set(
        storyRef,
        {
          FirestoreStoryFields.comments: FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );

      if (ownerId != null &&
          ownerId != userId &&
          StoryCoreService.notificationsEnabled(ownerSnap?.data())) {
        tx.set(notificationRef, {
          'toUserId': ownerId,
          'fromUserId': userId,
          'fromUserName': userName,
          'type': 'comment',
          FirestoreStoryFields.storyId: storyId,
          'storyTitle': title,
          'message': '$userName commented on "$title"',
          'isRead': false,
          FirestoreStoryFields.createdAt: FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> deleteComment({
    required String storyId,
    required String commentId,
  }) async {
    final storyRef = _core.storyRef(storyId);
    final commentRef =
        storyRef.collection(FirestoreCollections.comments).doc(commentId);

    await _core.db.runTransaction((tx) async {
      tx.delete(commentRef);
      tx.set(
        storyRef,
        {
          FirestoreStoryFields.comments: FieldValue.increment(-1),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> addCommentReply({
    required String storyId,
    required String commentId,
    required String userId,
    required String userName,
    required String text,
  }) async {
    final storyRef = _core.storyRef(storyId);
    final storySnapPre = await storyRef.get();
    final storyTitle =
        (storySnapPre.data()?[FirestoreStoryFields.title] as String?) ?? '';
    final moderation = ContentModerationService().moderateWithSurface(
      ModerationSurface.reply,
      text,
      storyExcerpt: storyTitle,
    );
    if (!moderation.isSafe) {
      throw ArgumentError(ContentModerationService.childFriendlyWarning);
    }
    final geminiSafe = await _geminiService.moderateContent(text);
    if (!geminiSafe) {
      throw ArgumentError(ContentModerationService.childFriendlyWarning);
    }

    final commentRef = storyRef.collection(FirestoreCollections.comments).doc(commentId);
    final notificationRef =
        _core.db.collection(FirestoreCollections.notifications).doc();
    final replyData = {
      'id': _core.db.collection(FirestoreCollections.replyIds).doc().id,
      FirestoreStoryFields.userId: userId,
      FirestoreStoryFields.userName: userName,
      FirestoreStoryFields.text: text,
      FirestoreStoryFields.createdAt: Timestamp.now(),
    };

    await _core.db.runTransaction((tx) async {
      final storySnap = await tx.get(storyRef);
      final commentSnap = await tx.get(commentRef);
      final storyData = storySnap.data() ?? {};
      final commentData = commentSnap.data() ?? {};
      final commentOwnerId = commentData[FirestoreStoryFields.userId] as String?;
      final title =
          (storyData[FirestoreStoryFields.title] as String?) ?? 'your story';
      DocumentSnapshot<Map<String, dynamic>>? ownerSnap;
      if (commentOwnerId != null && commentOwnerId != userId) {
        ownerSnap = await tx.get(_core.userRef(commentOwnerId));
      }

      tx.set(
        commentRef,
        {
          FirestoreStoryFields.replies: FieldValue.arrayUnion([replyData]),
          FirestoreStoryFields.replyCount: FieldValue.increment(1),
          FirestoreStoryFields.updatedAt: FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (commentOwnerId != null &&
          commentOwnerId != userId &&
          StoryCoreService.notificationsEnabled(ownerSnap?.data())) {
        tx.set(notificationRef, {
          'toUserId': commentOwnerId,
          'fromUserId': userId,
          'fromUserName': userName,
          'type': 'comment_reply',
          FirestoreStoryFields.storyId: storyId,
          'storyTitle': title,
          'commentId': commentId,
          'message': '$userName replied to your comment on "$title"',
          'isRead': false,
          FirestoreStoryFields.createdAt: FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> toggleCommentReaction({
    required String storyId,
    required String commentId,
    required String userId,
    required String userName,
    required String emoji,
  }) async {
    final storyRef = _core.storyRef(storyId);
    final commentRef = storyRef.collection(FirestoreCollections.comments).doc(commentId);
    final reactionRef = storyRef
        .collection(FirestoreCollections.comments)
        .doc(commentId)
        .collection(FirestoreCollections.reactions)
        .doc(userId);
    final notificationRef =
        _core.db.collection(FirestoreCollections.notifications).doc();

    await _core.db.runTransaction((tx) async {
      final storySnap = await tx.get(storyRef);
      final commentSnap = await tx.get(commentRef);
      final reactionSnap = await tx.get(reactionRef);
      final storyData = storySnap.data() ?? {};
      final commentData = commentSnap.data() ?? {};
      final commentOwnerId = commentData[FirestoreStoryFields.userId] as String?;
      final title =
          (storyData[FirestoreStoryFields.title] as String?) ?? 'your story';
      final previousEmoji =
          reactionSnap.data()?[FirestoreStoryFields.emoji] as String?;
      DocumentSnapshot<Map<String, dynamic>>? ownerSnap;
      if (commentOwnerId != null && commentOwnerId != userId) {
        ownerSnap = await tx.get(_core.userRef(commentOwnerId));
      }

      if (reactionSnap.exists && previousEmoji == emoji) {
        tx.delete(reactionRef);
        return;
      }

      tx.set(
        reactionRef,
        {
          FirestoreStoryFields.userId: userId,
          FirestoreStoryFields.emoji: emoji,
          FirestoreStoryFields.updatedAt: FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (commentOwnerId != null &&
          commentOwnerId != userId &&
          previousEmoji != emoji &&
          StoryCoreService.notificationsEnabled(ownerSnap?.data())) {
        tx.set(notificationRef, {
          'toUserId': commentOwnerId,
          'fromUserId': userId,
          'fromUserName': userName,
          'type': 'comment_reaction',
          FirestoreStoryFields.storyId: storyId,
          'storyTitle': title,
          'commentId': commentId,
          FirestoreStoryFields.emoji: emoji,
          'message': '$userName reacted $emoji to your comment on "$title"',
          'isRead': false,
          FirestoreStoryFields.createdAt: FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> rateStory({
    required String storyId,
    required String userId,
    required String userName,
    required int rating,
  }) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError('Rating must be between 1 and 5.');
    }

    final storyRef = _core.storyRef(storyId);
    final ratingRef = storyRef.collection(FirestoreCollections.ratings).doc(userId);
    final notificationRef =
        _core.db.collection(FirestoreCollections.notifications).doc();

    await _core.db.runTransaction((tx) async {
      final storySnap = await tx.get(storyRef);
      final storyData = storySnap.data() ?? {};
      final ownerId = storyData[FirestoreStoryFields.authorId] as String?;
      final title =
          (storyData[FirestoreStoryFields.title] as String?) ?? 'your story';
      DocumentSnapshot<Map<String, dynamic>>? ownerSnap;
      if (ownerId != null && ownerId != userId) {
        ownerSnap = await tx.get(_core.userRef(ownerId));
      }

      if (ownerId == userId) {
        throw StateError('You cannot rate your own story.');
      }

      final ratingSnap = await tx.get(ratingRef);
      final oldRating = ratingSnap.exists
          ? StoryCoreService.readInt(
              ratingSnap.data()?[FirestoreStoryFields.rating],
            )
          : null;
      final currentTotal =
          StoryCoreService.readInt(storyData[FirestoreStoryFields.ratingTotal]);
      final currentCount =
          StoryCoreService.readInt(storyData[FirestoreStoryFields.ratingCount]);

      final nextTotal = oldRating == null
          ? currentTotal + rating
          : currentTotal - oldRating + rating;
      final nextCount = oldRating == null ? currentCount + 1 : currentCount;
      final nextAverage = nextCount == 0 ? 0.0 : nextTotal / nextCount;

      tx.set(
        ratingRef,
        {
          FirestoreStoryFields.userId: userId,
          FirestoreStoryFields.rating: rating,
          FirestoreStoryFields.createdAt: ratingSnap.exists
              ? (ratingSnap.data()?[FirestoreStoryFields.createdAt])
              : FieldValue.serverTimestamp(),
          FirestoreStoryFields.updatedAt: FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      tx.set(
        storyRef,
        {
          FirestoreStoryFields.ratingTotal: nextTotal,
          FirestoreStoryFields.ratingCount: nextCount,
          FirestoreStoryFields.averageRating: nextAverage,
        },
        SetOptions(merge: true),
      );

      if (ownerId != null &&
          ownerId != userId &&
          StoryCoreService.notificationsEnabled(ownerSnap?.data())) {
        tx.set(notificationRef, {
          'toUserId': ownerId,
          'fromUserId': userId,
          'fromUserName': userName,
          'type': 'rating',
          FirestoreStoryFields.storyId: storyId,
          'storyTitle': title,
          'message': '$userName rated "$title" $rating stars',
          'isRead': false,
          FirestoreStoryFields.createdAt: FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Stream<QuerySnapshot> getComments(String storyId) {
    return _core
        .storyRef(storyId)
        .collection(FirestoreCollections.comments)
        .orderBy(FirestoreStoryFields.createdAt, descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getCommentReactions({
    required String storyId,
    required String commentId,
  }) {
    return _core
        .storyRef(storyId)
        .collection(FirestoreCollections.comments)
        .doc(commentId)
        .collection(FirestoreCollections.reactions)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserRating({
    required String storyId,
    required String userId,
  }) {
    return _core
        .storyRef(storyId)
        .collection(FirestoreCollections.ratings)
        .doc(userId)
        .snapshots();
  }
}
