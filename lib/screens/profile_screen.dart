// profile_screen.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'badge_screen.dart';
import 'write_story_screen.dart';
import 'community.dart';
import 'theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    if (_user != null) {
      _ensureUserDocExists();
    }
  }

  Future<void> _ensureUserDocExists() async {
    if (_user == null) return;
    final docRef = _db.collection('users').doc(_user!.uid);
    final snap = await docRef.get();
    final fallbackName =
        (_user!.displayName != null && _user!.displayName!.trim().isNotEmpty)
            ? _user!.displayName!.trim()
            : (_user!.email?.split('@').first ?? 'guest');

    if (!snap.exists) {
      await docRef.set({
        'username': fallbackName,
        'email': _user!.email?.trim().toLowerCase(),
        'role': 'child',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      final data = snap.data() ?? {};
      final username = (data['username'] as String?)?.trim();
      if (username == null || username.isEmpty) {
        await docRef.set({'username': fallbackName}, SetOptions(merge: true));
      }
      await docRef.set({
        'email': _user!.email?.trim().toLowerCase(),
        if (data['role'] == null) 'role': 'child',
      }, SetOptions(merge: true));
    }
  }

  Future<void> _logout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );
    if (result == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _user?.uid;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        drawer: _buildDrawer(context),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        extendBodyBehindAppBar: true,
        body: Column(
          children: [
            _buildHeader(context, userId),
            const TabBar(
              tabs: [
                Tab(text: "My Stories"),
                Tab(text: "Drafts"),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _StoriesTab(
                      title: "My Stories", status: "published", userId: userId),
                  _StoriesTab(title: "Drafts", status: "draft", userId: userId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeStatCard(String? userId) {
    if (userId == null) {
      return _buildStatCard(Icons.emoji_events, "0", "Badges", Colors.orange);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('stories')
          .where('authorId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        int storyCount = 0;
        int totalLikes = 0;

        if (snapshot.hasData) {
          final stories = snapshot.data!.docs;
          storyCount = stories.length;

          for (final story in stories) {
            final data = story.data();
            final likes = data['likes'];
            if (likes is int) {
              totalLikes += likes;
            } else if (likes is num) {
              totalLikes += likes.toInt();
            } else if (likes is String) {
              totalLikes += int.tryParse(likes) ?? 0;
            }
          }
        }

        final badges = BadgeEngine.getBadges(
          storyCount: storyCount,
          likes: totalLikes,
        );
        final count = badges.where((badge) => badge['unlocked'] == true).length;

        return _buildStatCard(
          Icons.emoji_events,
          count.toString(),
          "Badges",
          Colors.orange,
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, String? userId) {
    final String email = _user?.email ?? "no-email@example.com";
    final String handle = "@${email.split('@').first}";

    return Container(
      padding: const EdgeInsets.only(top: 50, bottom: 30),
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kAppPrimary, Color(0xFFBA68C8)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Profile",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: userId != null
                ? _db.collection('users').doc(userId).snapshots()
                : const Stream.empty(),
            builder: (context, userDocSnap) {
              final userData = userDocSnap.data?.data();
              return CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(_profilePhotoUrl(userData)),
              );
            },
          ),
          const SizedBox(height: 12),

          // Display name: prefer users/{uid}.username, then FirebaseAuth.displayName, then email local part
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: userId != null
                ? _db.collection('users').doc(userId).snapshots()
                : const Stream.empty(),
            builder: (context, userDocSnap) {
              String displayName = "Guest User";

              if (userDocSnap.hasData && userDocSnap.data!.exists) {
                final data = userDocSnap.data!.data() ?? {};
                final dynamic usernameField =
                    data['username'] ?? data['displayName'];
                if (usernameField is String &&
                    usernameField.trim().isNotEmpty) {
                  displayName = usernameField.trim();
                } else if (_user?.displayName != null &&
                    _user!.displayName!.trim().isNotEmpty) {
                  displayName = _user!.displayName!.trim();
                } else {
                  displayName = email.split('@').first;
                }
              } else {
                if (_user?.displayName != null &&
                    _user!.displayName!.trim().isNotEmpty) {
                  displayName = _user!.displayName!.trim();
                } else {
                  displayName = email.split('@').first;
                }
              }

              return Column(
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    handle,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: _buildLikesStatCard(userId)),
                const SizedBox(width: 10),
                Flexible(
                  child: _buildStatCardStream(
                    icon: Icons.book,
                    label: "Stories",
                    color: Colors.blue,
                    userId: userId,
                    isLikes: false,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(child: _buildBadgeStatCard(userId)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: kAppPrimary,
            ),
            icon: const Icon(Icons.edit, size: 20),
            label: const Text("Edit Profile"),
          ),
        ],
      ),
    );
  }

  Widget _buildLikesStatCard(String? userId) {
    if (userId == null) {
      return _buildStatCard(Icons.favorite, "0", "Likes", Colors.red);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _db.collection('users').doc(userId).snapshots(),
      builder: (context, userSnap) {
        if (userSnap.hasError) {
          return _buildStatCardStream(
            icon: Icons.favorite,
            label: "Likes",
            color: Colors.red,
            userId: userId,
            isLikes: true,
          );
        }

        if (userSnap.hasData && userSnap.data!.exists) {
          final userData = userSnap.data!.data() ?? {};
          final dynamic totalLikesRaw = userData['totalLikes'];
          if (totalLikesRaw is int) {
            return _buildStatCard(
                Icons.favorite, totalLikesRaw.toString(), "Likes", Colors.red);
          }
          if (totalLikesRaw is String) {
            final parsed = int.tryParse(totalLikesRaw) ?? 0;
            return _buildStatCard(
                Icons.favorite, parsed.toString(), "Likes", Colors.red);
          }
        }

        return _buildStatCardStream(
          icon: Icons.favorite,
          label: "Likes",
          color: Colors.red,
          userId: userId,
          isLikes: true,
        );
      },
    );
  }

  Widget _buildStatCardStream({
    required IconData icon,
    required String label,
    required Color color,
    required String? userId,
    required bool isLikes,
  }) {
    if (userId == null) {
      return _buildStatCard(icon, "0", label, color);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('stories')
          .where('authorId', isEqualTo: userId)
          .where('status', isEqualTo: 'published')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildStatCard(icon, "0", label, color);
        }

        if (!snapshot.hasData) {
          return _buildStatCard(icon, "0", label, color);
        }

        final stories = snapshot.data!.docs;

        if (isLikes) {
          int totalLikes = 0;
          for (var story in stories) {
            final data = story.data();
            final dynamic likesRaw = data['likes'];
            if (likesRaw is int) {
              totalLikes += likesRaw;
            } else if (likesRaw is String) {
              totalLikes += int.tryParse(likesRaw) ?? 0;
            }
          }
          return _buildStatCard(icon, totalLikes.toString(), label, color);
        } else {
          return _buildStatCard(icon, stories.length.toString(), label, color);
        }
      },
    );
  }

  Widget _buildStatCard(
      IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      width: 95,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final String email = _user?.email ?? "no-email@example.com";

    return Drawer(
      child: Column(
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _user != null
                ? _db.collection('users').doc(_user!.uid).snapshots()
                : const Stream.empty(),
            builder: (context, snap) {
              String displayName = _user?.displayName ?? "Guest User";
              Map<String, dynamic>? userData;
              if (snap.hasData && snap.data!.exists) {
                userData = snap.data!.data() ?? {};
                final username = (userData['username'] as String?)?.trim();
                if (username != null && username.isNotEmpty) {
                  displayName = username;
                } else if (_user?.displayName != null &&
                    _user!.displayName!.trim().isNotEmpty) {
                  displayName = _user!.displayName!.trim();
                } else {
                  displayName = email.split('@').first;
                }
              } else {
                if (_user?.displayName != null &&
                    _user!.displayName!.trim().isNotEmpty) {
                  displayName = _user!.displayName!.trim();
                } else {
                  displayName = email.split('@').first;
                }
              }

              return UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: kAppPrimary),
                currentAccountPicture: CircleAvatar(
                  backgroundImage: NetworkImage(_profilePhotoUrl(userData)),
                ),
                accountName: Text(displayName),
                accountEmail: Text(email),
              );
            },
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerSectionTitle("Account"),
                _buildDrawerItem(Icons.emoji_events, "Badges", () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BadgeScreen()),
                  );
                }),
                _buildParentApprovalDrawerItem(context),
                _buildDrawerItem(Icons.settings, "Settings", () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                }),
                _buildDrawerSectionTitle("Support"),
                _buildDrawerItem(Icons.help_outline, "Help Guide", () {
                  _openInfoPage(
                    context,
                    title: "Help Guide",
                    icon: Icons.help_outline,
                    sections: const [
                      _InfoSection(
                        title: "Write",
                        body:
                            "Use Write to create a story title, body, and cover image.",
                      ),
                      _InfoSection(
                        title: "Publish",
                        body:
                            "Drafts stay private until you publish them. Published stories appear in Community.",
                      ),
                      _InfoSection(
                        title: "Badges",
                        body:
                            "Earn badges by writing stories and collecting likes from readers.",
                      ),
                      _InfoSection(
                        title: "E-Books",
                        body:
                            "Turn one or more published stories into an eBook from the E-Books area.",
                      ),
                    ],
                  );
                }),
                _buildDrawerItem(Icons.family_restroom, "Parent Info", () {
                  _openInfoPage(
                    context,
                    title: "Parent Info",
                    icon: Icons.family_restroom,
                    sections: const [
                      _InfoSection(
                        title: "Creative Writing",
                        body:
                            "PixiePen is designed to help kids practice storytelling, reading, and imagination.",
                      ),
                      _InfoSection(
                        title: "Content Safety",
                        body:
                            "Stories and comments are checked with local rule-based moderation before saving.",
                      ),
                      _InfoSection(
                        title: "Guidance",
                        body:
                            "Children should avoid sharing phone numbers, emails, addresses, or private details.",
                      ),
                    ],
                  );
                }),
                _buildDrawerItem(
                  Icons.verified_user_outlined,
                  "Privacy & Safety",
                  () {
                    _openInfoPage(
                      context,
                      title: "Privacy & Safety",
                      icon: Icons.verified_user_outlined,
                      sections: const [
                        _InfoSection(
                          title: "Safe Words",
                          body:
                              "The app blocks unsafe words, bullying terms, violent terms, and drug or alcohol references.",
                        ),
                        _InfoSection(
                          title: "Personal Information",
                          body:
                              "Phone numbers and email addresses are blocked before stories or comments are saved.",
                        ),
                        _InfoSection(
                          title: "Community",
                          body:
                              "Published stories should be kind, age-appropriate, and safe for kids.",
                        ),
                      ],
                    );
                  },
                ),
                _buildDrawerItem(Icons.feedback_outlined, "Feedback", () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                  );
                }),
                _buildDrawerItem(Icons.info_outline, "About PixiePen", () {
                  _openInfoPage(
                    context,
                    title: "About PixiePen",
                    icon: Icons.auto_stories,
                    sections: const [
                      _InfoSection(
                        title: "PixiePen",
                        body:
                            "A kids storytelling app for writing, sharing, earning badges, and creating eBooks.",
                      ),
                      _InfoSection(
                        title: "Version",
                        body: "1.0.0",
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildDrawerItem(
            Icons.logout,
            "Logout",
            () {
              Navigator.pop(context);
              _logout();
            },
            color: Colors.redAccent,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDrawerSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }

  Widget _buildParentApprovalDrawerItem(BuildContext context) {
    final user = _user;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _db.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final role = snapshot.data?.data()?['role'] as String?;
        if (role != 'parent') return const SizedBox.shrink();

        return _buildDrawerItem(Icons.fact_check_outlined, "Parent Approvals",
            () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ParentApprovalsScreen(),
            ),
          );
        });
      },
    );
  }

  Widget _buildDrawerItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? color,
  }) {
    final itemColor = color ?? kAppPrimary;

    return ListTile(
      leading: Icon(icon, color: itemColor),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }

  void _openInfoPage(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<_InfoSection> sections,
  }) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _InfoPage(
          title: title,
          icon: icon,
          sections: sections,
        ),
      ),
    );
  }

  String _profilePhotoUrl(Map<String, dynamic>? data) {
    final firestorePhoto =
        (data?['photoURL'] as String?) ?? (data?['profileImageUrl'] as String?);
    if (firestorePhoto != null && firestorePhoto.trim().isNotEmpty) {
      return firestorePhoto.trim();
    }
    final authPhoto = _user?.photoURL;
    if (authPhoto != null && authPhoto.trim().isNotEmpty) {
      return authPhoto.trim();
    }
    return "https://i.pravatar.cc/150?img=12";
  }
}

