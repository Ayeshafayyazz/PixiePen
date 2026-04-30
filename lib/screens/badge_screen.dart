import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:confetti/confetti.dart';
import 'theme.dart';

class BadgeScreen extends StatefulWidget {
  const BadgeScreen({super.key});

  @override
  State<BadgeScreen> createState() => _BadgeScreenState();
}

class _BadgeScreenState extends State<BadgeScreen> {
  final ConfettiController _confetti =
  ConfettiController(duration: const Duration(seconds: 2));

  Map<String, dynamic>? selectedBadge;

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(
              badge['icon'],
              size: 50,
              color: unlocked ? kAppPrimary : Colors.grey,
            ),
            const SizedBox(height: 10),
            Text(
              badge['label'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          unlocked
              ? "🎉 Congratulations! You unlocked this badge."
              : badge['desc'],
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          )
        ],
      ),
    );

    if (unlocked) {
      _confetti.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Badges", style: TextStyle(color: Colors.white)),
        backgroundColor: kAppPrimary,
      ),

      body: Stack(
        alignment: Alignment.topCenter,
        children: [

          // 🎊 CONFETTI
          ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 25,
            gravity: 0.2,
          ),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('stories')
                .where('authorId', isEqualTo: user?.uid)
                .snapshots(),
            builder: (context, storySnap) {

              int storyCount = 0;
              int totalLikes = 0;

              if (storySnap.hasData) {
                final docs = storySnap.data!.docs;

                storyCount = docs.length;

                for (var d in docs) {
                  final data = d.data() as Map<String, dynamic>;
                  totalLikes += (data['likes'] ?? 0) as int;
                }
              }

              final badges = BadgeEngine.getBadges(
                storyCount: storyCount,
                likes: totalLikes,
              );

              final unlocked = badges.where((b) => b['unlocked']).length;

              return Column(
                children: [

                  const SizedBox(height: 16),

                  Text(
                    "$unlocked / ${badges.length} Badges Unlocked",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: LinearProgressIndicator(
                      value: unlocked / badges.length,
                      minHeight: 10,
                      backgroundColor: Colors.grey[300],
                      valueColor:
                      const AlwaysStoppedAnimation(kAppPrimary),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: badges.length,
                      itemBuilder: (context, index) {
                        final b = badges[index];
                        final unlocked = b['unlocked'];

                        return GestureDetector(
                          onTap: () => _showBadgePopup(b),

                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              color: unlocked
                                  ? kAppPrimary
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: unlocked
                                  ? [
                                BoxShadow(
                                  color: kAppPrimary
                                      .withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                )
                              ]
                                  : [],
                            ),

                            child: Column(
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              children: [

                                Icon(
                                  b['icon'],
                                  size: 42,
                                  color: unlocked
                                      ? Colors.white
                                      : Colors.grey,
                                ),

                                const SizedBox(height: 10),

                                // ⭐ FIX: WHITE TEXT ON PURPLE
                                Text(
                                  b['label'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: unlocked
                                        ? Colors.white
                                        : Colors.grey,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  unlocked
                                      ? "Unlocked 🎉"
                                      : b['desc'],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: unlocked
                                        ? Colors.white70
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class BadgeEngine {
  static List<Map<String, dynamic>> getBadges({
    required int storyCount,
    required int likes,
  }) {
    return [
      {
        "id": "rookie",
        "icon": Icons.star,
        "label": "Rookie",
        "desc": "Write your first story",
        "unlocked": storyCount >= 1,
      },
      {
        "id": "fast_writer",
        "icon": Icons.bolt,
        "label": "Fast Writer",
        "desc": "Write 5 stories",
        "unlocked": storyCount >= 5,
      },
      {
        "id": "loved",
        "icon": Icons.favorite,
        "label": "Loved",
        "desc": "Get 20 total likes",
        "unlocked": likes >= 20,
      },
      {
        "id": "explorer",
        "icon": Icons.public,
        "label": "Explorer",
        "desc": "Write 10 stories",
        "unlocked": storyCount >= 10,
      },
    ];
  }
}