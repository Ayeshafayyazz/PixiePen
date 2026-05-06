import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../services/story_service.dart';

class StoryController extends ChangeNotifier {
  StoryController({StoryService? storyService})
      : _storyService = storyService ?? StoryService();

  final StoryService _storyService;
  StreamSubscription? _storiesSubscription;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _stories = const [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _storyDocs = const [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get stories => List.unmodifiable(_stories);
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get storyDocs =>
      List.unmodifiable(_storyDocs);

  Future<void> fetchStories({
    String? authorId,
    String? status,
    String? parentEmail,
  }) async {
    _setLoading(true);
    _setError(null);

    await _storiesSubscription?.cancel();
    _storiesSubscription = _storyService
        .fetchStories(
          authorId: authorId,
          status: status,
          parentEmail: parentEmail,
        )
        .listen(
          (snapshot) {
            _storyDocs = snapshot.docs;
            _stories = snapshot.docs
                .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
                .toList();
            _setLoading(false);
          },
          onError: (Object error) {
            _setError(error.toString());
            _setLoading(false);
          },
        );
  }

  Future<void> createStory({
    required Map<String, dynamic> data,
    String? storyId,
  }) async {
    await _runAction(() async {
      await _storyService.createStory(data: data, storyId: storyId);
    });
  }

  Future<void> updateStory({
    required String storyId,
    required Map<String, dynamic> data,
  }) async {
    await _runAction(() async {
      await _storyService.updateStory(storyId: storyId, data: data);
    });
  }

  Future<void> deleteStory(String storyId) async {
    await _runAction(() async {
      await _storyService.deleteStory(storyId);
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    _setLoading(true);
    _setError(null);
    try {
      await action();
    } catch (error) {
      _setError(error.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    if (_errorMessage == message) return;
    _errorMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _storiesSubscription?.cancel();
    super.dispose();
  }
}
