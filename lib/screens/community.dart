import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'ebook_screen.dart';
import 'my_stories_screen.dart';
import 'profile_screen.dart';
import 'theme.dart';
import 'write_story_screen.dart';
import '../services/content_moderation_service.dart';

/// =============================================================================
/// FIRESTORE SERVICE
/// =============================================================================

class StoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
        likes--;
      } else {
        likedBy.add(userId);
        likes++;
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

    await _db.runTransaction((tx) async {
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
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  User? _user;
  String _userId = "";
  String _userName = "";

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
      print('Error fetching username: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildCommunityFeed(),
      const WriteStoryScreen(),
      const EbookScreen(),
      const MyStoriesScreen(),
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
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return const Center(child: Text('No stories yet'));
            }

            return ListView.builder(
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
                      );
                    }
                  },
                  onOpen: () => _openStory(context, post),
                  onComment: () => _openComments(context, storyId),
                );
              },
            );
          },
        ),
      ),
    );
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
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
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

  void _showCharacterCustomization() {
    showDialog(
      context: context,
      builder: (context) {
        return CharacterCustomizationDialog(
          currentMapping: viewModel.currentMapping,
          onApply: (nameMap) {
            viewModel.updateCharacterMapping(nameMap);
          },
        );
      },
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