/// =============================================================================
/// EDIT PROFILE SCREEN (saves to both Auth and users/{uid}.username)
/// =============================================================================

class _InfoPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_InfoSection> sections;

  const _InfoPage({
    required this.title,
    required this.icon,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FF),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        backgroundColor: kAppPrimary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2D9F3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: kAppPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: kAppPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...sections.map(
            (section) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2D9F3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    section.body,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection {
  final String title;
  final String body;

  const _InfoSection({
    required this.title,
    required this.body,
  });
}

class ParentApprovalsScreen extends StatelessWidget {
  final String? highlightStoryId;

  const ParentApprovalsScreen({super.key, this.highlightStoryId});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final parentEmail = user?.email?.trim().toLowerCase();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F7FF),
        appBar: AppBar(
          title: const Text(
            'Parent Approvals',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: kAppPrimary,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (user != null) _ParentNotificationButton(userId: user.uid),
            IconButton(
              tooltip: 'Logout',
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/login', (route) => false);
                }
              },
              icon: const Icon(Icons.logout, color: Colors.white),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: parentEmail == null
            ? const Center(child: Text('Please log in as a parent.'))
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('stories')
                    .where('parentEmail', isEqualTo: parentEmail)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: kAppPrimary),
                    );
                  }

                  final stories = (snapshot.data?.docs ?? []).toList()
                    ..sort((a, b) {
                      final aDate = _readDate(a.data()['createdAt']);
                      final bDate = _readDate(b.data()['createdAt']);
                      return bDate.compareTo(aDate);
                    });

                  final pending = stories
                      .where(
                        (doc) =>
                            doc.data()['status'] == 'pending_parent_approval',
                      )
                      .toList();
                  final history = stories
                      .where((doc) =>
                          doc.data()['approvalStatus'] == 'approved' ||
                          doc.data()['approvalStatus'] == 'rejected')
                      .toList();

                  return TabBarView(
                    children: [
                      _ParentApprovalList(
                        docs: _prioritizeStory(pending, highlightStoryId),
                        emptyText: 'No stories waiting for approval.',
                        showActions: true,
                        highlightStoryId: highlightStoryId,
                      ),
                      _ParentApprovalList(
                        docs: history,
                        emptyText: 'No approval history yet.',
                        showActions: false,
                        highlightStoryId: highlightStoryId,
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static List<QueryDocumentSnapshot<Map<String, dynamic>>> _prioritizeStory(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String? storyId,
  ) {
    if (storyId == null) return docs;
    return docs.toList()
      ..sort((a, b) {
        if (a.id == storyId) return -1;
        if (b.id == storyId) return 1;
        return 0;
      });
  }
}

class _ParentApprovalList extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final String emptyText;
  final bool showActions;
  final String? highlightStoryId;

  const _ParentApprovalList({
    required this.docs,
    required this.emptyText,
    required this.showActions,
    required this.highlightStoryId,
  });

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyText,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data();
        return _ParentApprovalCard(
          storyId: doc.id,
          title: (data['title'] as String?) ?? 'Untitled',
          body: (data['body'] as String?) ?? '',
          childId: data['authorId'] as String?,
          childName: (data['authorName'] as String?) ?? 'Child',
          approvalStatus: (data['approvalStatus'] as String?) ?? 'pending',
          showActions: showActions,
          highlighted: doc.id == highlightStoryId,
        );
      },
    );
  }
}

