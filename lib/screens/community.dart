import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_tts/flutter_tts.dart';

import 'ebook_screen.dart';
import 'my_stories_screen.dart';
import 'pixie_dash_screen.dart';
import 'profile_screen.dart';
import 'public_profile_screen.dart';
import 'theme.dart';
import 'write_story_screen.dart';
import '../controllers/story_controller.dart';
import '../data/mappers/story_post_mapper.dart';
import '../domain/models/story_post.dart';
import '../services/follow_service.dart';
import '../services/gemini_service.dart';
import '../widgets/storage_image.dart';
import '../services/story_service.dart';
import '../services/content_moderation_service.dart';
import '../widgets/moderation_ui.dart';
import '../utils/story_content.dart';
import '../utils/story_search.dart';

DateTime _readTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.fromMillisecondsSinceEpoch(0);
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

  void setGeneratedPerspective({
    required int index,
    required String label,
    required String text,
  }) {
    currentPerspectiveIndex = index;
    currentMapping = CharacterMapping(
      pronounMap: const {},
      nameMap: const {},
      label: label,
    );
    final shiftedText = text.trim();
    displayPost = StoryPost(
      id: originalPost.id,
      authorId: originalPost.authorId,
      author: originalPost.author,
      handle: originalPost.handle,
      title: originalPost.title,
      excerpt: shiftedText,
      likes: originalPost.likes,
      comments: originalPost.comments,
      saves: originalPost.saves,
      ratingCount: originalPost.ratingCount,
      averageRating: originalPost.averageRating,
      likedByMe: originalPost.likedByMe,
      savedByMe: originalPost.savedByMe,
      accent: originalPost.accent,
      imageUrl: originalPost.imageUrl,
      commentList: originalPost.commentList,
      contentBlocks: [
        {
          'type': StoryContentCodec.typeText,
          'text': shiftedText,
        },
      ],
    );
    notifyListeners();
  }

  void _updateDisplayPost() {
    final blocks = originalPost.contentBlocks;
    final String excerpt;
    final List<Map<String, dynamic>>? outBlocks;
    if (blocks != null && blocks.isNotEmpty) {
      outBlocks = blocks.map((m) {
        final type = m['type'] as String?;
        if (type == StoryContentCodec.typeText) {
          final text = m['text'] as String? ?? '';
          return {
            'type': StoryContentCodec.typeText,
            'text': PerspectiveEngine.transform(text, currentMapping),
          };
        }
        return Map<String, dynamic>.from(m);
      }).toList();
      excerpt = StoryContentCodec.joinPlainText(outBlocks);
    } else {
      excerpt =
          PerspectiveEngine.transform(originalPost.excerpt, currentMapping);
      outBlocks = null;
    }

    displayPost = StoryPost(
      id: originalPost.id,
      authorId: originalPost.authorId,
      author: originalPost.author,
      handle: originalPost.handle,
      title: originalPost.title,
      excerpt: excerpt,
      likes: originalPost.likes,
      comments: originalPost.comments,
      saves: originalPost.saves,
      ratingCount: originalPost.ratingCount,
      averageRating: originalPost.averageRating,
      likedByMe: originalPost.likedByMe,
      savedByMe: originalPost.savedByMe,
      accent: originalPost.accent,
      imageUrl: originalPost.imageUrl,
      commentList: originalPost.commentList,
      contentBlocks: outBlocks,
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
  final StoryService _service = StoryService();
  final FollowService _followService = FollowService();
  final StoryController _storyController = StoryController();
  final ContentModerationService _moderationService =
      ContentModerationService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  User? _user;
  String _userId = "";
  String _userName = "";
  Set<String> _savedStoryIds = const {};
  String _searchQuery = "";
  bool _isSearchOpen = false;
  String? _communityHighlightedStoryId;
  bool _pendingCommunityHighlightScroll = false;
  final Map<String, GlobalKey> _communityStoryKeys = {};
  String? _myStoriesInitialStatus;
  String? _myStoriesHighlightedStoryId;

  @override
  void initState() {
    super.initState();
    _storyController.fetchStories(status: 'published');
    _user = FirebaseAuth.instance.currentUser;
    if (_user != null) {
      _userId = _user!.uid;
      // Set fallback username immediately
      _userName =
          _user!.displayName ?? _user!.email?.split('@').first ?? 'User';
      // Try to fetch the actual username from Firestore
      _fetchUserName();
      _listenToUserSavedStories();
    }
  }

  @override
  void dispose() {
    _storyController.dispose();
    _searchDebounce?.cancel();
    _userDocSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _listenToUserSavedStories() {
    final userId = _user?.uid;
    if (userId == null || userId.isEmpty) return;

    _userDocSub = _db.collection('users').doc(userId).snapshots().listen(
      (snapshot) {
        if (!mounted) return;
        setState(() {
          _savedStoryIds = _readStringSet(snapshot.data()?['savedStoryIds']);
        });
      },
      onError: (error) {
        debugPrint('Could not listen to saved stories: $error');
      },
    );
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
      WriteStoryScreen(
        onBackToCommunity: () {
          setState(() => _selectedIndex = 0);
        },
      ),
      const EbookScreen(),
      const PixieDashScreen(),
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
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            if (index != 0) {
              _communityHighlightedStoryId = null;
              _pendingCommunityHighlightScroll = false;
            }
          });
        },
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
            icon: Icon(Icons.auto_awesome_outlined),
            activeIcon: Icon(Icons.auto_awesome),
            label: 'Play',
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
      appBar: _buildFeedHeaderSection(),
      body: RefreshIndicator(
        color: Colors.purple,
        onRefresh: () async {
          await _storyController.fetchStories(status: 'published');
          await Future<void>.delayed(const Duration(milliseconds: 400));
          if (!mounted) return;
          setState(() {});
        },
        child: _buildFeedBodySection(),
      ),
    );
  }

  PreferredSizeWidget _buildFeedHeaderSection() {
    return AppBar(
      backgroundColor: const Color(0xFF7B1FA2),
      title: const _BrandTitle(),
      centerTitle: true,
      actions: [
        IconButton(
          tooltip: _isSearchOpen ? 'Close search' : 'Search stories',
          onPressed: _toggleSearch,
          icon: Icon(
            _isSearchOpen ? Icons.close : Icons.search,
            color: Colors.white,
          ),
        ),
        _NotificationBell(
          userId: _userId,
          onStoryNotificationTap: _handleStoryNotificationTap,
        ),
      ],
    );
  }

  Widget _buildFeedBodySection() {
    return AnimatedBuilder(
      animation: _storyController,
      builder: (context, _) {
        final availableDocs = _storyController.storyDocs;
        if (_storyController.isLoading && availableDocs.isEmpty) {
          return _buildFeedLoadingStateUi();
        }
        if (_storyController.errorMessage != null && availableDocs.isEmpty) {
          return Center(
            child: Text(
              'Error loading stories',
              style: TextStyle(color: Colors.grey[700]),
            ),
          );
        }

        final publishedDocs = availableDocs.toList()
          ..sort((a, b) {
            final aDate = _readTimestamp(a.data()['createdAt']);
            final bDate = _readTimestamp(b.data()['createdAt']);
            return bDate.compareTo(aDate);
          });

        if (publishedDocs.isEmpty) return _buildFeedEmptyStateUi();

        final docs = publishedDocs
            .where((doc) => _matchesStorySearch(doc.data()))
            .toList();
        final hasActiveSearch = StorySearch.hasSearchTerms(_searchQuery);
        if (_pendingCommunityHighlightScroll &&
            _communityHighlightedStoryId != null &&
            docs.any((doc) => doc.id == _communityHighlightedStoryId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToCommunityStory(_communityHighlightedStoryId!);
          });
        }

        return _buildSearchAndFeedSection(
          docs: docs,
          hasActiveSearch: hasActiveSearch,
        );
      },
    );
  }

  Widget _buildFeedLoadingStateUi() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildFeedEmptyStateUi() {
    return const Center(child: Text('No stories yet'));
  }

  Widget _buildSearchAndFeedSection({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required bool hasActiveSearch,
  }) {
    return Column(
      children: [
        if (_isSearchOpen)
          _StorySearchSection(
            controller: _searchController,
            onChanged: _queueSearch,
            onClear: () {
              setState(() {
                _searchDebounce?.cancel();
                _searchController.clear();
                _searchQuery = "";
              });
            },
          ),
        if (_isSearchOpen && !hasActiveSearch && _searchQuery.trim().isNotEmpty)
          const _SearchMinimumHint(),
        if (docs.isEmpty)
          Expanded(child: _StorySearchEmptyState(query: _searchQuery))
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                return _buildPostStoryCard(context, docs[index]);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPostStoryCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final storyId = doc.id;

    final author = (data['authorName'] as String?) ??
        (data['authorId'] as String?) ??
        'Unknown';
    final mappedPost = StoryPostMapper.fromFirestoreMap(
      storyId: storyId,
      data: data,
      currentUserId: _userId,
      accent: const Color(0xFF7B1FA2),
      fallbackAuthor: author,
    );
    final savedBy = (data['savedBy'] as List?) ?? [];
    final savedByMe =
        _savedStoryIds.contains(storyId) || savedBy.contains(_userId);
    final post = StoryPost(
      id: mappedPost.id,
      authorId: mappedPost.authorId,
      author: mappedPost.author,
      handle: mappedPost.handle,
      title: mappedPost.title,
      excerpt: mappedPost.excerpt,
      likes: mappedPost.likes,
      comments: mappedPost.comments,
      saves: _readInt(data['saves']),
      ratingCount: mappedPost.ratingCount,
      averageRating: mappedPost.averageRating,
      likedByMe: mappedPost.likedByMe,
      savedByMe: savedByMe,
      accent: mappedPost.accent,
      imageUrl: mappedPost.imageUrl,
      contentBlocks: mappedPost.contentBlocks,
    );

    return Container(
      key: _communityStoryKey(storyId),
      child: StoryCard(
        post: post,
        service: _service,
        userId: _userId.isEmpty ? _user?.uid ?? '' : _userId,
        userName:
            _userName.isEmpty ? (_user?.displayName ?? 'User') : _userName,
        followService: _followService,
        onAuthorTap: () => _openAuthorProfile(post),
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
        onOpen: () {
          _clearCommunityHighlight();
          _openStory(context, post);
        },
        onComment: () {
          _clearCommunityHighlight();
          _openComments(
            context,
            storyId,
            storyTitle: post.title,
          );
        },
        onSave: () async {
          final activeUserId = _userId.isEmpty ? _user?.uid ?? '' : _userId;
          if (activeUserId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please log in to save stories.')),
            );
            return;
          }

          try {
            final isSaved = await _service.toggleSave(
              storyId: storyId,
              userId: activeUserId,
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isSaved
                      ? 'Story saved to your profile.'
                      : 'Story removed from Saved.',
                ),
                backgroundColor: isSaved ? Colors.green : Colors.grey.shade700,
              ),
            );
          } catch (error, stackTrace) {
            debugPrint('Could not update saved story: $error');
            debugPrintStack(stackTrace: stackTrace);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Could not update saved story. Please try again.'),
              ),
            );
          }
        },
        highlighted: storyId == _communityHighlightedStoryId,
      ),
    );
  }

  void _openAuthorProfile(StoryPost post) {
    final authorId = post.authorId;
    if (authorId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(
          userId: authorId,
          fallbackName: post.author,
          fallbackHandle: post.handle,
        ),
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      _isSearchOpen = !_isSearchOpen;
      if (!_isSearchOpen) {
        _searchDebounce?.cancel();
        _searchController.clear();
        _searchQuery = "";
      }
    });
  }

  void _queueSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _searchQuery = value);
    });
  }

  GlobalKey _communityStoryKey(String storyId) {
    return _communityStoryKeys.putIfAbsent(storyId, GlobalKey.new);
  }

  void _scrollToCommunityStory(String storyId) {
    if (!mounted) return;
    final context = _communityStoryKeys[storyId]?.currentContext;
    if (context == null) return;

    _pendingCommunityHighlightScroll = false;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  void _clearCommunityHighlight() {
    if (_communityHighlightedStoryId == null &&
        !_pendingCommunityHighlightScroll) {
      return;
    }

    setState(() {
      _communityHighlightedStoryId = null;
      _pendingCommunityHighlightScroll = false;
    });
  }

  bool _matchesStorySearch(Map<String, dynamic> data) {
    return StorySearch.matchesStory(data, _searchQuery);
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
    if (type == 'like' ||
        type == 'comment' ||
        type == 'comment_reply' ||
        type == 'comment_reaction' ||
        type == 'rating') {
      final snap = await _db.collection('stories').doc(storyId).get();
      if (!mounted) return;

      if (!snap.exists || snap.data()?['status'] != 'published') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story is not available in Community.')),
        );
        return;
      }

      setState(() {
        _selectedIndex = 0;
        _communityHighlightedStoryId = storyId;
        _pendingCommunityHighlightScroll = true;
        _isSearchOpen = false;
        _searchDebounce?.cancel();
        _searchController.clear();
        _searchQuery = "";
      });
      return;
    }

    if (type == 'approval_result') {
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

    final author = (data['authorName'] as String?) ?? authorId ?? 'Unknown';

    _openStory(
      context,
      StoryPostMapper.fromFirestoreMap(
        storyId: storyId,
        data: data,
        currentUserId: _userId,
        accent: kAppPrimary,
        fallbackAuthor: author,
      ),
    );
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Set<String> _readStringSet(dynamic value) {
    if (value is! List) return const {};
    return value.whereType<String>().where((id) => id.isNotEmpty).toSet();
  }

  String _currentCommentUserName() {
    return _userName.isNotEmpty
        ? _userName
        : (_user?.displayName ?? _user?.email?.split('@').first ?? 'User');
  }

  Future<void> _showReactionPicker({
    required BuildContext context,
    required String storyId,
    required String commentId,
  }) async {
    const emojis = ['❤️', '😂', '👏', '😍', '👍'];
    final selectedEmoji = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: emojis
                  .map(
                    (emoji) => InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => Navigator.pop(context, emoji),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );

    if (selectedEmoji == null || _userId.isEmpty) return;
    if (!context.mounted) return;
    await _toggleCommentReactionSafely(
      context: context,
      storyId: storyId,
      commentId: commentId,
      emoji: selectedEmoji,
    );
  }

  Future<void> _toggleCommentReactionSafely({
    required BuildContext context,
    required String storyId,
    required String commentId,
    required String emoji,
  }) async {
    if (_userId.isEmpty) return;

    try {
      await _service.toggleCommentReaction(
        storyId: storyId,
        commentId: commentId,
        userId: _userId,
        userName: _currentCommentUserName(),
        emoji: emoji,
      );
    } on FirebaseException catch (e) {
      if (!context.mounted) return;
      final message = e.code == 'permission-denied'
          ? 'Reactions need updated Firestore rules.'
          : 'Could not update reaction: ${e.message ?? e.code}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update reaction: $e')),
      );
    }
  }

  Widget _buildCommentReactionBar({
    required String storyId,
    required String commentId,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.getCommentReactions(
        storyId: storyId,
        commentId: commentId,
      ),
      builder: (context, snapshot) {
        final reactionCounts = <String, int>{};
        String? selectedReaction;

        for (final doc in snapshot.data?.docs ?? const []) {
          final data = doc.data();
          final emoji = data['emoji'];
          if (emoji is! String || emoji.isEmpty) continue;
          reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
          if (doc.id == _userId) selectedReaction = emoji;
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reactionCounts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  reactionCounts.entries
                      .map((entry) => '${entry.key} ${entry.value}')
                      .join(' '),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            IconButton(
              tooltip: selectedReaction == '❤️' ? 'Remove reaction' : 'React',
              onPressed: _userId.isEmpty
                  ? null
                  : () {
                      _toggleCommentReactionSafely(
                        context: context,
                        storyId: storyId,
                        commentId: commentId,
                        emoji: '❤️',
                      );
                    },
              icon: Icon(
                selectedReaction == '❤️'
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: selectedReaction == '❤️'
                    ? Colors.redAccent
                    : Colors.grey.shade700,
                size: 20,
              ),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              tooltip: 'Choose reaction',
              onPressed: _userId.isEmpty
                  ? null
                  : () => _showReactionPicker(
                        context: context,
                        storyId: storyId,
                        commentId: commentId,
                      ),
              icon: Icon(
                Icons.add_reaction_outlined,
                color: selectedReaction == null
                    ? Colors.grey.shade700
                    : kAppPrimary,
                size: 20,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        );
      },
    );
  }

  Widget _buildCommentReplies({
    required List<dynamic> replies,
  }) {
    final replyMaps = replies
        .whereType<Map>()
        .map((reply) => Map<String, dynamic>.from(reply))
        .toList()
      ..sort((a, b) {
        final aDate = _readTimestamp(a['createdAt']);
        final bDate = _readTimestamp(b['createdAt']);
        return aDate.compareTo(bDate);
      });

    if (replyMaps.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8, left: 4),
      padding: const EdgeInsets.only(left: 12),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Color(0xFFE2D9F3), width: 2),
        ),
      ),
      child: Column(
        children: replyMaps.map((data) {
          final name = (data['userName'] as String?) ?? 'Unknown';
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: const Color(0xFFE1BEE7),
                  child: Text(
                    name.isNotEmpty ? name[0] : '?',
                    style: const TextStyle(
                      color: kAppPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF8FD),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (data['text'] as String?) ?? '',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _openComments(
    BuildContext context,
    String storyId, {
    String? storyTitle,
  }) {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    final expandedReplyCommentIds = <String>{};
    _CommentReplyTarget? replyTarget;
    bool isSending = false;
    bool isSheetClosing = false;
    Timer? moderationDebounce;
    ModerationLiveFeedback? liveModeration;
    var moderationListenerAttached = false;

    void dismissCommentKeyboard() {
      focusNode.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            if (!moderationListenerAttached) {
              moderationListenerAttached = true;
              controller.addListener(() {
                moderationDebounce?.cancel();
                moderationDebounce =
                    Timer(const Duration(milliseconds: 240), () {
                  if (isSheetClosing || !sheetContext.mounted) return;
                  final surface = replyTarget == null
                      ? ModerationSurface.comment
                      : ModerationSurface.reply;
                  final fb = _moderationService.previewWhileTyping(
                    surface,
                    controller.text,
                    storyExcerpt: storyTitle ?? '',
                  );
                  setModalState(() => liveModeration = fb);
                });
              });
            }

            Future<void> submitText() async {
              if (isSending || isSheetClosing) return;
              final text = controller.text.trim();
              if (text.isEmpty || _userId.isEmpty) return;

              final target = replyTarget;
              final surface = target == null
                  ? ModerationSurface.comment
                  : ModerationSurface.reply;
              final moderation = _moderationService.moderateWithSurface(
                surface,
                text,
                storyExcerpt: storyTitle ?? '',
              );
              if (!moderation.isSafe) {
                await ModerationUi.showBlockDialog(
                  sheetContext,
                  result: moderation,
                  surface: surface,
                );
                return;
              }

              dismissCommentKeyboard();
              setModalState(() => isSending = true);
              try {
                if (target == null) {
                  await _service.addComment(
                    storyId: storyId,
                    userId: _userId,
                    userName: _currentCommentUserName(),
                    text: text,
                  );
                } else {
                  await _service.addCommentReply(
                    storyId: storyId,
                    commentId: target.commentId,
                    userId: _userId,
                    userName: _currentCommentUserName(),
                    text: text,
                  );
                  expandedReplyCommentIds.add(target.commentId);
                }
              } catch (e) {
                if (!sheetContext.mounted || isSheetClosing) return;
                if (e is ArgumentError) {
                  await ModerationUi.showPlainMessage(
                    sheetContext,
                    message: e.message?.toString() ??
                        ContentModerationService.childFriendlyWarning,
                    surface: surface,
                  );
                  return;
                }
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(content: Text('Could not send: $e')),
                );
                return;
              } finally {
                if (sheetContext.mounted && !isSheetClosing) {
                  setModalState(() => isSending = false);
                }
              }

              controller.clear();
              if (!sheetContext.mounted || isSheetClosing) return;
              setModalState(() => replyTarget = null);
            }

            void startReply(String commentId, String userName) {
              if (isSheetClosing) return;
              setModalState(() {
                replyTarget = _CommentReplyTarget(
                  commentId: commentId,
                  userName: userName,
                );
              });
              focusNode.requestFocus();
            }

            final mediaQuery = MediaQuery.of(sheetContext);
            final availableHeight = mediaQuery.size.height -
                mediaQuery.viewInsets.bottom -
                mediaQuery.padding.bottom -
                24;
            final sheetHeight = availableHeight
                .clamp(280.0, mediaQuery.size.height * 0.78)
                .toDouble();

            return PopScope(
              onPopInvokedWithResult: (_, __) {
                isSheetClosing = true;
                dismissCommentKeyboard();
              },
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: mediaQuery.viewInsets.bottom,
                    left: 12,
                    right: 12,
                    top: 10,
                  ),
                  child: SizedBox(
                    height: sheetHeight,
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
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              final docs = snapshot.data!.docs;

                              if (docs.isEmpty) {
                                return const Center(
                                  child: Text("No comments yet"),
                                );
                              }

                              return ListView.separated(
                                padding: const EdgeInsets.only(bottom: 12),
                                itemCount: docs.length,
                                separatorBuilder: (_, __) => const Divider(
                                  height: 24,
                                  color: Color(0xFFF1ECF7),
                                ),
                                itemBuilder: (context, i) {
                                  final commentId = docs[i].id;
                                  final data =
                                      docs[i].data() as Map<String, dynamic>;
                                  final isOwner = data['userId'] == _userId;
                                  final commentUserName =
                                      (data['userName'] as String?) ??
                                          'Unknown';
                                  final replies =
                                      (data['replies'] as List?) ?? const [];
                                  final replyCount = replies.isNotEmpty
                                      ? replies.length
                                      : _readInt(data['replyCount']);
                                  final repliesExpanded =
                                      expandedReplyCommentIds
                                          .contains(commentId);

                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.purple,
                                        radius: 18,
                                        child: Text(
                                          commentUserName.isNotEmpty
                                              ? commentUserName[0]
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
                                            Container(
                                              width: double.infinity,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFAF8FD),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    commentUserName,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(data['text'] ?? ''),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 4,
                                              runSpacing: 2,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                TextButton(
                                                  onPressed: _userId.isEmpty
                                                      ? null
                                                      : () => startReply(
                                                            commentId,
                                                            commentUserName,
                                                          ),
                                                  style: TextButton.styleFrom(
                                                    foregroundColor:
                                                        Colors.grey.shade700,
                                                    minimumSize: Size.zero,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                  child: const Text('Reply'),
                                                ),
                                                _buildCommentReactionBar(
                                                  storyId: storyId,
                                                  commentId: commentId,
                                                ),
                                                if (isOwner)
                                                  IconButton(
                                                    tooltip: 'Delete comment',
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                      color: Colors.red,
                                                      size: 19,
                                                    ),
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    onPressed: () async {
                                                      await _service
                                                          .deleteComment(
                                                        storyId: storyId,
                                                        commentId: commentId,
                                                      );
                                                    },
                                                  ),
                                              ],
                                            ),
                                            if (replyCount > 0)
                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: TextButton(
                                                  onPressed: () {
                                                    setModalState(() {
                                                      if (repliesExpanded) {
                                                        expandedReplyCommentIds
                                                            .remove(commentId);
                                                      } else {
                                                        expandedReplyCommentIds
                                                            .add(commentId);
                                                      }
                                                    });
                                                  },
                                                  style: TextButton.styleFrom(
                                                    foregroundColor:
                                                        kAppPrimary,
                                                    minimumSize: Size.zero,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 4,
                                                      vertical: 2,
                                                    ),
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                  child: Text(
                                                    repliesExpanded
                                                        ? 'Hide replies'
                                                        : 'View $replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            AnimatedSwitcher(
                                              duration: const Duration(
                                                  milliseconds: 180),
                                              child: repliesExpanded
                                                  ? _buildCommentReplies(
                                                      replies: replies,
                                                    )
                                                  : const SizedBox.shrink(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: replyTarget == null
                              ? const SizedBox.shrink()
                              : Container(
                                  key: ValueKey(replyTarget!.commentId),
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7F3FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Replying to ${replyTarget!.userName}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: kAppPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Cancel reply',
                                        onPressed: () => setModalState(
                                          () => replyTarget = null,
                                        ),
                                        icon: const Icon(Icons.close, size: 18),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      minLines: 1,
                                      maxLines: 4,
                                      textInputAction: TextInputAction.send,
                                      onSubmitted: (_) {
                                        submitText();
                                      },
                                      decoration: InputDecoration(
                                        hintText: replyTarget == null
                                            ? 'Add a comment...'
                                            : 'Write a reply...',
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filled(
                                    icon: isSending
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.send),
                                    onPressed: isSending ? null : submitText,
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              ModerationLiveBanner(feedback: liveModeration),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      isSheetClosing = true;
      moderationDebounce?.cancel();
      dismissCommentKeyboard();
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        controller.dispose();
        focusNode.dispose();
      });
    });
  }
}

class _CommentReplyTarget {
  final String commentId;
  final String userName;

  const _CommentReplyTarget({
    required this.commentId,
    required this.userName,
  });
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

class _StorySearchSection extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _StorySearchSection({
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
          hintText: 'Search title, keyword, or username',
          prefixIcon: const Icon(Icons.search, color: kAppPrimary),
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

class _SearchMinimumHint extends StatelessWidget {
  const _SearchMinimumHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Enter at least ${StorySearch.minTermLength} characters to search.',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _StorySearchEmptyState extends StatelessWidget {
  final String query;

  const _StorySearchEmptyState({required this.query});

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
              Icons.search_off,
              size: 58,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 14),
            const Text(
              'No stories found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              searchText.isEmpty
                  ? 'Try a story title, keyword, username, or handle.'
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

class _RatingSummary extends StatelessWidget {
  final double averageRating;
  final int ratingCount;

  const _RatingSummary({
    required this.averageRating,
    required this.ratingCount,
  });

  @override
  Widget build(BuildContext context) {
    final label = ratingCount == 0
        ? 'No ratings yet'
        : '${averageRating.toStringAsFixed(1)} / 5 ($ratingCount)';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star, color: Colors.amber, size: 18),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _StoryRatingPanel extends StatefulWidget {
  final StoryPost post;
  final StoryService service;
  final String userId;
  final String userName;

  const _StoryRatingPanel({
    required this.post,
    required this.service,
    required this.userId,
    required this.userName,
  });

  @override
  State<_StoryRatingPanel> createState() => _StoryRatingPanelState();
}

class _StoryRatingPanelState extends State<_StoryRatingPanel> {
  int? _savingRating;
  int? _optimisticRating;

  @override
  Widget build(BuildContext context) {
    if (widget.userId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('stories')
          .doc(widget.post.id)
          .snapshots(),
      builder: (context, storySnap) {
        final storyData = storySnap.data?.data() ?? {};
        final averageRating = _readDouble(storyData['averageRating'],
            fallback: widget.post.averageRating);
        final ratingCount = _readInt(storyData['ratingCount'],
            fallback: widget.post.ratingCount);
        final authorId = storyData['authorId'] as String?;
        final isOwnStory = authorId == widget.userId;

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: widget.service.getUserRating(
            storyId: widget.post.id,
            userId: widget.userId,
          ),
          builder: (context, ratingSnap) {
            final savedRating = _readInt(ratingSnap.data?.data()?['rating']);
            final selectedRating = _optimisticRating ?? savedRating;

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F3FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2D9F3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _RatingSummary(
                        averageRating: averageRating,
                        ratingCount: ratingCount,
                      ),
                      const Spacer(),
                      if (selectedRating > 0)
                        Text(
                          'Your rating: $selectedRating',
                          style: const TextStyle(
                            color: kAppPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    isOwnStory
                        ? 'Readers can rate this story'
                        : 'Rate this story',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: List.generate(5, (index) {
                      final rating = index + 1;
                      final isFilled = rating <= selectedRating;
                      final isSaving = _savingRating == rating;

                      return IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 34,
                        ),
                        tooltip: '$rating star${rating == 1 ? '' : 's'}',
                        onPressed: isOwnStory ||
                                _savingRating != null ||
                                rating == selectedRating
                            ? null
                            : () => _rateStory(rating, savedRating),
                        icon: Icon(
                          isFilled ? Icons.star : Icons.star_border,
                          color: isOwnStory
                              ? Colors.grey
                              : isSaving
                                  ? kAppPrimary
                                  : Colors.amber.shade700,
                        ),
                      );
                    }),
                  ),
                  if (_savingRating != null) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Saving rating...',
                      style: TextStyle(
                        color: kAppPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _rateStory(int rating, int savedRating) async {
    setState(() {
      _optimisticRating = rating;
      _savingRating = rating;
    });
    try {
      await widget.service.rateStory(
        storyId: widget.post.id,
        userId: widget.userId,
        userName: widget.userName,
        rating: rating,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Thanks for rating ${widget.post.title}!')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _optimisticRating = savedRating > 0 ? savedRating : null;
      });
      final message = error is StateError
          ? error.message
          : 'Could not save rating. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _savingRating = null);
      }
    }
  }

  static int _readInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static double _readDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
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

  Future<void> _deleteNotification(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    await doc.reference.delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification deleted')),
    );
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
                      type == 'comment_reply' ||
                      type == 'comment_reaction' ||
                      type == 'rating' ||
                      type == 'approval_result');

              return Dismissible(
                key: ValueKey(docs[index].id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 18),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (_) => _deleteNotification(docs[index]),
                child: InkWell(
                  onTap: canOpenApproval
                      ? () {
                          Navigator.pop(context);
                          widget.onParentApprovalTap?.call(storyId);
                        }
                      : canOpenStory
                          ? () {
                              Navigator.pop(context);
                              widget.onStoryNotificationTap
                                  ?.call(storyId, type);
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
                        IconButton(
                          tooltip: 'Delete notification',
                          onPressed: () => _deleteNotification(docs[index]),
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: Colors.grey.shade600,
                          visualDensity: VisualDensity.compact,
                        ),
                        if (!isRead)
                          Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(top: 12),
                            decoration: const BoxDecoration(
                              color: kAppPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
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
    if (type == 'comment_reply') return 'Someone replied to your comment';
    if (type == 'comment_reaction') return 'Someone reacted to your comment';
    if (type == 'rating') return 'Someone rated your story';
    if (type == 'follow') return 'Someone started following you';
    if (type == 'parent_approval') return 'A story is waiting for approval';
    if (type == 'approval_result') return 'Your story approval was updated';
    return 'Someone liked your story';
  }

  static IconData _notificationIcon(String type) {
    if (type == 'comment') return Icons.chat_bubble_outline;
    if (type == 'comment_reply') return Icons.reply;
    if (type == 'comment_reaction') return Icons.add_reaction_outlined;
    if (type == 'rating') return Icons.star_outline;
    if (type == 'follow') return Icons.person_add_alt_1;
    if (type == 'parent_approval') return Icons.fact_check_outlined;
    if (type == 'approval_result') return Icons.verified_outlined;
    return Icons.favorite;
  }

  static Color _notificationColor(String type) {
    if (type == 'comment') return kAppPrimary;
    if (type == 'comment_reply') return kAppPrimary;
    if (type == 'comment_reaction') return kAppPrimary;
    if (type == 'rating') return Colors.amber.shade800;
    if (type == 'follow') return Colors.pink.shade600;
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
  final FollowService followService;
  final String userId;
  final String userName;
  final VoidCallback onLike;
  final VoidCallback onOpen;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback? onAuthorTap;
  final bool highlighted;

  const StoryCard({
    super.key,
    required this.post,
    required this.service,
    required this.followService,
    required this.userId,
    required this.userName,
    required this.onLike,
    required this.onOpen,
    required this.onComment,
    required this.onSave,
    this.onAuthorTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < 380 ? 10.0 : 16.0;
    final imageHeight = (screenWidth * 0.48).clamp(155.0, 220.0).toDouble();

    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: highlighted ? const Color(0xFFFFFBEB) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                highlighted ? kAppPrimary : Colors.grey.withValues(alpha: 0.2),
            width: highlighted ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: highlighted
                  ? kAppPrimary.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: highlighted ? 16 : 10,
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
                    child: StorageImage(
                      url: post.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: imageHeight,
                      placeholder: Container(
                        height: imageHeight,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: onAuthorTap,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFF7B1FA2),
                                    child: Text(
                                      post.author.isNotEmpty
                                          ? post.author[0]
                                          : '?',
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StoryFollowButton(
                          followService: followService,
                          currentUserId: userId,
                          targetUserId: post.authorId,
                          targetUserName: post.author,
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
                  const SizedBox(height: 10),
                  _RatingSummary(
                    averageRating: post.averageRating,
                    ratingCount: post.ratingCount,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _StoryActionCount(
                        icon: post.likedByMe
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: post.likedByMe ? Colors.red : Colors.purple,
                        count: post.likes,
                        onPressed: onLike,
                      ),
                      _StoryActionCount(
                        icon: Icons.chat_bubble_outline,
                        color: Colors.purple,
                        count: post.comments,
                        onPressed: onComment,
                      ),
                      _StoryActionCount(
                        icon: post.savedByMe
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        color: post.savedByMe ? kAppPrimary : Colors.purple,
                        count: post.saves,
                        onPressed: onSave,
                      ),
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryFollowButton extends StatefulWidget {
  final FollowService followService;
  final String currentUserId;
  final String targetUserId;
  final String targetUserName;

  const _StoryFollowButton({
    required this.followService,
    required this.currentUserId,
    required this.targetUserId,
    required this.targetUserName,
  });

  @override
  State<_StoryFollowButton> createState() => _StoryFollowButtonState();
}

class _StoryFollowButtonState extends State<_StoryFollowButton> {
  bool _isSaving = false;

  bool get _canFollow =>
      widget.currentUserId.isNotEmpty &&
      widget.targetUserId.isNotEmpty &&
      widget.currentUserId != widget.targetUserId;

  Future<void> _toggleFollow() async {
    if (!_canFollow || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final isFollowing = await widget.followService.toggleFollow(
        currentUserId: widget.currentUserId,
        targetUserId: widget.targetUserId,
      );
      if (!mounted) return;
      final name = widget.targetUserName.trim().isEmpty
          ? 'this user'
          : widget.targetUserName.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFollowing ? 'Following $name' : 'Unfollowed $name'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update follow: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canFollow) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.followService.followStream(
        currentUserId: widget.currentUserId,
        targetUserId: widget.targetUserId,
      ),
      builder: (context, snapshot) {
        final isFollowing = snapshot.data?.exists == true;
        final foreground = isFollowing ? kAppPrimary : Colors.white;
        final background =
            isFollowing ? Colors.white : kAppPrimary.withValues(alpha: 0.96);

        return SizedBox.square(
          dimension: 34,
          child: IconButton(
            tooltip: isFollowing ? 'Unfollow' : 'Follow',
            onPressed: _isSaving ? null : _toggleFollow,
            icon: _isSaving
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                : Icon(
                    isFollowing
                        ? Icons.person_remove_alt_1
                        : Icons.person_add_alt_1,
                    size: 18,
                  ),
            style: IconButton.styleFrom(
              backgroundColor: background,
              foregroundColor: foreground,
              disabledBackgroundColor: background.withValues(alpha: 0.82),
              disabledForegroundColor: foreground.withValues(alpha: 0.7),
              side: BorderSide(
                color: isFollowing
                    ? kAppPrimary.withValues(alpha: 0.34)
                    : Colors.white.withValues(alpha: 0.36),
              ),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
        );
      },
    );
  }
}

class _StoryActionCount extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback onPressed;

  const _StoryActionCount({
    required this.icon,
    required this.color,
    required this.count,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: color),
          onPressed: onPressed,
          visualDensity: VisualDensity.compact,
        ),
        Text("$count"),
      ],
    );
  }
}

/// One segment in the reader scroll: a speech paragraph or an inline image.
class _ReaderLayoutPiece {
  const _ReaderLayoutPiece.text(this.text, this.speechIndex)
      : isImage = false,
        imageUrl = null,
        delta = null;

  const _ReaderLayoutPiece.rich(this.text, this.delta, this.speechIndex)
      : isImage = false,
        imageUrl = null;

  const _ReaderLayoutPiece.image(this.imageUrl)
      : isImage = true,
        text = null,
        delta = null,
        speechIndex = -1;

  final bool isImage;
  final String? text;
  final String? imageUrl;
  final List<dynamic>? delta;

  /// Index into [_paragraphs] / [_paragraphKeys]; -1 for images.
  final int speechIndex;
}

/// =============================================================================
/// STORY READER PAGE (Enhanced with Perspective Shift & Character Names)
/// =============================================================================

class StoryReaderPage extends StatefulWidget {
  final StoryPost post;
  final StoryService service;
  final String userId;
  final String userName;
  final Widget? footer;

  const StoryReaderPage({
    super.key,
    required this.post,
    required this.service,
    required this.userId,
    required this.userName,
    this.footer,
  });

  @override
  State<StoryReaderPage> createState() => _StoryReaderPageState();
}

class _StoryReaderPageState extends State<StoryReaderPage> {
  late StoryReaderViewModel viewModel;
  final FlutterTts _tts = FlutterTts();
  final GeminiService _geminiService = GeminiService();
  final ScrollController _storyScrollController = ScrollController();
  final List<GlobalKey> _paragraphKeys = [];
  List<String> _paragraphs = [];
  List<_ReaderLayoutPiece> _layoutPieces = [];
  bool _isSpeaking = false;
  bool _isPreparingSpeech = false;
  bool _isShiftingPerspective = false;
  bool _isPaused = false;
  int? _activeParagraphIndex;
  int _speechSession = 0;

  @override
  void initState() {
    super.initState();
    viewModel = StoryReaderViewModel(widget.post);
    _syncParagraphs();
    viewModel.addListener(_syncParagraphs);
    _configureTts();
  }

  @override
  void dispose() {
    _speechSession++;
    _tts.stop();
    viewModel.removeListener(_syncParagraphs);
    _storyScrollController.dispose();
    viewModel.dispose();
    super.dispose();
  }

  void _syncParagraphs() {
    final post = viewModel.displayPost;
    final blocks = post.contentBlocks;
    final List<String> nextParagraphs;
    final List<_ReaderLayoutPiece> nextPieces;

    if (blocks != null && blocks.isNotEmpty) {
      nextParagraphs = [];
      nextPieces = [];
      for (final m in blocks) {
        final type = m['type'] as String?;
        if (type == StoryContentCodec.typeImage) {
          final url = (m['url'] as String?)?.trim() ?? '';
          if (url.isNotEmpty) {
            nextPieces.add(_ReaderLayoutPiece.image(url));
          }
        } else {
          final raw = m['text'] as String? ?? '';
          final delta = m['delta'];
          if (delta is List && delta.isNotEmpty) {
            final idx = nextParagraphs.length;
            final plain = StoryContentCodec.plainTextFromFormatted(raw);
            nextParagraphs.add(plain);
            nextPieces.add(_ReaderLayoutPiece.rich(plain, delta, idx));
            continue;
          }
          final paras = _buildParagraphs(raw);
          for (final p in paras) {
            final idx = nextParagraphs.length;
            nextParagraphs.add(p);
            nextPieces.add(_ReaderLayoutPiece.text(p, idx));
          }
        }
      }
    } else {
      nextParagraphs = _buildParagraphs(post.excerpt);
      nextPieces = [
        for (var i = 0; i < nextParagraphs.length; i++)
          _ReaderLayoutPiece.text(nextParagraphs[i], i),
      ];
    }

    _paragraphKeys
      ..clear()
      ..addAll(List.generate(nextParagraphs.length, (_) => GlobalKey()));

    if (!mounted) {
      _paragraphs = nextParagraphs;
      _layoutPieces = nextPieces;
      return;
    }

    setState(() {
      _paragraphs = nextParagraphs;
      _layoutPieces = nextPieces;
      if (!_isSpeaking && !_isPreparingSpeech && !_isPaused) {
        _activeParagraphIndex = null;
      }
    });
  }

  Future<void> _configureTts() async {
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);
    _tts.setCancelHandler(() {
      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
        _isPreparingSpeech = false;
      });
    });
    _tts.setErrorHandler((message) {
      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
        _isPreparingSpeech = false;
      });
      if (message.toLowerCase().contains('interrupted')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reading paused.')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not read story aloud: $message')),
      );
    });
  }

  Future<void> _toggleReadAloud() async {
    if (_isSpeaking || _isPreparingSpeech) {
      await _pauseReadAloud();
      return;
    }
    await _startReadAloud(startIndex: _isPaused ? _activeParagraphIndex : null);
  }

  Future<void> _startReadAloud({int? startIndex}) async {
    final text = viewModel.displayPost.excerpt.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No story text to read.')),
      );
      return;
    }

    final session = ++_speechSession;
    final firstIndex = (startIndex ?? 0).clamp(0, _paragraphs.length - 1);
    setState(() {
      _isPreparingSpeech = true;
      _isSpeaking = false;
      _isPaused = false;
      _activeParagraphIndex = firstIndex;
    });

    try {
      final language = await _selectTtsLanguage(text);
      if (session != _speechSession) return;
      await _tts.setLanguage(language);

      if (mounted) {
        setState(() {
          _isPreparingSpeech = false;
          _isSpeaking = true;
        });
      }

      for (var i = firstIndex; i < _paragraphs.length; i++) {
        final paragraph = _paragraphs[i];
        if (session != _speechSession) return;
        setState(() => _activeParagraphIndex = i);
        _scrollParagraphIntoView(i);

        for (final part in _splitForSpeech(paragraph)) {
          if (session != _speechSession) return;
          await _tts.speak(part);
        }
      }

      if (mounted && session == _speechSession) {
        setState(() {
          _isSpeaking = false;
          _isPaused = false;
          _activeParagraphIndex = null;
        });
      }
    } catch (error) {
      if (!mounted || session != _speechSession) return;
      setState(() {
        _isSpeaking = false;
        _isPreparingSpeech = false;
        _isPaused = false;
        _activeParagraphIndex = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start read aloud: $error')),
      );
    }
  }

  Future<void> _pauseReadAloud() async {
    _speechSession++;
    await _tts.stop();
    if (!mounted) return;
    setState(() {
      _isSpeaking = false;
      _isPreparingSpeech = false;
      _isPaused = _activeParagraphIndex != null;
    });
  }

  Future<void> _stopReadAloud() async {
    _speechSession++;
    await _tts.stop();
    if (!mounted) return;
    setState(() {
      _isSpeaking = false;
      _isPreparingSpeech = false;
      _isPaused = false;
      _activeParagraphIndex = null;
    });
  }

  Future<String> _selectTtsLanguage(String text) async {
    final preferredLanguages = _looksLikeUrdu(text)
        ? const ['ur-PK', 'ur-IN', 'en-US']
        : const ['en-US', 'en-GB'];

    for (final language in preferredLanguages) {
      try {
        final available = await _tts.isLanguageAvailable(language);
        if (available == true || available == 1) {
          return language;
        }
      } catch (_) {
        return language;
      }
    }

    if (_looksLikeUrdu(text) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Urdu voice is not available on this device.'),
        ),
      );
    }
    return preferredLanguages.first;
  }

  bool _looksLikeUrdu(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  List<String> _splitForSpeech(String text) {
    const maxLength = 3500;
    final words = text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
    final chunks = <String>[];
    final buffer = StringBuffer();

    for (final word in words) {
      if (buffer.length + word.length + 1 > maxLength) {
        chunks.add(buffer.toString().trim());
        buffer.clear();
      }
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(word);
    }

    if (buffer.isNotEmpty) chunks.add(buffer.toString().trim());
    return chunks;
  }

  List<String> _buildParagraphs(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return const [];

    final paragraphBreaks = normalized
        .split(RegExp(r'\n\s*\n+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (paragraphBreaks.length > 1) return paragraphBreaks;

    return normalized
        .split(RegExp(r'(?<=[.!?۔؟])\s+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  void _scrollParagraphIntoView(int index) {
    if (index < 0 || index >= _paragraphKeys.length) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _paragraphKeys[index].currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.18,
      );
    });
  }

  String _sourceStoryText() {
    final blocks = widget.post.contentBlocks;
    if (blocks != null && blocks.isNotEmpty) {
      final text = StoryContentCodec.joinPlainText(blocks).trim();
      if (text.isNotEmpty) return text;
    }
    return widget.post.excerpt.trim();
  }

  Future<void> _applyGeminiPerspective({
    required int index,
    required String label,
    required String shiftType,
  }) async {
    Navigator.pop(context);
    final sourceText = _sourceStoryText();
    if (sourceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No story text to shift.')),
      );
      return;
    }

    await _stopReadAloud();
    setState(() => _isShiftingPerspective = true);

    try {
      final shifted = await _geminiService.shiftPerspective(
        shiftType,
        sourceText,
      );
      if (!mounted) return;
      viewModel.setGeneratedPerspective(
        index: index,
        label: label,
        text: shifted,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not shift perspective: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isShiftingPerspective = false);
      }
    }
  }

  void _showPerspectiveMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
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
                const SizedBox(height: 8),
                const Text(
                  'AI Story Shift',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                _aiPerspectiveButton(
                  label: 'Villain View',
                  index: 10,
                  shiftType: 'villain',
                ),
                _aiPerspectiveButton(
                  label: 'Side Character',
                  index: 11,
                  shiftType: 'side_character',
                ),
                _aiPerspectiveButton(
                  label: '10 Years Later',
                  index: 12,
                  shiftType: 'time_shift',
                ),
                _aiPerspectiveButton(
                  label: 'Joy + Fear',
                  index: 13,
                  shiftType: 'emotional_lens',
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text(
                    'Reset',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () {
                    _stopReadAloud();
                    viewModel.resetPerspective();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _aiPerspectiveButton({
    required String label,
    required int index,
    required String shiftType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: viewModel.currentPerspectiveIndex == index
              ? Colors.purple
              : Colors.purple.shade50,
          foregroundColor: viewModel.currentPerspectiveIndex == index
              ? Colors.white
              : Colors.purple.shade800,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: const Icon(Icons.auto_awesome),
        label: Text(label),
        onPressed: _isShiftingPerspective
            ? null
            : () => _applyGeminiPerspective(
                  index: index,
                  label: label,
                  shiftType: shiftType,
                ),
      ),
    );
  }

  Widget _perspectiveButton({required String label, required int index}) {
    // Maps the three person buttons (indices 0/1/2) onto the OpenAI shift
    // types so the rewrite happens with proper grammar instead of regex
    // pronoun swapping.
    const personShiftTypes = ['first_person', 'second_person', 'third_person'];

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
        onPressed: () async {
          _stopReadAloud();
          if (index >= 0 &&
              index < personShiftTypes.length &&
              _geminiService.isConfigured) {
            // OpenAI faithful-rewrite path (handles verb conjugation,
            // possessives, reflexives, etc. correctly).
            await _applyGeminiPerspective(
              index: index,
              label: label,
              shiftType: personShiftTypes[index],
            );
          } else {
            // Fallback: legacy regex pronoun substitution (used when the API
            // key isn't configured so the feature still works offline).
            viewModel.setPerspective(index);
            Navigator.pop(context);
          }
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
          IconButton(
            icon: Icon(
              _isSpeaking || _isPreparingSpeech
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline,
            ),
            tooltip: _isSpeaking || _isPreparingSpeech
                ? 'Pause reading'
                : _isPaused
                    ? 'Resume reading'
                    : 'Read aloud',
            onPressed: _toggleReadAloud,
          ),
        ],
      ),
      // Pin optional footer (e.g. parent actions) below one Expanded scroll area.
      // Avoids a Column of [many fixed rows] + Expanded + footer, which can
      // briefly assign zero/negative flex to Expanded when viewInsets/keyboard
      // change while a modal is open, causing a short bottom overflow flash.
      resizeToAvoidBottomInset: true,
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final pagePadding = constraints.maxWidth < 380 ? 12.0 : 16.0;

              return Padding(
                padding: EdgeInsets.all(pagePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, innerConstraints) {
                          // Width-based cover height stays valid inside scrollables
                          // (inner maxHeight can be unbounded in the scroll axis).
                          final imageHeight = (innerConstraints.maxWidth * 0.42)
                              .clamp(110.0, 168.0);

                          return SingleChildScrollView(
                            controller: _storyScrollController,
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _AuthorRow(
                                  name: viewModel.displayPost.author,
                                  handle: viewModel.displayPost.handle,
                                  onTap: _openAuthorProfile,
                                ),
                                const SizedBox(height: 6),
                                if (viewModel.displayPost.imageUrl.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: StorageImage(
                                      url: viewModel.displayPost.imageUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: imageHeight,
                                      placeholder: Container(
                                        height: imageHeight,
                                        color: Colors.grey[200],
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                _StoryRatingPanel(
                                  post: viewModel.displayPost,
                                  service: widget.service,
                                  userId: widget.userId,
                                  userName: widget.userName,
                                ),
                                const SizedBox(height: 6),
                                _ReadAloudBar(
                                  isSpeaking: _isSpeaking,
                                  isPreparing: _isPreparingSpeech,
                                  isPaused: _isPaused,
                                  onPressed: _toggleReadAloud,
                                  onStop: _isPaused ||
                                          _isSpeaking ||
                                          _isPreparingSpeech
                                      ? _stopReadAloud
                                      : null,
                                ),
                                const SizedBox(height: 8),
                                ..._layoutPieces.map((piece) {
                                  if (piece.isImage) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          10,
                                        ),
                                        child: StorageImage(
                                          url: piece.imageUrl!,
                                          width: double.infinity,
                                          fit: BoxFit.fitWidth,
                                          placeholder: Container(
                                            height: 120,
                                            color: Colors.grey.shade200,
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.broken_image_outlined,
                                              size: 40,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  final idx = piece.speechIndex;
                                  if (piece.delta != null) {
                                    return _TrackedStoryRichBlock(
                                      key: _paragraphKeys[idx],
                                      delta: piece.delta!,
                                      highlighted:
                                          idx == _activeParagraphIndex,
                                    );
                                  }
                                  return _TrackedStoryParagraph(
                                    key: _paragraphKeys[idx],
                                    text: piece.text!,
                                    highlighted: idx == _activeParagraphIndex,
                                  );
                                }),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    if (widget.footer != null) ...[
                      const SizedBox(height: 8),
                      widget.footer!,
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openAuthorProfile() {
    final post = viewModel.displayPost;
    if (post.authorId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(
          userId: post.authorId,
          fallbackName: post.author,
          fallbackHandle: post.handle,
        ),
      ),
    );
  }
}

/// =============================================================================
/// TRACKED STORY PARAGRAPH
/// =============================================================================

class _TrackedStoryParagraph extends StatelessWidget {
  final String text;
  final bool highlighted;

  const _TrackedStoryParagraph({
    super.key,
    required this.text,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.6,
              color: highlighted ? const Color(0xFF4A148C) : Colors.black87,
              fontWeight: highlighted ? FontWeight.w600 : FontWeight.normal,
            ) ??
        TextStyle(
          height: 1.6,
          color: highlighted ? const Color(0xFF4A148C) : Colors.black87,
          fontWeight: highlighted ? FontWeight.w600 : FontWeight.normal,
        );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFFFF8D8) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: highlighted
            ? Border.all(color: const Color(0xFFE3C54B))
            : Border.all(color: Colors.transparent),
      ),
      child: _FormattedStoryText(text: text, baseStyle: baseStyle),
    );
  }
}

class _TrackedStoryRichBlock extends StatelessWidget {
  final List<dynamic> delta;
  final bool highlighted;

  const _TrackedStoryRichBlock({
    super.key,
    required this.delta,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    final controller = quill.QuillController(
      document: quill.Document.fromJson(delta),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFFFF8D8) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: highlighted
            ? Border.all(color: const Color(0xFFE3C54B))
            : Border.all(color: Colors.transparent),
      ),
      child: quill.QuillEditor.basic(
        controller: controller,
        config: const quill.QuillEditorConfig(
          scrollable: false,
          showCursor: false,
          enableInteractiveSelection: false,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _FormattedStoryText extends StatelessWidget {
  final String text;
  final TextStyle baseStyle;

  const _FormattedStoryText({
    required this.text,
    required this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          _FormattedStoryLine(line: lines[i], baseStyle: baseStyle),
          if (i != lines.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _FormattedStoryLine extends StatelessWidget {
  final String line;
  final TextStyle baseStyle;

  const _FormattedStoryLine({
    required this.line,
    required this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = line.trimRight();
    if (trimmed.trim() == '---') {
      return Divider(color: Colors.grey.shade300, thickness: 1.2, height: 20);
    }

    final heading = RegExp(r'^\s{0,3}#{1,3}\s+(.+)$').firstMatch(trimmed);
    if (heading != null) {
      return RichText(
        text: TextSpan(
          style: baseStyle.copyWith(
            fontSize: 22,
            height: 1.28,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF2F2140),
          ),
          children: _inlineSpans(heading.group(1) ?? '', baseStyle),
        ),
      );
    }

    final quote = RegExp(r'^\s{0,3}>\s?(.+)$').firstMatch(trimmed);
    if (quote != null) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: kAppPrimary, width: 3)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: RichText(
            text: TextSpan(
              style: baseStyle.copyWith(
                color: Colors.grey.shade800,
                fontStyle: FontStyle.italic,
              ),
              children: _inlineSpans(quote.group(1) ?? '', baseStyle),
            ),
          ),
        ),
      );
    }

    final bullet = RegExp(r'^\s*[-*]\s+(.+)$').firstMatch(trimmed);
    if (bullet != null) {
      return _ListStoryLine(
        marker: '\u2022',
        content: bullet.group(1) ?? '',
        baseStyle: baseStyle,
      );
    }

    final numbered = RegExp(r'^\s*(\d+[.)])\s+(.+)$').firstMatch(trimmed);
    if (numbered != null) {
      return _ListStoryLine(
        marker: numbered.group(1) ?? '1.',
        content: numbered.group(2) ?? '',
        baseStyle: baseStyle,
      );
    }

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: _inlineSpans(trimmed, baseStyle),
      ),
    );
  }

  List<TextSpan> _inlineSpans(String value, TextStyle baseStyle) {
    final spans = <TextSpan>[];
    final pattern = RegExp(
      r'(\*\*[^*]+\*\*|__[^_]+__|\*[^*]+\*|_[^_]+_|\[[^\]]+\]\([^)]+\)|`[^`]+`)',
    );
    var cursor = 0;
    for (final match in pattern.allMatches(value)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: value.substring(cursor, match.start)));
      }
      final token = match.group(0) ?? '';
      if (token.startsWith('**') || token.startsWith('__')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        );
      } else if (token.startsWith('*') || token.startsWith('_')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      } else if (token.startsWith('`')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: TextStyle(
              backgroundColor: Colors.grey.shade200,
              fontFamily: 'monospace',
            ),
          ),
        );
      } else {
        final link = RegExp(r'^\[([^\]]+)\]\([^)]+\)$').firstMatch(token);
        spans.add(
          TextSpan(
            text: link?.group(1) ?? token,
            style: const TextStyle(
              color: kAppPrimary,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }
      cursor = match.end;
    }
    if (cursor < value.length) {
      spans.add(TextSpan(text: value.substring(cursor)));
    }
    return spans;
  }
}

class _ListStoryLine extends StatelessWidget {
  final String marker;
  final String content;
  final TextStyle baseStyle;

  const _ListStoryLine({
    required this.marker,
    required this.content,
    required this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30,
          child: Text(
            marker,
            style: baseStyle.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: _FormattedStoryLine(line: content, baseStyle: baseStyle),
        ),
      ],
    );
  }
}

/// =============================================================================
/// READ ALOUD BAR
/// =============================================================================

class _ReadAloudBar extends StatelessWidget {
  final bool isSpeaking;
  final bool isPreparing;
  final bool isPaused;
  final VoidCallback onPressed;
  final VoidCallback? onStop;

  const _ReadAloudBar({
    required this.isSpeaking,
    required this.isPreparing,
    required this.isPaused,
    required this.onPressed,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final active = isSpeaking || isPreparing;
    final label = isPreparing
        ? 'Preparing voice...'
        : active
            ? 'Pause reading'
            : isPaused
                ? 'Resume reading'
                : 'Read aloud';

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: isPreparing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(active
                    ? Icons.pause_circle_outline
                    : isPaused
                        ? Icons.play_circle_outline
                        : Icons.volume_up),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: active ? Colors.orange.shade800 : Colors.purple,
              side: BorderSide(
                color:
                    active ? Colors.orange.shade200 : const Color(0xFFE0C6F2),
              ),
              padding: const EdgeInsets.symmetric(vertical: 7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (onStop != null) ...[
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: onStop,
            tooltip: 'Stop and reset',
            icon: const Icon(Icons.stop),
          ),
        ],
      ],
    );
  }
}

/// =============================================================================
/// AUTHOR ROW
/// =============================================================================

class _AuthorRow extends StatelessWidget {
  final String name;
  final String handle;
  final VoidCallback? onTap;

  const _AuthorRow({
    required this.name,
    required this.handle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
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
      ),
    );
  }
}
