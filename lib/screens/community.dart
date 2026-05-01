import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'ebook_screen.dart';
import 'my_stories_screen.dart';
import 'profile_screen.dart';
import 'theme.dart';
import 'write_story_screen.dart';
import '../services/content_moderation_service.dart';

DateTime _readTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.fromMillisecondsSinceEpoch(0);
}

/// =============================================================================
/// FIRESTORE SERVICE
/// =============================================================================

class StoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> toggleLike({
    required String storyId,
    required String userId,
    required String userName,
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
        likes--;
      } else {
        likedBy.add(userId);
        likes++;

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

  Future<void> addComment({
    required String storyId,
    required String userId,
    required String userName,
    required String text,
  }) async {
    final moderation = ContentModerationService().moderateText(text);
    if (!moderation.isSafe) {
      throw ArgumentError(ContentModerationService.childFriendlyWarning);
    }

    final storyRef = _db.collection('stories').doc(storyId);
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

  Future<void> deleteComment({
    required String storyId,
    required String commentId,
  }) async {
    final storyRef = _db.collection('stories').doc(storyId);
    final commentRef = storyRef.collection('comments').doc(commentId);

    await _db.runTransaction((tx) async {
      tx.delete(commentRef);
      tx.set(
          storyRef,
          {
            'comments': FieldValue.increment(-1),
          },
          SetOptions(merge: true));
    });
  }

  Stream<QuerySnapshot> getComments(String storyId) {
    return _db
        .collection('stories')
        .doc(storyId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}

/// =============================================================================
/// MODELS
/// =============================================================================

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
  final bool likedByMe;
  final Color accent;
  final String imageUrl;
  final List<Comment> commentList;

  const StoryPost({
    required this.id,
    required this.author,
    required this.handle,
    required this.title,
    required this.excerpt,
    required this.likes,
    required this.comments,
    required this.likedByMe,
    required this.accent,
    required this.imageUrl,
    this.commentList = const [],
  });

  StoryPost toggleLike() => StoryPost(
        id: id,
        author: author,
        handle: handle,
        title: title,
        excerpt: excerpt,
        likes: likedByMe ? likes - 1 : likes + 1,
        comments: comments,
        likedByMe: !likedByMe,
        accent: accent,
        imageUrl: imageUrl,
        commentList: commentList,
      );
}

/// =============================================================================
/// CHARACTER MAPPING MODEL
/// =============================================================================

class CharacterMapping {
  final Map<String, String> pronounMap;
  final Map<String, String> nameMap;
  final String label;

  CharacterMapping({
    required this.pronounMap,
    required this.nameMap,
    required this.label,
  });

  CharacterMapping copyWith({
    Map<String, String>? pronounMap,
    Map<String, String>? nameMap,
    String? label,
  }) {
    return CharacterMapping(
      pronounMap: pronounMap ?? this.pronounMap,
      nameMap: nameMap ?? this.nameMap,
      label: label ?? this.label,
    );
  }
}

/// =============================================================================
/// PERSPECTIVE ENGINE (Business Logic)
/// =============================================================================

enum PerspectiveType { firstPerson, secondPerson, thirdPerson, custom }

class PerspectiveEngine {
  static const Map<PerspectiveType, String> labels = {
    PerspectiveType.firstPerson: 'First Person (I)',
    PerspectiveType.secondPerson: 'Second Person (You)',
    PerspectiveType.thirdPerson: 'Third Person (They)',
    PerspectiveType.custom: 'Custom Characters',
  };

  /// Default character mappings
  static CharacterMapping getDefaultMapping(int perspectiveIndex) {
    switch (perspectiveIndex) {
      case 0:
        return CharacterMapping(
          pronounMap: {
            'you': 'I',
            'your': 'my',
            'yours': 'mine',
            'they': 'I',
            'their': 'my',
            'them': 'me',
          },
          nameMap: {},
          label: 'First Person (I)',
        );
      case 1:
        return CharacterMapping(
          pronounMap: {
            'I': 'you',
            'my': 'your',
            'mine': 'yours',
            'we': 'you',
            'me': 'you',
            'us': 'you',
          },
          nameMap: {},
          label: 'Second Person (You)',
        );
      case 2:
        return CharacterMapping(
          pronounMap: {
            'I': 'they',
            'you': 'they',
            'my': 'their',
            'your': 'their',
            'me': 'them',
            'yours': 'theirs',
            'we': 'they',
            'us': 'them',
          },
          nameMap: {},
          label: 'Third Person (They)',
        );
      default:
        return CharacterMapping(
          pronounMap: {},
          nameMap: {},
          label: 'Original',
        );
    }
  }

  /// Transform text with character mapping
  static String transform(String text, CharacterMapping mapping) {
    String result = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    /// Apply name replacements first (case-sensitive)
    mapping.nameMap.forEach((original, replacement) {
      result = result.replaceAll(original, replacement);
    });

    /// Apply pronoun replacements (case-insensitive)
    mapping.pronounMap.forEach((original, replacement) {
      result = result.replaceAll(
        RegExp(r'\b' + original + r'\b', caseSensitive: false),
        replacement,
      );
    });

    return result;
  }
}

/// =============================================================================
/// VIEW MODEL
/// =============================================================================

class StoryReaderViewModel extends ChangeNotifier {
  final StoryPost originalPost;
  late StoryPost displayPost;
  int currentPerspectiveIndex = 0;
  late CharacterMapping currentMapping;
  bool isCustomizing = false;

  StoryReaderViewModel(this.originalPost) {
    displayPost = originalPost;
    currentMapping = PerspectiveEngine.getDefaultMapping(0);
  }

  void setPerspective(int index) {
    currentPerspectiveIndex = index;
    currentMapping = PerspectiveEngine.getDefaultMapping(index);
    _updateDisplayPost();
  }

  void updateCharacterMapping(Map<String, String> nameMap) {
    currentMapping = currentMapping.copyWith(nameMap: nameMap);
    _updateDisplayPost();
  }

  void resetPerspective() {
    currentPerspectiveIndex = 0;
    currentMapping = PerspectiveEngine.getDefaultMapping(0);
    _updateDisplayPost();
  }

  void _updateDisplayPost() {
    displayPost = StoryPost(
      id: originalPost.id,
      author: originalPost.author,
      handle: originalPost.handle,
      title: originalPost.title,
      excerpt:
          PerspectiveEngine.transform(originalPost.excerpt, currentMapping),
      likes: originalPost.likes,
      comments: originalPost.comments,
      likedByMe: originalPost.likedByMe,
      accent: originalPost.accent,
      imageUrl: originalPost.imageUrl,
      commentList: originalPost.commentList,
    );
    notifyListeners();
  }

  void toggleCustomizing() {
    isCustomizing = !isCustomizing;
    notifyListeners();
  }
}

/// =============================================================================
/// CHARACTER CUSTOMIZATION DIALOG
/// =============================================================================

class CharacterCustomizationDialog extends StatefulWidget {
  final CharacterMapping currentMapping;
  final Function(Map<String, String>) onApply;

  const CharacterCustomizationDialog({
    super.key,
    required this.currentMapping,
    required this.onApply,
  });

  @override
  State<CharacterCustomizationDialog> createState() =>
      _CharacterCustomizationDialogState();
}

class _CharacterCustomizationDialogState
    extends State<CharacterCustomizationDialog> {
  late Map<String, TextEditingController> controllers;

  @override
  void initState() {
    super.initState();
    controllers = {
      'protagonist': TextEditingController(
        text: widget.currentMapping.nameMap['protagonist'] ?? 'Alex',
      ),
      'sidekick': TextEditingController(
        text: widget.currentMapping.nameMap['sidekick'] ?? 'Sam',
      ),
      'antagonist': TextEditingController(
        text: widget.currentMapping.nameMap['antagonist'] ?? 'Jordan',
      ),
    };
  }

  @override
  void dispose() {
    controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Customize Character Names'),
      contentPadding: const EdgeInsets.all(20),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Replace character names in the story:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ..._buildCharacterFields(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
          ),
          onPressed: () {
            final nameMap = <String, String>{};
            controllers.forEach((key, controller) {
              if (controller.text.isNotEmpty) {
                nameMap[key] = controller.text;
              }
            });
            widget.onApply(nameMap);
            Navigator.pop(context);
          },
          child: const Text('Apply', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  List<Widget> _buildCharacterFields() {
    final characters = [
      {'key': 'protagonist', 'label': 'Protagonist', 'hint': 'e.g., Alice'},
      {'key': 'sidekick', 'label': 'Sidekick', 'hint': 'e.g., Bob'},
      {'key': 'antagonist', 'label': 'Antagonist', 'hint': 'e.g., Carol'},
    ];

    return characters.map((char) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controllers[char['key']]!,
          decoration: InputDecoration(
            labelText: char['label'],
            hintText: char['hint'],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.person, color: Colors.purple),
          ),
        ),
      );
    }).toList();
  }
}

/// =============================================================================
/// COMMUNITY SCREEN
/// =============================================================================

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _selectedIndex = 0;
  static const String _storiesCollection = 'stories';
  final StoryService _service = StoryService();
  final ContentModerationService _moderationService =
      ContentModerationService();
  final TextEditingController _authorSearchController = TextEditingController();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  User? _user;
  String _userId = "";
  String _userName = "";
  String _authorSearchQuery = "";
  bool _isSearchingAuthors = false;
  String? _myStoriesInitialStatus;
  String? _myStoriesHighlightedStoryId;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    if (_user != null) {
      _userId = _user!.uid;
      // Set fallback username immediately
      _userName =
          _user!.displayName ?? _user!.email?.split('@').first ?? 'User';
      // Try to fetch the actual username from Firestore
      _fetchUserName();
    }
  }

  @override
  void dispose() {
    _authorSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserName() async {
    if (_user == null) return;
    try {
      final snap = await _db.collection('users').doc(_user!.uid).get();
      if (mounted) {
        setState(() {
          final firestoreUsername = snap.data()?['username'] as String?;
          if (firestoreUsername != null && firestoreUsername.isNotEmpty) {
            _userName = firestoreUsername;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching username: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildCommunityFeed(),
      const WriteStoryScreen(),
      const EbookScreen(),
      MyStoriesScreen(
        key: ValueKey(
          '${_myStoriesInitialStatus ?? 'published'}-${_myStoriesHighlightedStoryId ?? ''}',
        ),
        initialStatus: _myStoriesInitialStatus,
        highlightedStoryId: _myStoriesHighlightedStoryId,
      ),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: kAppPrimary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        iconSize: 24,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_outlined),
            activeIcon: Icon(Icons.edit),
            label: 'Write',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'E-Books',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmarks_outlined),
            activeIcon: Icon(Icons.bookmarks),
            label: 'My Stories',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityFeed() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7B1FA2),
        title: const _BrandTitle(),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _isSearchingAuthors ? 'Close search' : 'Search authors',
            onPressed: _toggleAuthorSearch,
            icon: Icon(
              _isSearchingAuthors ? Icons.close : Icons.search,
              color: Colors.white,
            ),
          ),
          _NotificationBell(
            userId: _userId,
            onStoryNotificationTap: _handleStoryNotificationTap,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: Colors.purple,
        onRefresh: () async {
          await Future<void>.delayed(const Duration(milliseconds: 400));
          if (!mounted) return;
          setState(() {});
        },
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(_storiesCollection)
              .where('status', isEqualTo: 'published')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final publishedDocs = snapshot.data!.docs.toList()
              ..sort((a, b) {
                final aDate = _readTimestamp(a.data()['createdAt']);
                final bDate = _readTimestamp(b.data()['createdAt']);
                return bDate.compareTo(aDate);
              });

            if (publishedDocs.isEmpty) {
              return const Center(child: Text('No stories yet'));
            }

            final docs = publishedDocs
                .where((doc) => _matchesAuthorSearch(doc.data()))
                .toList();

            return Column(
              children: [
                if (_isSearchingAuthors)
                  _AuthorSearchSection(
                    controller: _authorSearchController,
                    onChanged: (value) {
                      setState(() => _authorSearchQuery = value);
                    },
                    onClear: () {
                      setState(() {
                        _authorSearchController.clear();
                        _authorSearchQuery = "";
                      });
                    },
                  ),
                if (docs.isEmpty)
                  Expanded(
                    child: _AuthorSearchEmptyState(query: _authorSearchQuery),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();
                        final storyId = doc.id;

                        final title = (data['title'] as String?) ?? 'Untitled';
                        final body = (data['body'] as String?) ?? '';
                        final cover = (data['coverUrl'] as String?);
                        final author = (data['authorName'] as String?) ??
                            (data['authorId'] as String?) ??
                            'Unknown';
                        final handle = (data['handle'] as String?) ??
                            (author.replaceAll(' ', '').toLowerCase());
                        final likes = (data['likes'] as int?) ?? 0;
                        final comments = (data['comments'] as int?) ?? 0;
                        final imageUrl = cover != null && cover.isNotEmpty
                            ? cover
                            : 'https://picsum.photos/seed/$storyId/600/300';

                        final likedBy = (data['likedBy'] as List?) ?? [];
                        final likedByMe = likedBy.contains(_userId);

                        final post = StoryPost(
                          id: storyId,
                          author: author,
                          handle: handle,
                          title: title,
                          excerpt: body,
                          likes: likes,
                          comments: comments,
                          likedByMe: likedByMe,
                          accent: const Color(0xFF7B1FA2),
                          imageUrl: imageUrl,
                        );

                        return StoryCard(
                          post: post,
                          service: _service,
                          userId: _userId.isEmpty ? _user?.uid ?? '' : _userId,
                          userName: _userName.isEmpty
                              ? (_user?.displayName ?? 'User')
                              : _userName,
                          onLike: () async {
                            if (_userId.isNotEmpty) {
                              await _service.toggleLike(
                                storyId: storyId,
                                userId: _userId,
                                userName: _userName.isEmpty
                                    ? (_user?.displayName ??
                                        _user?.email?.split('@').first ??
                                        'User')
                                    : _userName,
                              );
                            }
                          },
                          onOpen: () => _openStory(context, post),
                          onComment: () => _openComments(context, storyId),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _toggleAuthorSearch() {
    setState(() {
      _isSearchingAuthors = !_isSearchingAuthors;
      if (!_isSearchingAuthors) {
        _authorSearchController.clear();
        _authorSearchQuery = "";
      }
    });
  }

  bool _matchesAuthorSearch(Map<String, dynamic> data) {
    final query = _authorSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    final authorName = ((data['authorName'] as String?) ?? '').toLowerCase();
    final handle = ((data['handle'] as String?) ?? '').toLowerCase();

    return authorName.contains(query) || handle.contains(query);
  }

  void _openStory(BuildContext context, StoryPost post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryReaderPage(
          post: post,
          service: _service,
          userId: _userId,
          userName: _userName,
        ),
      ),
    );
  }

  Future<void> _handleStoryNotificationTap(
    String storyId,
    String type,
  ) async {
    if (type == 'approval_result') {
      final snap = await _db.collection('stories').doc(storyId).get();
      if (!mounted) return;
      final data = snap.data() ?? {};
      final status = data['status'] as String?;
      final approvalStatus = data['approvalStatus'] as String?;
      final targetStatus = approvalStatus == 'rejected'
          ? 'rejected'
          : status == 'published'
              ? 'published'
              : status == 'pending_parent_approval'
                  ? 'pending_parent_approval'
                  : 'draft';

      setState(() {
        _myStoriesInitialStatus = targetStatus;
        _myStoriesHighlightedStoryId = storyId;
        _selectedIndex = 3;
      });
      return;
    }

    final snap = await _db.collection('stories').doc(storyId).get();
    if (!mounted) return;

    if (!snap.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story is no longer available.')),
      );
      return;
    }

    final data = snap.data() ?? {};
    final status = data['status'] as String?;
    final authorId = data['authorId'] as String?;
    if (status != 'published' && authorId != _userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story is not available yet.')),
      );
      return;
    }

    final title = (data['title'] as String?) ?? 'Untitled';
    final body = (data['body'] as String?) ?? '';
    final author = (data['authorName'] as String?) ?? authorId ?? 'Unknown';
    final handle =
        (data['handle'] as String?) ?? author.replaceAll(' ', '').toLowerCase();
    final cover = data['coverUrl'] as String?;
    final likedBy = (data['likedBy'] as List?) ?? [];

    _openStory(
      context,
      StoryPost(
        id: storyId,
        author: author,
        handle: handle,
        title: title,
        excerpt: body,
        likes: _readInt(data['likes']),
        comments: _readInt(data['comments']),
        likedByMe: likedBy.contains(_userId),
        accent: kAppPrimary,
        imageUrl: cover != null && cover.isNotEmpty
            ? cover
            : 'https://picsum.photos/seed/$storyId/600/300',
      ),
    );
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  void _openComments(BuildContext context, String storyId) {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 12,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              children: [
                Container(
                  height: 4,
                  width: 40,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Comments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _service.getComments(storyId),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data!.docs;

                      if (docs.isEmpty) {
                        return const Center(child: Text("No comments yet"));
                      }

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, i) {
                          final data = docs[i].data() as Map<String, dynamic>;
                          final isOwner = data['userId'] == _userId;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.purple,
                                  radius: 18,
                                  child: Text(
                                    (data['userName'] as String?)?.isNotEmpty ==
                                            true
                                        ? (data['userName'] as String)[0]
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['userName'] ?? 'Unknown',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(data['text'] ?? ''),
                                    ],
                                  ),
                                ),
                                if (isOwner)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                    onPressed: () async {
                                      await _service.deleteComment(
                                        storyId: storyId,
                                        commentId: docs[i].id,
                                      );
                                    },
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.purple),
                      onPressed: () async {
                        final commentText = controller.text.trim();
                        if (commentText.isNotEmpty && _userId.isNotEmpty) {
                          final moderation =
                              _moderationService.moderateText(commentText);
                          if (!moderation.isSafe) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  ContentModerationService.childFriendlyWarning,
                                ),
                              ),
                            );
                            return;
                          }

                          // Use current username, fallback if empty
                          String commentUserName = _userName.isNotEmpty
                              ? _userName
                              : (_user?.displayName ??
                                  _user?.email?.split('@').first ??
                                  'User');

                          await _service.addComment(
                            storyId: storyId,
                            userId: _userId,
                            userName: commentUserName,
                            text: commentText,
                          );
                          controller.clear();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// =============================================================================
/// BRAND TITLE
/// =============================================================================

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Community',
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
    );
  }
}