class _ParentNotificationButton extends StatelessWidget {
  final String userId;

  const _ParentNotificationButton({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('toUserId', isEqualTo: userId)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = (snapshot.data?.docs ?? [])
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
                  onParentApprovalTap: (storyId) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ParentApprovalsScreen(highlightStoryId: storyId),
                      ),
                    );
                  },
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

class _ParentApprovalCard extends StatefulWidget {
  final String storyId;
  final String title;
  final String body;
  final String? childId;
  final String childName;
  final String approvalStatus;
  final bool showActions;
  final bool highlighted;

  const _ParentApprovalCard({
    required this.storyId,
    required this.title,
    required this.body,
    required this.childId,
    required this.childName,
    required this.approvalStatus,
    required this.showActions,
    required this.highlighted,
  });

  @override
  State<_ParentApprovalCard> createState() => _ParentApprovalCardState();
}

class _ParentApprovalCardState extends State<_ParentApprovalCard> {
  bool _isSaving = false;

  Future<void> _review({required bool approved}) async {
    setState(() => _isSaving = true);

    try {
      final db = FirebaseFirestore.instance;
      final parent = FirebaseAuth.instance.currentUser;
      final storyRef = db.collection('stories').doc(widget.storyId);

      await storyRef.set({
        'status': approved ? 'published' : 'draft',
        'isPublish': approved,
        'approvalStatus': approved ? 'approved' : 'rejected',
        'parentApproval': {
          'status': approved ? 'approved' : 'rejected',
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': parent?.uid,
          'reviewedByEmail': parent?.email?.trim().toLowerCase(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final childId = widget.childId;
      if (childId != null && childId.isNotEmpty) {
        final childSnap = await db.collection('users').doc(childId).get();
        if (childSnap.data()?['notificationsEnabled'] != false) {
          await db.collection('notifications').add({
            'toUserId': childId,
            'fromUserId': parent?.uid,
            'fromUserName': parent?.displayName ?? 'Parent',
            'type': 'approval_result',
            'storyId': widget.storyId,
            'storyTitle': widget.title,
            'message': approved
                ? 'Your story "${widget.title}" was approved and published.'
                : 'Your story "${widget.title}" was sent back for editing.',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved ? 'Story approved' : 'Story sent back'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update story: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.highlighted ? kAppPrimary : const Color(0xFFE2D9F3),
          width: widget.highlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'by ${widget.childName}',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          _ParentApprovalStatus(status: widget.approvalStatus),
          const SizedBox(height: 10),
          Text(
            widget.body,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(height: 1.35),
          ),
          if (widget.showActions) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _isSaving ? null : () => _review(approved: false),
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Send Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade800,
                      side: BorderSide(color: Colors.orange.shade300),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : () => _review(approved: true),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAppPrimary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ParentApprovalStatus extends StatelessWidget {
  final String status;

  const _ParentApprovalStatus({required this.status});

  @override
  Widget build(BuildContext context) {
    final isApproved = status == 'approved';
    final isRejected = status == 'rejected';
    final color = isApproved
        ? Colors.green.shade700
        : isRejected
            ? Colors.orange.shade800
            : Colors.blue.shade700;
    final label = isApproved
        ? 'Approved'
        : isRejected
            ? 'Sent back'
            : 'Waiting for review';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final List<String> _categories = const [
    'I have an idea',
    'Something is not working',
    'I need help',
    'Something feels unsafe',
    'Other',
  ];

  String _category = 'I have an idea';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    final message = _messageController.text.trim();

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write your feedback first.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await _db.collection('feedback').add({
        'userId': user?.uid,
        'userEmail': user?.email,
        'category': _category,
        'message': message,
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _messageController.clear();
      setState(() => _category = 'I have an idea');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks! Your feedback was sent.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send feedback: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FF),
      appBar: AppBar(
        title: const Text('Feedback', style: TextStyle(color: Colors.white)),
        backgroundColor: kAppPrimary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFD77A)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.family_restroom, color: Color(0xFF8A5A00)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ask a parent, guardian, or teacher before sending feedback.',
                    style: TextStyle(
                      color: Color(0xFF6B4700),
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2D9F3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What would you like to tell us?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _category = value);
                          }
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _messageController,
                  minLines: 5,
                  maxLines: 8,
                  enabled: !_isSubmitting,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Write your feedback here...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitFeedback,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_isSubmitting ? 'Sending...' : 'Send Feedback'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAppPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
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

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();
  late final TextEditingController _nameController;
  late final TextEditingController _handleController;
  late final TextEditingController _parentEmailController;
  String? _photoUrl;
  String _role = 'child';
  bool _saving = false;
  bool _photoSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _user?.displayName ?? "");
    _handleController =
        TextEditingController(text: _user?.email?.split('@').first ?? "");
    _parentEmailController = TextEditingController();
    _photoUrl = _user?.photoURL;
    _loadProfileFromFirestore();
  }

  Future<void> _loadProfileFromFirestore() async {
    if (_user == null) return;
    final doc = await _db.collection('users').doc(_user!.uid).get();
    if (doc.exists) {
      final data = doc.data() ?? {};
      final username = data['username'] as String?;
      if (username != null && username.trim().isNotEmpty) {
        _nameController.text = username;
      }
      final role = data['role'] as String?;
      final parentEmail = data['parentEmail'] as String?;
      if (mounted) {
        setState(() {
          _role = role == 'parent' ? 'parent' : 'child';
          _parentEmailController.text = parentEmail ?? '';
        });
      }
      final photoUrl =
          (data['photoURL'] as String?) ?? (data['profileImageUrl'] as String?);
      if (photoUrl != null && photoUrl.trim().isNotEmpty && mounted) {
        setState(() {
          _photoUrl = photoUrl.trim();
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _handleController.dispose();
    _parentEmailController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_user == null) return;
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
    }
    final parentEmail = _parentEmailController.text.trim().toLowerCase();
    if (_role == 'child' && parentEmail.isNotEmpty) {
      final emailRegex = RegExp(r'^[\w-\.]+@gmail\.com$');
      if (!emailRegex.hasMatch(parentEmail)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid parent Gmail')),
        );
        return;
      }
    }

    setState(() {
      _saving = true;
    });

    try {
      // Update FirebaseAuth displayName
      await _user!.updateDisplayName(newName);

      // Update users/{uid}.username (create doc if missing)
      await _db.collection('users').doc(_user!.uid).set({
        'username': newName,
        'email': _user!.email?.trim().toLowerCase(),
        'role': _role,
        'parentEmail': _role == 'child' && parentEmail.isNotEmpty
            ? parentEmail
            : FieldValue.delete(),
        'photoURL': _photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error updating profile: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadProfilePhoto() async {
    if (_user == null || _photoSaving) return;

    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (image == null) return;

    setState(() {
      _photoSaving = true;
    });

    try {
      final bytes = await image.readAsBytes();
      final ref = _profilePhotoRef();
      final metadata = SettableMetadata(
        contentType: image.mimeType ?? _contentTypeForPath(image.name),
      );

      await ref.putData(Uint8List.fromList(bytes), metadata);
      final downloadUrl = await ref.getDownloadURL();

      await _user!.updatePhotoURL(downloadUrl);
      await _db.collection('users').doc(_user!.uid).set({
        'photoURL': downloadUrl,
        'profileImageUrl': downloadUrl,
        'profileImagePath': ref.fullPath,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _photoUrl = downloadUrl;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile image updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading profile image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _photoSaving = false;
        });
      }
    }
  }

  Future<void> _removeProfilePhoto() async {
    if (_user == null || _photoSaving) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Profile Image'),
        content: const Text('Remove your current profile image?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      _photoSaving = true;
    });

    try {
      final userDoc = _db.collection('users').doc(_user!.uid);
      final snap = await userDoc.get();
      final storagePath = snap.data()?['profileImagePath'] as String?;

      if (storagePath != null && storagePath.trim().isNotEmpty) {
        try {
          await _storage.ref(storagePath).delete();
        } on FirebaseException catch (e) {
          if (e.code != 'object-not-found') rethrow;
        }
      }

      await _user!.updatePhotoURL(null);
      await userDoc.set({
        'photoURL': FieldValue.delete(),
        'profileImageUrl': FieldValue.delete(),
        'profileImagePath': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _photoUrl = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile image removed'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing profile image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _photoSaving = false;
        });
      }
    }
  }

  Reference _profilePhotoRef() {
    return _storage.ref().child('users/${_user!.uid}/profile/profile.jpg');
  }

  String _contentTypeForPath(String path) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.png')) return 'image/png';
    if (lowerPath.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  String get _displayPhotoUrl {
    final photoUrl = _photoUrl;
    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      return photoUrl.trim();
    }
    return "https://i.pravatar.cc/150?img=12";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text("Edit Profile", style: TextStyle(color: Colors.white)),
        backgroundColor: kAppPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(_displayPhotoUrl),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            _photoSaving ? null : _pickAndUploadProfilePhoto,
                        icon: _photoSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.photo_camera),
                        label: Text(_photoUrl == null ? 'Add Image' : 'Update'),
                      ),
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: _photoSaving || _photoUrl == null
                            ? null
                            : _removeProfilePhoto,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: "Display Name",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _handleController,
              enabled: false,
              decoration: InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'child',
                  icon: Icon(Icons.face),
                  label: Text('Child'),
                ),
                ButtonSegment(
                  value: 'parent',
                  icon: Icon(Icons.family_restroom),
                  label: Text('Parent'),
                ),
              ],
              selected: {_role},
              onSelectionChanged: (selection) {
                setState(() => _role = selection.first);
              },
            ),
            if (_role == 'child') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _parentEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Parent Gmail",
                  hintText: "parent@gmail.com",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: kAppPrimary,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Save Changes",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =============================================================================
/// STORIES TAB
/// =============================================================================

class _StoriesTab extends StatefulWidget {
  final String title;
  final String status;
  final String? userId;

  const _StoriesTab({
    required this.title,
    required this.status,
    required this.userId,
  });

  @override
  State<_StoriesTab> createState() => _StoriesTabState();
}

class _StoriesTabState extends State<_StoriesTab> {
  final StoryService _storyService = StoryService();

  @override
  Widget build(BuildContext context) {
    if (widget.userId == null) {
      return const Center(
        child: Text("User not logged in"),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('stories')
          .where('authorId', isEqualTo: widget.userId)
          .where('status', isEqualTo: widget.status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: kAppPrimary),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.book_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No ${widget.status} stories yet',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        final stories = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: stories.length,
          itemBuilder: (context, index) {
            final story = stories[index];
            final data = story.data() as Map<String, dynamic>;
            final post = _buildStoryPost(story.id, data);

            return Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
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
                    Row(
                      children: [
                        const Icon(
                          Icons.favorite,
                          size: 14,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${data['likes'] ?? 0}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: const Text('Edit'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WriteStoryScreen(storyId: story.id),
                          ),
                        );
                      },
                    ),
                    PopupMenuItem(
                      child: const Text('Delete'),
                      onTap: () {
                        _showDeleteConfirmation(context, story.id);
                      },
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
    final authorName = (data['authorName'] as String?) ??
        FirebaseAuth.instance.currentUser?.displayName ??
        'You';
    final handle = (data['handle'] as String?) ??
        authorName.replaceAll(' ', '').toLowerCase();
    final likes = _readInt(data['likes']);
    final comments = _readInt(data['comments']);
    final likedBy = (data['likedBy'] as List?) ?? [];
    final likedByMe = widget.userId != null && likedBy.contains(widget.userId);
    final imageUrl = cover != null && cover.isNotEmpty
        ? cover
        : 'https://picsum.photos/seed/$storyId/600/300';

    return StoryPost(
      id: storyId,
      author: authorName,
      handle: handle,
      title: title,
      excerpt: body,
      likes: likes,
      comments: comments,
      likedByMe: likedByMe,
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

  void _openStory(BuildContext context, StoryPost post) {
    final currentUser = FirebaseAuth.instance.currentUser;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryReaderPage(
          post: post,
          service: _storyService,
          userId: widget.userId ?? currentUser?.uid ?? '',
          userName: currentUser?.displayName ?? currentUser?.email ?? 'User',
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String storyId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Story'),
        content: const Text('Are you sure you want to delete this story?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('stories')
                  .doc(storyId)
                  .delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Story deleted successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// =============================================================================
/// SETTINGS SCREEN
/// =============================================================================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;

  Future<void> _changePassword() async {
    final newPassword = _passwordController.text.trim();
    if (newPassword.isEmpty || newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters'),
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.currentUser!.updatePassword(newPassword);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(color: Colors.white)),
        backgroundColor: kAppPrimary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: [
          if (_user != null)
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _db.collection('users').doc(_user!.uid).snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() ?? {};
                final enabled = data['notificationsEnabled'] != false;

                return SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text("Notifications"),
                  subtitle: const Text(
                    "Get alerts for likes, comments, ratings, and approvals",
                  ),
                  value: enabled,
                  activeThumbColor: kAppPrimary,
                  onChanged: (value) async {
                    await _db.collection('users').doc(_user!.uid).set({
                      'notificationsEnabled': value,
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
                  },
                );
              },
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text("Change Password"),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Change Password"),
                  content: TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: "Enter new password",
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: _changePassword,
                      child: const Text("Update"),
                    ),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text("About"),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("About PixiePen"),
                  content: const Text(
                    "PixiePen is a fun and creative app for kids to write and illustrate their own stories using AI-powered tools.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("OK"),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
