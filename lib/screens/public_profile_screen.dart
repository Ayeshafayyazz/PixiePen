import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/firestore_keys.dart';
import '../data/mappers/story_post_mapper.dart';
import '../domain/models/story_post.dart';
import '../services/follow_service.dart';
import '../services/story_service.dart';
import '../widgets/storage_image.dart';
import 'community.dart';
import 'theme.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  final String fallbackName;
  final String fallbackHandle;

  const PublicProfileScreen({
    super.key,
    required this.userId,
    this.fallbackName = 'PixiePen Author',
    this.fallbackHandle = 'pixiepen',
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FollowService _followService = FollowService();
  final StoryService _storyService = StoryService();
  bool _isUpdatingFollow = false;

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get _isOwnProfile => _currentUserId == widget.userId;

  Future<void> _toggleFollow() async {
    if (_isUpdatingFollow || _isOwnProfile || _currentUserId.isEmpty) return;
    setState(() => _isUpdatingFollow = true);
    try {
      await _followService.toggleFollow(
        currentUserId: _currentUserId,
        targetUserId: widget.userId,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update follow: $error')),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingFollow = false);
    }
  }

  void _openStory(StoryPost post) {
    final currentUser = FirebaseAuth.instance.currentUser;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryReaderPage(
          post: post,
          service: _storyService,
          userId: currentUser?.uid ?? '',
          userName: currentUser?.displayName ??
              currentUser?.email?.split('@').first ??
              'User',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FF),
      appBar: AppBar(
        backgroundColor: kAppPrimary,
        foregroundColor: Colors.white,
        title: Text(widget.fallbackName),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _followService.userStream(widget.userId),
        builder: (context, userSnap) {
          final profileData = userSnap.data?.data() ?? {};
          final name = _displayName(profileData);
          final handle = _handle(profileData, name);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _PublicProfileHeader(
                  name: name,
                  handle: handle,
                  photoUrl: _photoUrl(profileData),
                  followService: _followService,
                  userId: widget.userId,
                  currentUserId: _currentUserId,
                  isOwnProfile: _isOwnProfile,
                  isUpdatingFollow: _isUpdatingFollow,
                  onFollow: _toggleFollow,
                ),
              ),
              _PublishedStoriesSection(
                db: _db,
                authorId: widget.userId,
                currentUserId: _currentUserId,
                fallbackAuthor: name,
                onOpenStory: _openStory,
              ),
            ],
          );
        },
      ),
    );
  }

  String _displayName(Map<String, dynamic> data) {
    final username = data['username'] ?? data['displayName'];
    if (username is String && username.trim().isNotEmpty) {
      return username.trim();
    }
    return widget.fallbackName.trim().isEmpty
        ? 'PixiePen Author'
        : widget.fallbackName.trim();
  }

  String _handle(Map<String, dynamic> data, String name) {
    final handle = data['handle'];
    if (handle is String && handle.trim().isNotEmpty) {
      return handle.trim().replaceFirst('@', '');
    }
    final email = data['email'];
    if (email is String && email.trim().contains('@')) {
      return email.trim().split('@').first;
    }
    final fallback = widget.fallbackHandle.trim().replaceFirst('@', '');
    if (fallback.isNotEmpty) return fallback;
    return name.replaceAll(' ', '').toLowerCase();
  }

  String? _photoUrl(Map<String, dynamic> data) {
    final photoUrl = data['photoURL'] ?? data['profileImageUrl'];
    if (photoUrl is String && photoUrl.trim().isNotEmpty) {
      return photoUrl.trim();
    }
    return null;
  }
}

class _PublicProfileHeader extends StatelessWidget {
  final String name;
  final String handle;
  final String? photoUrl;
  final FollowService followService;
  final String userId;
  final String currentUserId;
  final bool isOwnProfile;
  final bool isUpdatingFollow;
  final VoidCallback onFollow;

