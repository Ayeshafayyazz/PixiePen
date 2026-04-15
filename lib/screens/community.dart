// community_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'NotificationsPage.dart';
import 'ebook_screen.dart';
import 'my_stories_screen.dart';
import 'profile_screen.dart';
import 'theme.dart';
import 'write_story_screen.dart';

/// COMMENT MODEL -------------------------------------------------------------
class Comment {
  final String user;
  final String text;

  Comment({required this.user, required this.text});
}

/// STORY MODELS --------------------------------------------------------------
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
  final int perspectiveIndex;
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
    this.perspectiveIndex = 0,
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
    perspectiveIndex: perspectiveIndex,
    imageUrl: imageUrl,
    commentList: commentList,
  );

  StoryPost shiftPerspective(int index) {
    final perspectives = [
      'I was walking through the woods when the dragon appeared…',
      'You are walking through the woods when the dragon appears…',
      'They were walking through the woods when the dragon appeared…',
    ];
    return StoryPost(
      id: id,
      author: author,
      handle: handle,
      title: title,
      excerpt: perspectives[index],
      likes: likes,
      comments: comments,
      likedByMe: likedByMe,
      accent: accent,
      perspectiveIndex: index,
      imageUrl: imageUrl,
      commentList: commentList,
    );
  }
}

/// DEMO DATA ----------------------------------------------------------------
final demoPosts = <StoryPost>[
  StoryPost(
    id: '1',
    author: 'Ayaan',
    handle: 'ayaan',
    title: 'The Midnight Library Dragon',
    excerpt:
    'At exactly 12:00, the books began to whisper. One shelf slid open and a tiny dragon sneezed glitter…',
    likes: 42,
    comments: 9,
    likedByMe: false,
    accent: const Color(0xFF7B1FA2),
    imageUrl: 'https://picsum.photos/id/1015/600/300',
  ),
  StoryPost(
    id: '2',
    author: 'Hiba',
    handle: 'hibzz',
    title: 'My Invisible Bicycle',
    excerpt:
    'No one believed me until the muddy tire tracks magically curved around the garden gnome…',
    likes: 31,
    comments: 4,
    likedByMe: true,
    accent: const Color(0xFF7B1FA2),
    imageUrl: 'https://picsum.photos/id/1018/600/300',
  ),
  StoryPost(
    id: '3',
    author: 'Omar',
    handle: 'omar_codes',
    title: 'Map of the Whispering Woods',
    excerpt:
    'Every tree had a secret. If you listened closely, the leaves told you which path was brave enough…',
    likes: 54,
    comments: 12,
    likedByMe: false,
    accent: const Color(0xFF7B1FA2),
    imageUrl: 'https://picsum.photos/id/1025/600/300',
  ),
];

