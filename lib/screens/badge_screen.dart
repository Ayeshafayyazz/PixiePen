import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

class BadgeScreen extends StatefulWidget {
  const BadgeScreen({super.key});

  @override
  State<BadgeScreen> createState() => _BadgeScreenState();
}

class _BadgeScreenState extends State<BadgeScreen> {
  final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 2));

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _showBadgePopup(Map<String, dynamic> badge) {
    final unlocked = badge['unlocked'] == true;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Icon(
              badge['icon'] as IconData,
              size: 50,
              color: unlocked ? kAppPrimary : Colors.grey,
            ),
            const SizedBox(height: 10),
            Text(
              badge['label'] as String,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          unlocked
              ? 'Congratulations. You unlocked this badge.\n\n${badge['desc']}'
              : badge['desc'] as String,
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          )
        ],
      ),
    );

    if (unlocked) _confetti.play();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final weekStart = DateTime.now().subtract(const Duration(days: 7));

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Badges', style: TextStyle(color: Colors.white)),
          backgroundColor: kAppPrimary,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: Text('Please log in to view badges.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Badges', style: TextStyle(color: Colors.white)),
        backgroundColor: kAppPrimary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 25,
            gravity: 0.2,
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('stories')
                .where('authorId', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, storySnap) {
              var storyCount = 0;
              var totalLikes = 0;
              var storiesThisWeek = 0;

              if (storySnap.hasData) {
                final docs = storySnap.data!.docs;
                storyCount = docs.length;
                for (final doc in docs) {
                  final data = doc.data();
                  totalLikes += _readInt(data['likes']);
                  if (_readDate(data['createdAt']).isAfter(weekStart)) {
                    storiesThisWeek++;
                  }
                }
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('storyLikes')
                    .where('authorId', isEqualTo: user.uid)
                    .snapshots(),
                builder: (context, likeSnap) {
                  final likesThisWeek = (likeSnap.data?.docs ?? [])
                      .where(
                        (doc) => _readDate(doc.data()['createdAt'])
                            .isAfter(weekStart),
                      )
                      .length;

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('savedStories')
                        .where('authorId', isEqualTo: user.uid)
                        .snapshots(),
                    builder: (context, saveSnap) {
                      final savesThisWeek = (saveSnap.data?.docs ?? [])
                          .where(
                            (doc) => _readDate(doc.data()['savedAt'])
                                .isAfter(weekStart),
                          )
                          .length;
                      final badges = BadgeEngine.getBadges(
                        storyCount: storyCount,
                        likes: totalLikes,
                        storiesThisWeek: storiesThisWeek,
                        likesThisWeek: likesThisWeek,
                        savesThisWeek: savesThisWeek,
                      );

                      return _BadgeGrid(
                        badges: badges,
                        onBadgeTap: _showBadgePopup,
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class _BadgeGrid extends StatelessWidget {
  final List<Map<String, dynamic>> badges;
  final ValueChanged<Map<String, dynamic>> onBadgeTap;

  const _BadgeGrid({
    required this.badges,
    required this.onBadgeTap,
  });

  @override
  Widget build(BuildContext context) {
    final unlocked = badges.where((badge) => badge['unlocked'] == true).length;

    return Column(
      children: [
        const SizedBox(height: 16),
        Text(
          '$unlocked / ${badges.length} Badges Unlocked',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LinearProgressIndicator(
            value: badges.isEmpty ? 0 : unlocked / badges.length,
            minHeight: 10,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation(kAppPrimary),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 700
                  ? 4
                  : constraints.maxWidth >= 460
                      ? 3
                      : 2;

              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemCount: badges.length,
                itemBuilder: (context, index) {
                  final badge = badges[index];
                  final isUnlocked = badge['unlocked'] == true;

                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => onBadgeTap(badge),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isUnlocked ? kAppPrimary : Colors.grey[200],
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: isUnlocked
                            ? [
                                BoxShadow(
                                  color: kAppPrimary.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                )
                              ]
                            : [],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            badge['icon'] as IconData,
                            size: 42,
                            color: isUnlocked ? Colors.white : Colors.grey,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            badge['label'] as String,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isUnlocked ? Colors.white : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            badge['desc'] as String,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isUnlocked ? Colors.white70 : Colors.grey,
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
        ),
      ],
    );
  }
}

class BadgeEngine {
  static List<Map<String, dynamic>> getBadges({
    required int storyCount,
    required int likes,
    int storiesThisWeek = 0,
    int likesThisWeek = 0,
    int savesThisWeek = 0,
  }) {
    return [
      {
        'id': 'rookie',
        'icon': Icons.star,
        'label': 'Rookie',
        'desc': 'Write 1 story',
        'unlocked': storyCount >= 1,
      },
      {
        'id': 'weekly_spark',
        'icon': Icons.edit_calendar,
        'label': 'Weekly Spark',
        'desc': 'Write 2 stories in 7 days',
        'unlocked': storiesThisWeek >= 2,
      },
      {
        'id': 'fast_writer',
        'icon': Icons.bolt,
        'label': 'Fast Writer',
        'desc': 'Write 5 stories in 7 days',
        'unlocked': storiesThisWeek >= 5,
      },
      {
        'id': 'explorer',
        'icon': Icons.public,
        'label': 'Explorer',
        'desc': 'Write 10 stories in 7 days',
        'unlocked': storiesThisWeek >= 10,
      },
      {
        'id': 'loved',
        'icon': Icons.favorite,
        'label': 'Loved',
        'desc': 'Get 10 likes in 7 days',
        'unlocked': likesThisWeek >= 10,
      },
      {
        'id': 'bookmarked',
        'icon': Icons.bookmark,
        'label': 'Bookmarked',
        'desc': 'Get 5 saves in 7 days',
        'unlocked': savesThisWeek >= 5,
      },
      {
        'id': 'story_builder',
        'icon': Icons.auto_stories,
        'label': 'Story Builder',
        'desc': 'Write 3 total stories',
        'unlocked': storyCount >= 3,
      },
      {
        'id': 'fan_favorite',
        'icon': Icons.local_fire_department,
        'label': 'Fan Favourite',
        'desc': 'Get 50 total likes',
        'unlocked': likes >= 50,
      },
    ];
  }
}
