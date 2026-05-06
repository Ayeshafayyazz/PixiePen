import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/firestore_keys.dart';
import 'story_core_service.dart';

class StoryStreamService {
  StoryStreamService(this._core);

  final StoryCoreService _core;

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
