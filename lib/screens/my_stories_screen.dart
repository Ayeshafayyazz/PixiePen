import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/content_moderation_service.dart';
import 'badge_screen.dart';
import 'community.dart';
import 'ebook_screen.dart';
import 'theme.dart';
import 'write_story_screen.dart';

class MyStoriesScreen extends StatefulWidget {
  const MyStoriesScreen({super.key});

  @override
  State<MyStoriesScreen> createState() => _MyStoriesScreenState();
}

class _MyStoriesScreenState extends State<MyStoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ContentModerationService _moderationService =
      ContentModerationService();
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
    final user = _user;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: kAppPrimary,
          title: const Text('My Stories'),
        ),
        body: const Center(child: Text('Please log in to view your stories')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F3FF),
      appBar: AppBar(
        backgroundColor: kAppPrimary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'My Stories',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Write Story',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WriteStoryScreen()),
              );
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _db
            .collection('stories')
            .where('authorId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kAppPrimary),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final stories = (snapshot.data?.docs ?? [])
              .map((doc) => _StoryDashboardItem.fromDoc(doc, user))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          final published =
              stories.where((story) => story.status == 'published').toList();
          final drafts =
              stories.where((story) => story.status == 'draft').toList();
          final totalLikes =
              stories.fold(0, (total, story) => total + story.likes);
          final badges = BadgeEngine.getBadges(
            storyCount: stories.length,
            likes: totalLikes,
          );
          final unlockedBadges =
              badges.where((badge) => badge['unlocked'] == true).length;
          final nextBadge = badges
              .where((badge) => badge['unlocked'] != true)
              .cast<Map<String, dynamic>?>()
              .firstWhere((_) => true, orElse: () => null);

          return Column(
            children: [
              _BadgeHeader(
                badges: badges,
                unlockedBadges: unlockedBadges,
                nextBadge: nextBadge,
              ),
              Material(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: kAppPrimary,
                  labelColor: kAppPrimary,
                  unselectedLabelColor: Colors.grey.shade600,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                  tabs: [
                    Tab(text: 'Published (${published.length})'),
                    Tab(text: 'Drafts (${drafts.length})'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _StoryList(
                      status: 'published',
                      stories: published,
                      onOpen: _openStory,
                      onEdit: _editStory,
                      onPublish: _publishStory,
                      onMakeEbook: _openEbookCreator,
                      onDelete: _deleteStory,
                    ),
                    _StoryList(
                      status: 'draft',
                      stories: drafts,
                      onOpen: _openStory,
                      onEdit: _editStory,
                      onPublish: _publishStory,
                      onMakeEbook: _openEbookCreator,
                      onDelete: _deleteStory,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _editStory(_StoryDashboardItem story) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WriteStoryScreen(storyId: story.id)),
    );
  }

  void _openEbookCreator() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EbookCreatorScreen()),
    );
  }

  Future<void> _publishStory(_StoryDashboardItem story) async {
    final moderation = _moderationService.moderateStory(
      title: story.title,
      body: story.body,
    );

    if (!moderation.isSafe) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(ContentModerationService.childFriendlyWarning),
        ),
      );
      return;
    }

    await _db.collection('stories').doc(story.id).set({
      'status': 'published',
      'isPublish': true,
      'moderation': {
        'isSafe': true,
        'flagReason': null,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${story.title} published')),
    );
  }

  void _openStory(_StoryDashboardItem story) {
    final storyService = StoryService();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryReaderPage(
          post: story.toPost(userId: _user!.uid),
          service: storyService,
          userId: _user!.uid,
          userName: _user!.displayName ?? _user!.email ?? 'User',
        ),
      ),
    );
  }

  void _deleteStory(_StoryDashboardItem story) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Story?'),
        content: Text('Delete "${story.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _db.collection('stories').doc(story.id).delete();
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted ${story.title}')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _BadgeHeader extends StatelessWidget {
  final List<Map<String, dynamic>> badges;
  final int unlockedBadges;
  final Map<String, dynamic>? nextBadge;

  const _BadgeHeader({
    required this.badges,
    required this.unlockedBadges,
    required this.nextBadge,
  });

  @override
  Widget build(BuildContext context) {
    final totalBadges = badges.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        color: kAppPrimary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Badges',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '$unlockedBadges of $totalBadges unlocked',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$unlockedBadges/$totalBadges',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _BadgeIconRow(badges: badges),
          const SizedBox(height: 10),
          _BadgeProgressStrip(
            unlockedBadges: unlockedBadges,
            totalBadges: totalBadges,
            nextBadge: nextBadge,
          ),
        ],
      ),
    );
  }
}

