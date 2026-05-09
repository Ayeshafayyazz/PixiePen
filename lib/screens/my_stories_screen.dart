import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/mappers/story_post_mapper.dart';
import '../services/content_moderation_service.dart';
import '../services/gemini_service.dart';
import '../domain/models/story_post.dart';
import '../services/story_service.dart';
import '../shared/ui/empty_widget.dart';
import '../shared/ui/error_widget_custom.dart';
import '../shared/ui/loading_widget.dart';
import '../widgets/moderation_ui.dart';
import 'badge_screen.dart';
import 'community.dart';
import 'ebook_screen.dart';
import 'theme.dart';
import 'write_story_screen.dart';

class MyStoriesScreen extends StatefulWidget {
  final String? initialStatus;
  final String? highlightedStoryId;

  const MyStoriesScreen({
    super.key,
    this.initialStatus,
    this.highlightedStoryId,
  });

  @override
  State<MyStoriesScreen> createState() => _MyStoriesScreenState();
}

class _MyStoriesScreenState extends State<MyStoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ContentModerationService _moderationService =
      ContentModerationService();
  final GeminiService _geminiService = GeminiService();
  User? _user;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _initialTabIndex(widget.initialStatus),
    );
    _user = FirebaseAuth.instance.currentUser;
  }

  int _initialTabIndex(String? status) {
    if (status == 'pending_parent_approval') return 1;
    if (status == 'rejected') return 2;
    return 0;
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
        body: const EmptyWidget(message: 'Please log in to view your stories'),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F3FF),
      appBar: AppBar(
        backgroundColor: kAppPrimary,
        foregroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back to Community',
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const CommunityScreen()),
              (route) => false,
            );
          },
          icon: const Icon(Icons.arrow_back),
        ),
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
            return const LoadingWidget(message: 'Loading your stories...');
          }

          if (snapshot.hasError) {
            return ErrorWidgetCustom(message: 'Error: ${snapshot.error}');
          }

          final stories = (snapshot.data?.docs ?? [])
              .map((doc) => _StoryDashboardItem.fromDoc(doc, user))
              .toList()
            ..sort(_compareRecentStoryActivity);

          final published =
              stories.where((story) => story.status == 'published').toList();
          final pending = stories
              .where((story) => story.status == 'pending_parent_approval')
              .toList();
          final rejected = stories
              .where((story) => story.approvalStatus == 'rejected')
              .toList();
          final totalLikes =
              stories.fold(0, (total, story) => total + story.likes);
          final weekStart = DateTime.now().subtract(const Duration(days: 7));
          final storiesThisWeek = stories
              .where((story) => story.createdAt.isAfter(weekStart))
              .length;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _db
                .collection('storyLikes')
                .where('authorId', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, likeSnap) {
              final likesThisWeek = (likeSnap.data?.docs ?? [])
                  .where(
                    (doc) => _readBadgeDate(doc.data()['createdAt'])
                        .isAfter(weekStart),
                  )
                  .length;

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _db
                    .collection('savedStories')
                    .where('authorId', isEqualTo: user.uid)
                    .snapshots(),
                builder: (context, saveSnap) {
                  final savesThisWeek = (saveSnap.data?.docs ?? [])
                      .where(
                        (doc) =>
                            _readBadgeDate(doc.data()['savedAt']).isAfter(
                          weekStart,
                        ),
                      )
                      .length;
                  final badges = BadgeEngine.getBadges(
                    storyCount: stories.length,
                    likes: totalLikes,
                    storiesThisWeek: storiesThisWeek,
                    likesThisWeek: likesThisWeek,
                    savesThisWeek: savesThisWeek,
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Material(
                          color: Colors.white,
                          child: TabBar(
                            controller: _tabController,
                            isScrollable: false,
                            padding: EdgeInsets.zero,
                            labelPadding: EdgeInsets.zero,
                            indicatorColor: kAppPrimary,
                            labelColor: kAppPrimary,
                            unselectedLabelColor: Colors.grey.shade600,
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                            unselectedLabelStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            tabs: [
                              Tab(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child:
                                      Text('Published (${published.length})'),
                                ),
                              ),
                              Tab(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('Pending (${pending.length})'),
                                ),
                              ),
                              Tab(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('Sent Back (${rejected.length})'),
                                ),
                              ),
                            ],
                          ),
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
                              onViewFeedback: _showParentFeedback,
                              highlightedStoryId: widget.highlightedStoryId,
                            ),
                            _StoryList(
                              status: 'pending_parent_approval',
                              stories: pending,
                              onOpen: _openStory,
                              onEdit: _editStory,
                              onPublish: _publishStory,
                              onMakeEbook: _openEbookCreator,
                              onDelete: _deleteStory,
                              onViewFeedback: _showParentFeedback,
                              highlightedStoryId: widget.highlightedStoryId,
                            ),
                            _StoryList(
                              status: 'rejected',
                              stories: rejected,
                              onOpen: _openStory,
                              onEdit: _editStory,
                              onPublish: _publishStory,
                              onMakeEbook: _openEbookCreator,
                              onDelete: _deleteStory,
                              onViewFeedback: _showParentFeedback,
                              highlightedStoryId: widget.highlightedStoryId,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
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
      await ModerationUi.showBlockDialog(
        context,
        result: moderation,
        surface: ModerationSurface.story,
      );
      return;
    }

    final geminiSafe = await _geminiService.moderateContent(
      '${story.title}\n\n${story.body}',
    );
    if (!geminiSafe) {
      if (!mounted) return;
      await ModerationUi.showPlainMessage(
        context,
        message: ContentModerationService.childFriendlyWarning,
        surface: ModerationSurface.story,
      );
      return;
    }

    final user = _user;
    if (user == null) return;

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};
    final role = (userData['role'] as String?) ?? 'child';
    final isChild = role != 'parent';
    final parentEmail =
        (userData['parentEmail'] as String?)?.trim().toLowerCase();

    if (isChild && (parentEmail == null || parentEmail.isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please add your parent Gmail in Edit Profile before publishing.',
          ),
        ),
      );
      return;
    }

    final nextStatus = isChild ? 'pending_parent_approval' : 'published';
    await _db.collection('stories').doc(story.id).set({
      'status': nextStatus,
      'isPublish': nextStatus == 'published',
      'parentEmail': isChild ? parentEmail : null,
      'approvalStatus': isChild ? 'pending' : 'approved',
      'parentFeedback': FieldValue.delete(),
      'moderation': {
        'isSafe': true,
        'flagReason': null,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (isChild) {
      await _notifyParentForApproval(
        storyId: story.id,
        title: story.title,
        authorName: story.authorName,
        parentEmail: parentEmail!,
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isChild
              ? '${story.title} sent to your parent for approval.'
              : '${story.title} published',
        ),
      ),
    );
  }

  Future<void> _notifyParentForApproval({
    required String storyId,
    required String title,
    required String authorName,
    required String parentEmail,
  }) async {
    final parentSnap = await _db
        .collection('users')
        .where('email', isEqualTo: parentEmail.trim().toLowerCase())
        .where('role', isEqualTo: 'parent')
        .limit(1)
        .get();

    if (parentSnap.docs.isEmpty) return;

    final parentData = parentSnap.docs.first.data();
    if (parentData['notificationsEnabled'] == false) return;

    await _db.collection('notifications').add({
      'toUserId': parentSnap.docs.first.id,
      'fromUserId': _user?.uid,
      'fromUserName': authorName,
      'type': 'parent_approval',
      'storyId': storyId,
      'storyTitle': title,
      'message': '$authorName wants to publish "$title"',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
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

  void _showParentFeedback(_StoryDashboardItem story) {
    final feedback = story.parentFeedbackText;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Feedback'),
        content: Text(
          feedback.isEmpty ? 'No feedback comment was provided.' : feedback,
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _editStory(story);
            },
            child: const Text('Edit Story'),
          ),
        ],
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
              // Cascade delete: Remove this story from all ebooks
              await _removeStoryFromAllEbooks(story.id);
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

  Future<void> _removeStoryFromAllEbooks(String storyId) async {
    try {
      final ebooksSnapshot = await _db
          .collection('ebooks')
          .where('userId', isEqualTo: _user?.uid)
          .get();
      for (final ebookDoc in ebooksSnapshot.docs) {
        final storyIds = List<String>.from(ebookDoc['storyIds'] ?? []);
        if (storyIds.contains(storyId)) {
          storyIds.remove(storyId);
          await ebookDoc.reference.update({'storyIds': storyIds});
        }
      }
    } catch (error) {
      // Silently handle error - deletion should not fail due to ebook cleanup
      debugPrint('Error removing story from ebooks: $error');
    }
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: badges.map((badge) {
        final unlocked = badge['unlocked'] == true;
        final icon = badge['icon'] as IconData? ?? Icons.emoji_events;

        return Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color:
                unlocked ? Colors.white : Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(
            icon,
            color: unlocked ? kAppPrimary : Colors.white54,
            size: 18,
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
  final ValueChanged<_StoryDashboardItem> onViewFeedback;
  final String? highlightedStoryId;

  const _StoryList({
    required this.status,
    required this.stories,
    required this.onOpen,
    required this.onEdit,
    required this.onPublish,
    required this.onMakeEbook,
    required this.onDelete,
    required this.onViewFeedback,
    required this.highlightedStoryId,
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
          onViewFeedback: () => onViewFeedback(story),
          highlighted: story.id == highlightedStoryId,
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
    final isPending = status == 'pending_parent_approval';
    final isRejected = status == 'rejected';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPublished
                  ? Icons.auto_stories
                  : isPending
                      ? Icons.hourglass_empty
                      : isRejected
                          ? Icons.assignment_return
                          : Icons.edit_note,
              color: Colors.grey.shade500,
              size: 64,
            ),
            const SizedBox(height: 14),
            Text(
              isPublished
                  ? 'No published stories yet'
                  : isPending
                      ? 'No stories waiting for approval'
                      : isRejected
                          ? 'No stories sent back'
                          : 'No drafts yet',
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
                  : isPending
                      ? 'Stories sent to your parent for approval appear here.'
                      : isRejected
                          ? 'Stories your parent sent back for editing appear here.'
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
  final VoidCallback onViewFeedback;
  final bool highlighted;

  const _StoryManagementCard({
    required this.story,
    required this.onOpen,
    required this.onEdit,
    required this.onPublish,
    required this.onMakeEbook,
    required this.onDelete,
    required this.onViewFeedback,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlighted ? kAppPrimary : const Color(0xFFE2D9F3),
          width: highlighted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                          _StatusChip(
                            status: story.status,
                            approvalStatus: story.approvalStatus,
                          ),
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
                      const SizedBox(height: 6),
                      Text(
                        story.approvalMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: story.approvalColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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
                _EngagementPill(
                  icon: Icons.star,
                  label: story.ratingLabel,
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
                if (story.approvalStatus == 'rejected')
                  _ActionButton(
                    icon: Icons.comment,
                    label: 'Feedback',
                    onPressed: onViewFeedback,
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
  final String approvalStatus;

  const _StatusChip({
    required this.status,
    required this.approvalStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isPublished = status == 'published';
    final isPending = status == 'pending_parent_approval';
    final isRejected = approvalStatus == 'rejected';
    final color = isPublished
        ? Colors.green.shade700
        : isPending
            ? Colors.blue.shade700
            : isRejected
                ? Colors.orange.shade800
                : Colors.orange.shade800;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isPublished
            ? 'Published'
            : isPending
                ? 'Pending'
                : isRejected
                    ? 'Sent Back'
                    : 'Draft',
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
  final List<Map<String, dynamic>>? contentBlocks;
  final String authorName;
  final String handle;
  final String status;
  final String approvalStatus;
  final String? coverUrl;
  final int wordCount;
  final int likes;
  final int comments;
  final int ratingCount;
  final double averageRating;
  final List likedBy;
  final Map<String, dynamic>? parentFeedback;
  final DateTime createdAt;
  final DateTime updatedAt;

  const _StoryDashboardItem({
    required this.id,
    required this.title,
    required this.body,
    this.contentBlocks,
    required this.authorName,
    required this.handle,
    required this.status,
    required this.approvalStatus,
    required this.coverUrl,
    required this.wordCount,
    required this.likes,
    required this.comments,
    required this.ratingCount,
    required this.averageRating,
    required this.likedBy,
    required this.parentFeedback,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _StoryDashboardItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    User user,
  ) {
    final data = doc.data();
    final authorName = (data['authorName'] as String?) ??
        user.displayName ??
        user.email?.split('@').first ??
        'You';
    final mappedPost = StoryPostMapper.fromFirestoreMap(
      storyId: doc.id,
      data: data,
      currentUserId: user.uid,
      accent: kAppPrimary,
      fallbackAuthor: authorName,
    );
    final title = mappedPost.title.trim();
    final body = mappedPost.excerpt;
    final contentBlocks = mappedPost.contentBlocks;

    return _StoryDashboardItem(
      id: doc.id,
      title: title.isEmpty ? 'Untitled' : title,
      body: body,
      contentBlocks: contentBlocks,
      authorName: mappedPost.author,
      handle: mappedPost.handle,
      status: _readStatus(data['status']),
      approvalStatus: (data['approvalStatus'] as String?) ?? 'not_required',
      coverUrl: data['coverUrl'] as String?,
      wordCount: _readInt(data['wordCount'], fallback: _wordCount(body)),
      likes: mappedPost.likes,
      comments: mappedPost.comments,
      ratingCount: mappedPost.ratingCount,
      averageRating: mappedPost.averageRating,
      likedBy: (data['likedBy'] as List?) ?? const [],
      parentFeedback: _readMap(data['parentFeedback']),
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

  String get approvalMessage {
    if (status == 'published') return 'Published in Community';
    if (status == 'pending_parent_approval') {
      return 'Waiting for parent approval';
    }
    if (approvalStatus == 'rejected') {
      return 'Sent back for editing';
    }
    return 'Draft saved';
  }

  String get parentFeedbackText {
    final feedback = parentFeedback?['feedback'];
    return feedback is String ? feedback.trim() : '';
  }

  Color get approvalColor {
    if (status == 'published') return Colors.green.shade700;
    if (status == 'pending_parent_approval') return Colors.blue.shade700;
    if (approvalStatus == 'rejected') return Colors.orange.shade800;
    return Colors.grey.shade700;
  }

  String get ratingLabel {
    if (ratingCount == 0) return 'No ratings';
    return '${averageRating.toStringAsFixed(1)} rating';
  }

  StoryPost toPost({required String userId}) {
    return StoryPostMapper.fromFirestoreMap(
      storyId: id,
      data: {
        'authorName': authorName,
        'handle': handle,
        'title': title,
        'body': body,
        'likes': likes,
        'comments': comments,
        'ratingCount': ratingCount,
        'averageRating': averageRating,
        'likedBy': likedBy,
        'coverUrl': coverUrl,
        'content': contentBlocks,
      },
      currentUserId: userId,
      accent: kAppPrimary,
      fallbackAuthor: authorName,
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

  static Map<String, dynamic>? _readMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static String _readStatus(dynamic value) {
    if (value == 'published') return 'published';
    if (value == 'pending_parent_approval') return 'pending_parent_approval';
    return 'draft';
  }
}

int _compareRecentStoryActivity(
  _StoryDashboardItem a,
  _StoryDashboardItem b,
) {
  return b.updatedAt.compareTo(a.updatedAt);
}

DateTime _readBadgeDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.fromMillisecondsSinceEpoch(0);
}