class _AuthorSearchSection extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _AuthorSearchSection({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search by author name',
          prefixIcon: const Icon(Icons.person_search, color: kAppPrimary),
          suffixIcon: controller.text.trim().isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  icon: const Icon(Icons.close),
                ),
          filled: true,
          fillColor: const Color(0xFFF7F3FF),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2D9F3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2D9F3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: kAppPrimary, width: 1.4),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _AuthorSearchEmptyState extends StatelessWidget {
  final String query;

  const _AuthorSearchEmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    final searchText = query.trim();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search,
              size: 58,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 14),
            const Text(
              'No authors found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              searchText.isEmpty
                  ? 'Try searching by an author name or handle.'
                  : 'No published stories match "$searchText".',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final String userId;
  final void Function(String storyId, String type)? onStoryNotificationTap;

  const _NotificationBell({
    required this.userId,
    this.onStoryNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) {
      return const IconButton(
        tooltip: 'Notifications',
        onPressed: null,
        icon: Icon(Icons.notifications_none, color: Colors.white),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('toUserId', isEqualTo: userId)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final unreadCount = docs
            .where((doc) => doc.data()['isRead'] != true)
            .length
            .clamp(0, 99);

        return IconButton(
          tooltip: 'Notifications',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NotificationScreen(
                  userId: userId,
                  onStoryNotificationTap: onStoryNotificationTap,
                ),
              ),
            );
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none, color: Colors.white),
              if (unreadCount > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                    child: Text(
                      '$unreadCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class NotificationScreen extends StatefulWidget {
  final String userId;
  final ValueChanged<String>? onParentApprovalTap;
  final void Function(String storyId, String type)? onStoryNotificationTap;

  const NotificationScreen({
    super.key,
    required this.userId,
    this.onParentApprovalTap,
    this.onStoryNotificationTap,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _markedRead = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markAllRead());
  }

  Future<void> _markAllRead() async {
    if (_markedRead) return;
    _markedRead = true;

    final snapshot = await _db
        .collection('notifications')
        .where('toUserId', isEqualTo: widget.userId)
        .get();

    final batch = _db.batch();
    var hasUpdates = false;

    for (final doc in snapshot.docs) {
      if (doc.data()['isRead'] != true) {
        batch.update(doc.reference, {'isRead': true});
        hasUpdates = true;
      }
    }

    if (hasUpdates) {
      await batch.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FF),
      appBar: AppBar(
        backgroundColor: kAppPrimary,
        foregroundColor: Colors.white,
        title: const Text('Notifications'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _db
            .collection('notifications')
            .where('toUserId', isEqualTo: widget.userId)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kAppPrimary),
            );
          }

          final docs = (snapshot.data?.docs ?? []).toList()
            ..sort((a, b) {
              final aDate = _readDate(a.data()['createdAt']);
              final bDate = _readDate(b.data()['createdAt']);
              return bDate.compareTo(aDate);
            });

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No notifications yet',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final type = data['type'] as String? ?? '';
              final isRead = data['isRead'] == true;
              final message =
                  data['message'] as String? ?? _fallbackMessage(type);
              final icon = _notificationIcon(type);
              final color = _notificationColor(type);

              final storyId = data['storyId'] as String?;
              final canOpenApproval =
                  type == 'parent_approval' && storyId != null;
              final canOpenStory = storyId != null &&
                  (type == 'like' ||
                      type == 'comment' ||
                      type == 'approval_result');

              return InkWell(
                onTap: canOpenApproval
                    ? () {
                        Navigator.pop(context);
                        widget.onParentApprovalTap?.call(storyId);
                      }
                    : canOpenStory
                        ? () {
                            Navigator.pop(context);
                            widget.onStoryNotificationTap?.call(storyId, type);
                          }
                        : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isRead
                          ? const Color(0xFFE2D9F3)
                          : kAppPrimary.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: color,
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              canOpenApproval
                                  ? 'Tap to review'
                                  : canOpenStory
                                      ? 'Tap to open'
                                      : _formatDate(data['createdAt']),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: kAppPrimary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _formatDate(dynamic value) {
    final date = _readDate(value);
    if (date.millisecondsSinceEpoch == 0) return 'Just now';
    return '${date.month}/${date.day}/${date.year}';
  }

  static String _fallbackMessage(String type) {
    if (type == 'comment') return 'Someone commented on your story';
    if (type == 'parent_approval') return 'A story is waiting for approval';
    if (type == 'approval_result') return 'Your story approval was updated';
    return 'Someone liked your story';
  }

  static IconData _notificationIcon(String type) {
    if (type == 'comment') return Icons.chat_bubble_outline;
    if (type == 'parent_approval') return Icons.fact_check_outlined;
    if (type == 'approval_result') return Icons.verified_outlined;
    return Icons.favorite;
  }

  static Color _notificationColor(String type) {
    if (type == 'comment') return kAppPrimary;
    if (type == 'parent_approval') return Colors.orange.shade800;
    if (type == 'approval_result') return Colors.green.shade700;
    return Colors.redAccent;
  }
}

/// =============================================================================
/// STORY CARD
/// =============================================================================

class StoryCard extends StatelessWidget {
  final StoryPost post;
  final StoryService service;
  final String userId;
  final String userName;
  final VoidCallback onLike;
  final VoidCallback onOpen;
  final VoidCallback onComment;

  const StoryCard({
    super.key,
    required this.post,
    required this.service,
    required this.userId,
    required this.userName,
    required this.onLike,
    required this.onOpen,
    required this.onComment,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (post.imageUrl.isNotEmpty)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: Image.network(
                        post.imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            color: Colors.grey[300],
                            child: const Icon(Icons.image_not_supported),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 12,
                      right: 12,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFF7B1FA2),
                            child: Text(
                              post.author.isNotEmpty ? post.author[0] : '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.author,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '@${post.handle}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      post.excerpt,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            post.likedByMe
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: post.likedByMe ? Colors.red : Colors.purple,
                          ),
                          onPressed: onLike,
                        ),
                        Text("${post.likes}"),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.purple,
                          ),
                          onPressed: onComment,
                        ),
                        Text("${post.comments}"),
                        const Spacer(),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: onOpen,
                          icon: const Icon(Icons.menu_book, size: 18),
                          label: const Text("Read"),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// =============================================================================
/// STORY READER PAGE (Enhanced with Perspective Shift & Character Names)
/// =============================================================================

class StoryReaderPage extends StatefulWidget {
  final StoryPost post;
  final StoryService service;
  final String userId;
  final String userName;

  const StoryReaderPage({
    super.key,
    required this.post,
    required this.service,
    required this.userId,
    required this.userName,
  });

  @override
  State<StoryReaderPage> createState() => _StoryReaderPageState();
}

class _StoryReaderPageState extends State<StoryReaderPage> {
  late StoryReaderViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = StoryReaderViewModel(widget.post);
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  void _showPerspectiveMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose Perspective',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _perspectiveButton(
                label: 'First Person (I)',
                index: 0,
              ),
              _perspectiveButton(
                label: 'Second Person (You)',
                index: 1,
              ),
              _perspectiveButton(
                label: 'Third Person (They)',
                index: 2,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.refresh, color: Colors.white),
                label:
                    const Text('Reset', style: TextStyle(color: Colors.white)),
                onPressed: () {
                  viewModel.resetPerspective();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _perspectiveButton({required String label, required int index}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: viewModel.currentPerspectiveIndex == index
              ? Colors.purple
              : Colors.grey[200],
          foregroundColor: viewModel.currentPerspectiveIndex == index
              ? Colors.white
              : Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: () {
          viewModel.setPerspective(index);
          Navigator.pop(context);
        },
        child: Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.purple,
        title: Text(
          widget.post.title,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Perspective & Characters',
            onPressed: _showPerspectiveMenu,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AuthorRow(
                  name: viewModel.displayPost.author,
                  handle: viewModel.displayPost.handle,
                ),
                const SizedBox(height: 12),
                if (viewModel.displayPost.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      viewModel.displayPost.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 220,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(height: 220, color: Colors.grey[200]),
                    ),
                  ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      viewModel.displayPost.excerpt,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(height: 1.6),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// =============================================================================
/// AUTHOR ROW
/// =============================================================================

class _AuthorRow extends StatelessWidget {
  final String name;
  final String handle;

  const _AuthorRow({required this.name, required this.handle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF7B1FA2),
            child: Text(
              name.isNotEmpty ? name[0] : '?',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '@$handle',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        overflow: TextOverflow.ellipsis,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