class _BadgeIconRow extends StatelessWidget {
  final List<Map<String, dynamic>> badges;

  const _BadgeIconRow({required this.badges});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: badges.map((badge) {
        final unlocked = badge['unlocked'] == true;
        final icon = badge['icon'] as IconData? ?? Icons.emoji_events;

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: unlocked
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(
              icon,
              color: unlocked ? kAppPrimary : Colors.white54,
              size: 18,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _BadgeProgressStrip extends StatelessWidget {
  final int unlockedBadges;
  final int totalBadges;
  final Map<String, dynamic>? nextBadge;

  const _BadgeProgressStrip({
    required this.unlockedBadges,
    required this.totalBadges,
    required this.nextBadge,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalBadges == 0 ? 0.0 : unlockedBadges / totalBadges;
    final badge = nextBadge;
    final icon = badge?['icon'] as IconData? ?? Icons.emoji_events;
    final title =
        badge == null ? 'All badges unlocked' : 'Next badge: ${badge['label']}';
    final subtitle = badge == null
        ? 'Great work. Keep writing and sharing stories.'
        : badge['desc'] as String? ?? '';

    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StoryList extends StatelessWidget {
  final String status;
  final List<_StoryDashboardItem> stories;
  final ValueChanged<_StoryDashboardItem> onOpen;
  final ValueChanged<_StoryDashboardItem> onEdit;
  final ValueChanged<_StoryDashboardItem> onPublish;
  final VoidCallback onMakeEbook;
  final ValueChanged<_StoryDashboardItem> onDelete;

  const _StoryList({
    required this.status,
    required this.stories,
    required this.onOpen,
    required this.onEdit,
    required this.onPublish,
    required this.onMakeEbook,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) {
      return _EmptyStoriesState(status: status);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: stories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final story = stories[index];
        return _StoryManagementCard(
          story: story,
          onOpen: () => onOpen(story),
          onEdit: () => onEdit(story),
          onPublish: story.status == 'draft' ? () => onPublish(story) : null,
          onMakeEbook: onMakeEbook,
          onDelete: () => onDelete(story),
        );
      },
    );
  }
}

class _EmptyStoriesState extends StatelessWidget {
  final String status;

  const _EmptyStoriesState({required this.status});

  @override
  Widget build(BuildContext context) {
    final isPublished = status == 'published';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPublished ? Icons.auto_stories : Icons.edit_note,
              color: Colors.grey.shade500,
              size: 64,
            ),
            const SizedBox(height: 14),
            Text(
              isPublished ? 'No published stories yet' : 'No drafts yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.black87,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isPublished
                  ? 'Published stories appear here with likes, comments, and eBook options.'
                  : 'Drafts appear here so you can edit, publish, or prepare them for an eBook.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryManagementCard extends StatelessWidget {
  final _StoryDashboardItem story;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback? onPublish;
  final VoidCallback onMakeEbook;
  final VoidCallback onDelete;

  const _StoryManagementCard({
    required this.story,
    required this.onOpen,
    required this.onEdit,
    required this.onPublish,
    required this.onMakeEbook,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2D9F3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StoryCover(url: story.coverUrl, seed: story.id),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _StatusChip(status: story.status),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                story.updatedLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          story.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          story.preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _EngagementPill(
                    icon: Icons.notes,
                    label: '${story.wordCount} words',
                  ),
                  _EngagementPill(
                    icon: Icons.favorite,
                    label: '${story.likes} likes',
                  ),
                  _EngagementPill(
                    icon: Icons.chat_bubble,
                    label: '${story.comments} comments',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionButton(
                    icon: Icons.edit,
                    label: 'Edit',
                    onPressed: onEdit,
                  ),
                  if (onPublish != null)
                    _ActionButton(
                      icon: Icons.public,
                      label: 'Publish',
                      onPressed: onPublish!,
                    )
                  else
                    _ActionButton(
                      icon: Icons.menu_book,
                      label: 'Read',
                      onPressed: onOpen,
                    ),
                  _ActionButton(
                    icon: Icons.auto_stories,
                    label: 'eBook',
                    onPressed: onMakeEbook,
                  ),
                  _ActionButton(
                    icon: Icons.delete_outline,
                    label: 'Delete',
                    foreground: Colors.redAccent,
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryCover extends StatelessWidget {
  final String? url;
  final String seed;

  const _StoryCover({required this.url, required this.seed});

  @override
  Widget build(BuildContext context) {
    final imageUrl = url != null && url!.isNotEmpty
        ? url!
        : 'https://picsum.photos/seed/$seed/160/160';

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        width: 82,
        height: 96,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 82,
          height: 96,
          color: kAppPrimary,
          child: const Icon(Icons.book, color: Colors.white),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isPublished = status == 'published';
    final color = isPublished ? Colors.green.shade700 : Colors.orange.shade800;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isPublished ? 'Published' : 'Draft',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EngagementPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EngagementPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1ECFA),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: kAppPrimary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? foreground;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground ?? kAppPrimary,
        side: BorderSide(
          color: (foreground ?? kAppPrimary).withValues(alpha: 0.35),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        minimumSize: const Size(0, 38),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _StoryDashboardItem {
  final String id;
  final String title;
  final String body;
  final String authorName;
  final String handle;
  final String status;
  final String? coverUrl;
  final int wordCount;
  final int likes;
  final int comments;
  final List likedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const _StoryDashboardItem({
    required this.id,
    required this.title,
    required this.body,
    required this.authorName,
    required this.handle,
    required this.status,
    required this.coverUrl,
    required this.wordCount,
    required this.likes,
    required this.comments,
    required this.likedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _StoryDashboardItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    User user,
  ) {
    final data = doc.data();
    final title = (data['title'] as String?)?.trim();
    final body = (data['body'] as String?) ?? '';
    final authorName = (data['authorName'] as String?) ??
        user.displayName ??
        user.email?.split('@').first ??
        'You';

    return _StoryDashboardItem(
      id: doc.id,
      title: title == null || title.isEmpty ? 'Untitled' : title,
      body: body,
      authorName: authorName,
      handle: (data['handle'] as String?) ??
          authorName.replaceAll(' ', '').toLowerCase(),
      status:
          (data['status'] as String?) == 'published' ? 'published' : 'draft',
      coverUrl: data['coverUrl'] as String?,
      wordCount: _readInt(data['wordCount'], fallback: _wordCount(body)),
      likes: _readInt(data['likes']),
      comments: _readInt(data['comments']),
      likedBy: (data['likedBy'] as List?) ?? const [],
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt'], fallback: data['createdAt']),
    );
  }

  String get preview {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return 'No story text yet.';
    return trimmed;
  }

  String get updatedLabel {
    final date = updatedAt;
    return '${date.month}/${date.day}/${date.year}';
  }

  StoryPost toPost({required String userId}) {
    final imageUrl = coverUrl != null && coverUrl!.isNotEmpty
        ? coverUrl!
        : 'https://picsum.photos/seed/$id/600/300';

    return StoryPost(
      id: id,
      author: authorName,
      handle: handle,
      title: title,
      excerpt: body,
      likes: likes,
      comments: comments,
      likedByMe: likedBy.contains(userId),
      accent: kAppPrimary,
      imageUrl: imageUrl,
    );
  }

  static int _readInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static int _wordCount(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  static DateTime _readDate(dynamic value, {dynamic fallback}) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (fallback != null) return _readDate(fallback);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