  const _PublicProfileHeader({
    required this.name,
    required this.handle,
    required this.photoUrl,
    required this.followService,
    required this.userId,
    required this.currentUserId,
    required this.isOwnProfile,
    required this.isUpdatingFollow,
    required this.onFollow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE9DFF2))),
      ),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: currentUserId.isEmpty
            ? const Stream.empty()
            : followService.followStream(
                currentUserId: currentUserId,
                targetUserId: userId,
              ),
        builder: (context, followSnap) {
          final isFollowing = followSnap.data?.exists == true;

          return Column(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: kAppPrimary,
                backgroundImage:
                    photoUrl == null ? null : NetworkImage(photoUrl!),
                child: photoUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '@$handle',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StoryCount(userId: userId),
                  const SizedBox(width: 26),
                  _FollowCount(
                    stream: followService.followersStream(userId),
                    label: 'Followers',
                  ),
                  const SizedBox(width: 26),
                  _FollowCount(
                    stream: followService.followingStream(userId),
                    label: 'Following',
                  ),
                ],
              ),
              if (!isOwnProfile) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: 190,
                  child: ElevatedButton.icon(
                    onPressed: isUpdatingFollow || currentUserId.isEmpty
                        ? null
                        : onFollow,
                    icon: isUpdatingFollow
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(isFollowing
                            ? Icons.person_remove_alt_1
                            : Icons.person_add_alt_1),
                    label: Text(isFollowing ? 'Following' : 'Follow'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowing ? Colors.white : kAppPrimary,
                      foregroundColor: isFollowing ? kAppPrimary : Colors.white,
                      side: const BorderSide(color: kAppPrimary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _FollowCount extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String label;

  const _FollowCount({
    required this.stream,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        return _ProfileCount(
          value: snapshot.data?.docs.length ?? 0,
          label: label,
        );
      },
    );
  }
}

class _StoryCount extends StatelessWidget {
  final String userId;

  const _StoryCount({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.stories)
          .where(FirestoreStoryFields.authorId, isEqualTo: userId)
          .where(FirestoreStoryFields.status, isEqualTo: 'published')
          .snapshots(),
      builder: (context, snapshot) {
        return _ProfileCount(
          value: snapshot.data?.docs.length ?? 0,
          label: 'Stories',
        );
      },
    );
  }
}

class _ProfileCount extends StatelessWidget {
  final int value;
  final String label;

  const _ProfileCount({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PublishedStoriesSection extends StatelessWidget {
  final FirebaseFirestore db;
  final String authorId;
  final String currentUserId;
  final String fallbackAuthor;
  final ValueChanged<StoryPost> onOpenStory;

  const _PublishedStoriesSection({
    required this.db,
    required this.authorId,
    required this.currentUserId,
    required this.fallbackAuthor,
    required this.onOpenStory,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection(FirestoreCollections.stories)
          .where(FirestoreStoryFields.authorId, isEqualTo: authorId)
          .where(FirestoreStoryFields.status, isEqualTo: 'published')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator(color: kAppPrimary)),
          );
        }

        if (snapshot.hasError) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load stories.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final docs = (snapshot.data?.docs ?? []).toList()
          ..sort((a, b) {
            final aDate = _readDate(a.data()[FirestoreStoryFields.createdAt]);
            final bDate = _readDate(b.data()[FirestoreStoryFields.createdAt]);
            return bDate.compareTo(aDate);
          });

        if (docs.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'No published stories yet',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
          sliver: SliverList.separated(
            itemCount: docs.length + 1,
            separatorBuilder: (_, index) => index == 0
                ? const SizedBox(height: 12)
                : const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return const Text(
                  'Stories',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                );
              }
              final doc = docs[index - 1];
              final post = StoryPostMapper.fromFirestoreMap(
                storyId: doc.id,
                data: doc.data(),
                currentUserId: currentUserId,
                accent: kAppPrimary,
                fallbackAuthor: fallbackAuthor,
              );
              return _PublicStoryTile(
                post: post,
                onTap: () => onOpenStory(post),
              );
            },
          ),
        );
      },
    );
  }

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class _PublicStoryTile extends StatelessWidget {
  final StoryPost post;
  final VoidCallback onTap;

  const _PublicStoryTile({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: StorageImage(
                  url: post.imageUrl,
                  width: 78,
                  height: 78,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    width: 78,
                    height: 78,
                    color: const Color(0xFFEDE4F4),
                    child: const Icon(Icons.menu_book, color: kAppPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      post.excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.favorite,
                            size: 15, color: Colors.red.shade400),
                        const SizedBox(width: 4),
                        Text('${post.likes}'),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 15,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text('${post.comments}'),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: kAppPrimary),
            ],
          ),
        ),
      ),
    );
  }
}
