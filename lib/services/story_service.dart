import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/repositories/story_repository.dart';

class StoryService {
  StoryService({FirebaseFirestore? firestore})
      : _repository = StoryRepository(firestore: firestore);

  final StoryRepository _repository;

  Stream<QuerySnapshot<Map<String, dynamic>>> fetchStories({
    String? authorId,
    String? status,
    String? parentEmail,
  }) {
    return _repository.fetchStories(
      authorId: authorId,
      status: status,
      parentEmail: parentEmail,
    );
  }

  Future<void> createStory({
    required Map<String, dynamic> data,
    String? storyId,
  }) async {
    await _repository.createStory(data: data, storyId: storyId);
  }

  Future<void> updateStory({
    required String storyId,
    required Map<String, dynamic> data,
  }) async {
    await _repository.updateStory(storyId: storyId, data: data);
  }

  Future<void> deleteStory(String storyId) async {
    await _repository.deleteStory(storyId);
  }

  Future<void> toggleLike({
    required String storyId,
    required String userId,
    required String userName,
  }) async {
    await _repository.toggleLike(
      storyId: storyId,
      userId: userId,
      userName: userName,
    );
  }

  Future<bool> toggleSave({
    required String storyId,
    required String userId,
  }) async {
    return _repository.toggleSave(storyId: storyId, userId: userId);
  }

  Future<void> addComment({
    required String storyId,
    required String userId,
    required String userName,
    required String text,
  }) async {
    await _repository.addComment(
      storyId: storyId,
      userId: userId,
      userName: userName,
      text: text,
    );
  }

  Future<void> deleteComment({
    required String storyId,
    required String commentId,
  }) async {
    await _repository.deleteComment(storyId: storyId, commentId: commentId);
  }

  Future<void> addCommentReply({
    required String storyId,
    required String commentId,
    required String userId,
    required String userName,
    required String text,
  }) async {
    await _repository.addCommentReply(
      storyId: storyId,
      commentId: commentId,
      userId: userId,
      userName: userName,
      text: text,
    );
  }

  Future<void> toggleCommentReaction({
    required String storyId,
    required String commentId,
    required String userId,
    required String userName,
    required String emoji,
  }) async {
    await _repository.toggleCommentReaction(
      storyId: storyId,
      commentId: commentId,
      userId: userId,
      userName: userName,
      emoji: emoji,
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getCommentReactions({
    required String storyId,
    required String commentId,
  }) {
    return _repository.getCommentReactions(
      storyId: storyId,
      commentId: commentId,
    );
  }

  Future<void> rateStory({
    required String storyId,
    required String userId,
    required String userName,
    required int rating,
  }) async {
    await _repository.rateStory(
      storyId: storyId,
      userId: userId,
      userName: userName,
      rating: rating,
    );
  }

  Stream<QuerySnapshot> getComments(String storyId) {
    return _repository.getComments(storyId);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserRating({
    required String storyId,
    required String userId,
  }) {
    return _repository.getUserRating(storyId: storyId, userId: userId);
  }
}