/// COMMUNITY SCREEN ---------------------------------------------------------
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _selectedIndex = 0;
  static const String _storiesCollection = 'stories';

  // placeholder for search delegate
  final List<StoryPost> _combinedPostsSnapshotPlaceholder = [];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final pages = [
      _buildCommunityFeed(screenWidth),
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

  Widget _buildCommunityFeed(double screenWidth) {
    final stream = FirebaseFirestore.instance
        .collection(_storiesCollection)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7B1FA2),
        title: const _BrandTitle(),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () => showSearch(
              context: context,
              delegate: StorySearchDelegate(_combinedPostsSnapshotPlaceholder),
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(
              Icons.notifications_outlined,
              color: Colors.white,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              );
            },
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
          stream: stream,
          builder: (context, snapshot) {
            final fetched = <StoryPost>[];
            if (snapshot.hasData && snapshot.data != null) {
              for (final doc in snapshot.data!.docs) {
                final data = doc.data();
                final id = doc.id;
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
                    : 'https://picsum.photos/seed/$id/600/300';

                fetched.add(StoryPost(
                  id: id,
                  author: author,
                  handle: handle,
                  title: title,
                  excerpt: body,
                  likes: likes,
                  comments: comments,
                  likedByMe: false,
                  accent: const Color(0xFF7B1FA2),
                  imageUrl: imageUrl,
                ));
              }
            }

            final combined = <StoryPost>[...demoPosts, ...fetched];
            _combinedPostsSnapshotPlaceholder.clear();
            _combinedPostsSnapshotPlaceholder.addAll(combined);

            if (combined.isEmpty) {
              return const Center(child: Text('No stories yet'));
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: combined.length,
              itemBuilder: (context, index) {
                final post = combined[index];
                return StoryCard(
                  post: post,
                  onLike: () {},
                  onOpen: () => _openStory(context, post),
                  onComment: () => _openComments(context, post),
                  onPerspective: (i) {},
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
        builder: (_) => StoryReaderPage(post: post),
      ),
    );
  }

  void _openComments(BuildContext context, StoryPost post) {
    final TextEditingController controller = TextEditingController();
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
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return SizedBox(
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
                    Expanded(
                      child: post.commentList.isEmpty
                          ? const Center(child: Text("No comments yet"))
                          : ListView.builder(
                        itemCount: post.commentList.length,
                        itemBuilder: (context, i) {
                          final c = post.commentList[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.purple,
                              child: Text(c.user[0].toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white)),
                            ),
                            title: Text(c.user),
                            subtitle: Text(c.text),
                          );
                        },
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                              hintText: "Write a comment...",
                              border: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.all(Radius.circular(20)),
                              ),
                              contentPadding:
                              EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.purple),
                          onPressed: () async {
                            if (controller.text.isNotEmpty) {
                              setSheetState(() {
                                final newComment =
                                Comment(user: "You", text: controller.text);
                                post.commentList.add(newComment);
                              });

                              try {
                                final docRef = FirebaseFirestore.instance
                                    .collection(_storiesCollection)
                                    .doc(post.id);
                                final doc = await docRef.get();
                                if (doc.exists) {
                                  await docRef.update({
                                    'comments': FieldValue.increment(1),
                                  });
                                }
                              } catch (_) {}

                              controller.clear();
                              setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// BRAND TITLE --------------------------------------------------------------
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

/// STORY CARD ---------------------------------------------------------------
class StoryCard extends StatelessWidget {
  final StoryPost post;
  final VoidCallback onLike;
  final VoidCallback onOpen;
  final VoidCallback onComment;
  final void Function(int) onPerspective;

  const StoryCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onOpen,
    required this.onComment,
    required this.onPerspective,
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
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                Text(
                                  '@${post.handle}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert,
                                color: Colors.white),
                            onSelected: (value) {
                              if (value == 'save') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Story saved!")),
                                );
                              } else if (value == 'reshare') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Story reshared!")),
                                );
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'save',
                                child: Row(
                                  children: [
                                    Icon(Icons.bookmark_outline,
                                        color: Color(0xFF7B1FA2)),
                                    SizedBox(width: 8),
                                    Text("Save"),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'reshare',
                                child: Row(
                                  children: [
                                    Icon(Icons.share,
                                        color: Color(0xFF7B1FA2)),
                                    SizedBox(width: 8),
                                    Text("Reshare"),
                                  ],
                                ),
                              ),
                            ],
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
                          icon: const Icon(Icons.chat_bubble_outline,
                              color: Colors.purple),
                          onPressed: onComment,
                        ),
                        Text("${post.comments}"),
                        const SizedBox(width: 16),
                        PopupMenuButton<int>(
                          icon: const Icon(Icons.sync_alt, color: Colors.purple),
                          onSelected: onPerspective,
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 0, child: Text("First Person")),
                            PopupMenuItem(value: 1, child: Text("Second Person")),
                            PopupMenuItem(value: 2, child: Text("Third Person")),
                          ],
                        ),
                        const Spacer(),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
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

/// STORY READER -------------------------------------------------------------
class StoryReaderPage extends StatelessWidget {
  final StoryPost post;
  const StoryReaderPage({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.purple,
        title: Text(post.title, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AuthorRow(name: post.author, handle: post.handle),
            const SizedBox(height: 12),
            if (post.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  post.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 220,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(height: 220, color: Colors.grey[200]),
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _longDummyText(post.excerpt),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _longDummyText(String seed) {
  return List<String>.generate(10, (i) => seed).join('\n\n');
}

/// AUTHOR ROW ---------------------------------------------------------------
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
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        overflow: TextOverflow.ellipsis)),
                Text('@$handle',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      overflow: TextOverflow.ellipsis,
                    )),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

/// SEARCH -------------------------------------------------------------------
class StorySearchDelegate extends SearchDelegate {
  final List<StoryPost> posts;
  StorySearchDelegate(this.posts);

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) {
    final matches = posts.where((p) =>
    p.title.toLowerCase().contains(query.toLowerCase()) ||
        p.excerpt.toLowerCase().contains(query.toLowerCase()));
    return ListView(
      children: matches
          .map((p) => StoryCard(
        post: p,
        onLike: () {},
        onOpen: () {},
        onComment: () {},
        onPerspective: (_) {},
      ))
          .toList(),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final matches = posts
        .where((p) => p.title.toLowerCase().startsWith(query.toLowerCase()))
        .toList();
    return ListView(
      children: matches
          .map((p) => ListTile(
        leading: const Icon(Icons.auto_stories, color: Colors.purple),
        title: Text(p.title),
        subtitle: Text('@${p.handle}'),
        onTap: () => close(context, p),
      ))
          .toList(),
    );
  }
}
