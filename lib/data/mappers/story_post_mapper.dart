import 'package:flutter/material.dart';

import '../../data/firestore_keys.dart';
import '../../domain/models/story_post.dart';
import '../../utils/story_content.dart';

class StoryPostMapper {
  static StoryPost fromFirestoreMap({
    required String storyId,
    required Map<String, dynamic> data,
    required String currentUserId,
    required Color accent,
    String fallbackAuthor = 'Unknown',
  }) {
    final title = (data[FirestoreStoryFields.title] as String?) ?? 'Untitled';
    final body = (data[FirestoreStoryFields.body] as String?) ?? '';
    final authorName =
        (data[FirestoreStoryFields.authorName] as String?) ?? fallbackAuthor;
    final handle = (data[FirestoreStoryFields.handle] as String?) ??
        authorName.replaceAll(' ', '').toLowerCase();
    final cover = data[FirestoreStoryFields.coverUrl] as String?;
    final likedBy = (data[FirestoreStoryFields.likedBy] as List?) ?? const [];
    final contentBlocks =
        StoryContentCodec.parseContent(data[FirestoreStoryFields.content]);

    return StoryPost(
      id: storyId,
      author: authorName,
      handle: handle,
      title: title,
      excerpt: body,
      likes: _readInt(data[FirestoreStoryFields.likes]),
      comments: _readInt(data[FirestoreStoryFields.comments]),
      ratingCount: _readInt(data[FirestoreStoryFields.ratingCount]),
      averageRating: _readDouble(data[FirestoreStoryFields.averageRating]),
      likedByMe: currentUserId.isNotEmpty && likedBy.contains(currentUserId),
      accent: accent,
      imageUrl: cover != null && cover.isNotEmpty
          ? cover
          : 'https://picsum.photos/seed/$storyId/600/300',
      contentBlocks: contentBlocks,
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _readDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
