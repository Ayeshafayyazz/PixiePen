import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme.dart';
import 'community.dart';
import 'write_story_screen.dart';

class MyStoriesScreen extends StatefulWidget {
  const MyStoriesScreen({super.key});

  @override
  State<MyStoriesScreen> createState() => _MyStoriesScreenState();
}

class _MyStoriesScreenState extends State<MyStoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  User? _user;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _user = FirebaseAuth.instance.currentUser;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: kAppPrimary,
          title: const Text("📖 My Stories"),
        ),
        body: const Center(
          child: Text("Please log in to view your stories"),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: kAppPrimary,
        centerTitle: true,
        title: const Text(
          "📖 My Stories",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'My Stories'),
            Tab(text: 'Drafts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStoriesTab(status: 'published'),
          _buildStoriesTab(status: 'draft'),
        ],
      ),
    );
  }

  Widget _buildStoriesTab({required String status}) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('stories')
          .where('authorId', isEqualTo: _user!.uid)
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kAppPrimary));
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final stories = snapshot.data?.docs ?? [];

        if (stories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  status == 'published'
                      ? Icons.edit_outlined
                      : Icons.drafts_outlined,
                  size: 60,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  status == 'published'
                      ? "No published stories yet"
                      : "No drafts yet",
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: stories.length,
          itemBuilder: (context, index) {
            final storyDoc = stories[index];
            final storyId = storyDoc.id;
            final data = storyDoc.data();
            final post = _buildStoryPost(storyId, data);

            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                onTap: () => _openStory(context, post),
                leading: data['coverUrl'] != null && data['coverUrl'] != ''
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          data['coverUrl'],
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: kAppPrimary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.book, color: Colors.white),
                      ),
                title: Text(
                  data['title'] ?? 'Untitled',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data['wordCount'] ?? _wordCount(data['body'])} words',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.favorite, size: 14, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          '${data['likes'] ?? 0}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WriteStoryScreen(storyId: storyId),
                        ),
                      );
                    } else if (value == 'delete') {
                      _deleteStory(storyId, post.title);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  StoryPost _buildStoryPost(String storyId, Map<String, dynamic> data) {
    final title = (data['title'] as String?) ?? 'Untitled';
    final body = (data['body'] as String?) ?? '';
    final cover = (data['coverUrl'] as String?);
    final authorName =
        (data['authorName'] as String?) ?? _user?.displayName ?? 'You';
    final handle = (data['handle'] as String?) ??
        authorName.replaceAll(' ', '').toLowerCase();
    final likedBy = (data['likedBy'] as List?) ?? [];
    final imageUrl = cover != null && cover.isNotEmpty
        ? cover
        : 'https://picsum.photos/seed/$storyId/600/300';

    return StoryPost(
      id: storyId,
      author: authorName,
      handle: handle,
      title: title,
      excerpt: body,
      likes: _readInt(data['likes']),
      comments: _readInt(data['comments']),
      likedByMe: likedBy.contains(_user?.uid),
      accent: kAppPrimary,
      imageUrl: imageUrl,
    );
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  int _wordCount(dynamic body) {
    if (body is! String || body.trim().isEmpty) return 0;
    return body.trim().split(RegExp(r'\s+')).length;
  }

  void _openStory(BuildContext context, StoryPost post) {
    final storyService = StoryService();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryReaderPage(
          post: post,
          service: storyService,
          userId: _user!.uid,
          userName: _user!.displayName ?? _user!.email ?? 'User',
        ),
      ),
    );
  }

  void _deleteStory(String storyId, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Story?"),
        content: Text("Delete \"$title\"?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await _db.collection('stories').doc(storyId).delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("🗑️ Deleted $title")),
              );
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
