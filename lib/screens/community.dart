import 'package:flutter/material.dart';
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

/// COMMUNITY SCREEN ---------------------------------------------------------
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _selectedIndex = 0;
  late List<StoryPost> posts;

  @override
  void initState() {
    super.initState();
    posts = demoPosts;
  }

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      posts.shuffle();
    });
  }

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
        type: BottomNavigationBarType.fixed, // keeps all items visible
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: kAppPrimary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        iconSize: 24, // smaller icons
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
          ),BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),

        ],
      ),
    );

  }

  Widget _buildCommunityFeed(double screenWidth) {
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
              delegate: StorySearchDelegate(posts),
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        color: Colors.purple,
        onRefresh: _refresh,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: posts.length,
          itemBuilder: (context, index) => StoryCard(
            post: posts[index],
            onLike: () =>
                setState(() => posts[index] = posts[index].toggleLike()),
            onOpen: () => _openStory(context, posts[index]),
            onComment: () => _openComments(context, posts[index]),
            onPerspective: (perspectiveIndex) {
              setState(() {
                posts[index] = posts[index].shiftPerspective(perspectiveIndex);
              });
            },
          ),
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
                          onPressed: () {
                            if (controller.text.isNotEmpty) {
                              setSheetState(() {
                                final newComment =
                                Comment(user: "You", text: controller.text);
                                post.commentList.add(newComment);
                                final index = posts
                                    .indexWhere((p) => p.id == post.id);
                                if (index != -1) {
                                  posts[index] = StoryPost(
                                    id: post.id,
                                    author: post.author,
                                    handle: post.handle,
                                    title: post.title,
                                    excerpt: post.excerpt,
                                    likes: post.likes,
                                    comments: post.commentList.length,
                                    likedByMe: post.likedByMe,
                                    accent: post.accent,
                                    perspectiveIndex: post.perspectiveIndex,
                                    imageUrl: post.imageUrl,
                                    commentList: post.commentList,
                                  );
                                }
                              });
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

/// STORY CARD ----------------------------------------------------------------
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
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth < 600 ? 16 : screenWidth * 0.15,
        vertical: 10,
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(22),
        splashColor: Colors.purple.withOpacity(0.1),
        highlightColor: Colors.purple.withOpacity(0.05),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.withOpacity(0.1), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.purple.withOpacity(0.4),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Card(
            margin: EdgeInsets.zero,
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AuthorRow(name: post.author, handle: post.handle),

                if (post.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                    child: Image.network(
                      post.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 200,
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        post.excerpt,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style:
                        Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _EngagementBar(
                        liked: post.likedByMe,
                        likes: post.likes,
                        comments: post.comments,
                        onLike: onLike,
                        onRead: onOpen,
                        onComment: onComment,
                        onPerspective: onPerspective,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('@$handle',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const Spacer(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'save') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Story saved!")),
                );
              } else if (value == 'reshare') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Story reshared!")),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'save',
                child: Row(
                  children: [
                    Icon(Icons.bookmark_outline, color: const Color(0xFF7B1FA2)),
                    SizedBox(width: 8),
                    Text("Save"),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reshare',
                child: Row(
                  children: [
                    Icon(Icons.share, color:const Color(0xFF7B1FA2)),
                    SizedBox(width: 8),
                    Text("Reshare"),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EngagementBar extends StatelessWidget {
  final bool liked;
  final int likes;
  final int comments;
  final VoidCallback onLike;
  final VoidCallback onRead;
  final VoidCallback onComment;
  final void Function(int) onPerspective;

  const _EngagementBar({
    required this.liked,
    required this.likes,
    required this.comments,
    required this.onLike,
    required this.onRead,
    required this.onComment,
    required this.onPerspective,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onLike,
          icon: Icon(
            liked ? Icons.favorite : Icons.favorite_border,
            color: liked ? Colors.red : Colors.purple,
          ),
        ),
        Text('$likes'),
        const SizedBox(width: 12),
        IconButton(
          onPressed: onComment,
          icon: const Icon(Icons.mode_comment_outlined, color: Colors.purple),
        ),
        Text('$comments'),
        const SizedBox(width: 12),
        PopupMenuButton<int>(
          icon: const Icon(Icons.sync_alt, color: Colors.purple),
          onSelected: (value) => onPerspective(value),
          itemBuilder: (context) => const [
            PopupMenuItem(value: 0, child: Text("First Person")),
            PopupMenuItem(value: 1, child: Text("Second Person")),
            PopupMenuItem(value: 2, child: Text("Third Person")),
          ],
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: onRead,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          icon: const Icon(Icons.menu_book, size: 18),
          label: const Text("Read"),
        ),
      ],
    );
  }
}

/// READER -------------------------------------------------------------------
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
    commentList: [],
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
    commentList: [],
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
    accent:const Color(0xFF7B1FA2),
    imageUrl: 'https://picsum.photos/id/1025/600/300',
    commentList: [],
  ),
];
