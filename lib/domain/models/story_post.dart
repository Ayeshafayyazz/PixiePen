import 'package:flutter/material.dart';

class Comment {
  final String user;
  final String text;

  Comment({required this.user, required this.text});
}

class StoryPost {
  final String id;
  final String author;
  final String handle;
  final String title;
  final String excerpt;
  final int likes;
  final int comments;
  final int saves;
  final int ratingCount;
  final double averageRating;
  final bool likedByMe;
  final bool savedByMe;
  final Color accent;
  final String imageUrl;
  final List<Comment> commentList;
  final List<Map<String, dynamic>>? contentBlocks;

  const StoryPost({
    required this.id,
    required this.author,
    required this.handle,
    required this.title,
    required this.excerpt,
    required this.likes,
    required this.comments,
    this.saves = 0,
    this.ratingCount = 0,
    this.averageRating = 0,
    required this.likedByMe,
    this.savedByMe = false,
    required this.accent,
    required this.imageUrl,
    this.commentList = const [],
    this.contentBlocks,
  });

  StoryPost toggleLike() => StoryPost(
        id: id,
        author: author,
        handle: handle,
        title: title,
        excerpt: excerpt,
        likes: likedByMe ? likes - 1 : likes + 1,
        comments: comments,
        saves: saves,
        ratingCount: ratingCount,
        averageRating: averageRating,
        likedByMe: !likedByMe,
        savedByMe: savedByMe,
        accent: accent,
        imageUrl: imageUrl,
        commentList: commentList,
        contentBlocks: contentBlocks,
      );
}
