import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'badge_screen.dart';
import 'write_story_screen.dart';
import 'community.dart';
import 'parent_approvals_screen.dart';
import 'theme.dart';
import '../utils/story_content.dart';
import '../services/content_moderation_service.dart';
import '../widgets/moderation_ui.dart';

const List<_AvatarChoice> _avatarChoices = [
  _AvatarChoice(
    id: 'cartoon_girl_buns',
    color: Color(0xFFAD1457),
    background: Color(0xFFFFE4F1),
    cartoonStyle: _CartoonAvatarStyle(
      skin: Color(0xFFFFD7B5),
      hair: Color(0xFF4E2A1E),
      shirt: Color(0xFFE91E63),
      cheek: Color(0xFFFF8A80),
      hairStyle: _CartoonHairStyle.buns,
    ),
  ),
  _AvatarChoice(
    id: 'cartoon_boy_cap',
    color: Color(0xFF1565C0),
    background: Color(0xFFE1F5FE),
    cartoonStyle: _CartoonAvatarStyle(
      skin: Color(0xFFFFC89D),
      hair: Color(0xFF263238),
      shirt: Color(0xFF1E88E5),
      cheek: Color(0xFFFFAB91),
      hairStyle: _CartoonHairStyle.cap,
      accessory: Icons.star,
      accessoryColor: Color(0xFFFFD54F),
    ),
  ),
  _AvatarChoice(
    id: 'cartoon_girl_bob',
    color: Color(0xFF6A1B9A),
    background: Color(0xFFF3E5F5),
    cartoonStyle: _CartoonAvatarStyle(
      skin: Color(0xFFF6C19A),
      hair: Color(0xFF5D4037),
      shirt: Color(0xFF8E24AA),
      cheek: Color(0xFFF48FB1),
      hairStyle: _CartoonHairStyle.bob,
      accessory: Icons.favorite,
      accessoryColor: Color(0xFFFF80AB),
    ),
  ),
  _AvatarChoice(
    id: 'cartoon_boy_curls',
    color: Color(0xFF00897B),
    background: Color(0xFFE0F2F1),
    cartoonStyle: _CartoonAvatarStyle(
      skin: Color(0xFFB97855),
      hair: Color(0xFF2E1A12),
      shirt: Color(0xFF00ACC1),
      cheek: Color(0xFFD98B73),
      hairStyle: _CartoonHairStyle.curls,
    ),
  ),
  _AvatarChoice(
    id: 'cartoon_girl_puffs',
    color: Color(0xFFD81B60),
    background: Color(0xFFFFF1F7),
    cartoonStyle: _CartoonAvatarStyle(
      skin: Color(0xFF8D5524),
      hair: Color(0xFF21120D),
      shirt: Color(0xFFFF7043),
      cheek: Color(0xFFC66C4A),
      hairStyle: _CartoonHairStyle.puffs,
      accessory: Icons.auto_awesome,
      accessoryColor: Color(0xFFFFD54F),
    ),
  ),
  _AvatarChoice(
    id: 'cartoon_boy_swoop',
    color: Color(0xFF2E7D32),
    background: Color(0xFFE8F5E9),
    cartoonStyle: _CartoonAvatarStyle(
      skin: Color(0xFFFFDAB9),
      hair: Color(0xFFD84315),
      shirt: Color(0xFF43A047),
      cheek: Color(0xFFFFAB91),
      hairStyle: _CartoonHairStyle.swoop,
    ),
  ),
  _AvatarChoice(
    id: 'cartoon_girl_headband',
    color: Color(0xFFEF6C00),
    background: Color(0xFFFFF3E0),
    cartoonStyle: _CartoonAvatarStyle(
      skin: Color(0xFFE0AC69),
      hair: Color(0xFF3E2723),
      shirt: Color(0xFFFFB300),
      cheek: Color(0xFFE59675),
      hairStyle: _CartoonHairStyle.headband,
      accessory: Icons.local_florist,
      accessoryColor: Color(0xFFFF7043),
    ),
  ),
  _AvatarChoice(
    id: 'cartoon_boy_side_part',
    color: Color(0xFF3949AB),
    background: Color(0xFFE8EAF6),
    cartoonStyle: _CartoonAvatarStyle(
      skin: Color(0xFFDEB887),
      hair: Color(0xFF6D4C41),
      shirt: Color(0xFF5C6BC0),
      cheek: Color(0xFFE6A57E),
      hairStyle: _CartoonHairStyle.sidePart,
    ),
  ),
  _AvatarChoice(
    id: 'star_reader',
    icon: Icons.auto_stories,
    color: Color(0xFF7B1FA2),
    background: Color(0xFFF3E5F5),
  ),
  _AvatarChoice(
    id: 'magic_pen',
    icon: Icons.edit,
    color: Color(0xFF1565C0),
    background: Color(0xFFE3F2FD),
  ),
  _AvatarChoice(
    id: 'bright_idea',
    icon: Icons.lightbulb,
    color: Color(0xFFF57C00),
    background: Color(0xFFFFF3E0),
  ),
  _AvatarChoice(
    id: 'kind_heart',
    icon: Icons.favorite,
    color: Color(0xFFC2185B),
    background: Color(0xFFFCE4EC),
  ),
  _AvatarChoice(
    id: 'book_hero',
    icon: Icons.local_library,
    color: Color(0xFF2E7D32),
    background: Color(0xFFE8F5E9),
  ),
  _AvatarChoice(
    id: 'space_writer',
    icon: Icons.rocket_launch,
    color: Color(0xFF4527A0),
    background: Color(0xFFEDE7F6),
  ),
];

class _AvatarChoice {
  final String id;
  final IconData? icon;
  final Color color;
  final Color background;
  final _CartoonAvatarStyle? cartoonStyle;

  const _AvatarChoice({
    required this.id,
    this.icon,
    required this.color,
    required this.background,
    this.cartoonStyle,
  });
}

enum _CartoonHairStyle {
  bob,
  buns,
  cap,
  curls,
  headband,
  puffs,
  sidePart,
  swoop,
}

class _CartoonAvatarStyle {
  final Color skin;
  final Color hair;
  final Color shirt;
  final Color cheek;
  final _CartoonHairStyle hairStyle;
  final IconData? accessory;
  final Color? accessoryColor;

  const _CartoonAvatarStyle({
    required this.skin,
    required this.hair,
    required this.shirt,
    required this.cheek,
    required this.hairStyle,
    this.accessory,
    this.accessoryColor,
  });
}

_AvatarChoice _avatarChoiceFor(String? id) {
  return _avatarChoices.firstWhere(
    (avatar) => avatar.id == id,
    orElse: () => _avatarChoices.first,
  );
}

String? _cleanString(dynamic value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

class _AvatarArt extends StatelessWidget {
  final _AvatarChoice avatar;
  final double radius;

  const _AvatarArt({
    required this.avatar,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final cartoonStyle = avatar.cartoonStyle;
    if (cartoonStyle != null) {
      return ClipOval(
        child: CustomPaint(
          size: Size.square(radius * 2),
          painter: _CartoonAvatarPainter(
            background: avatar.background,
            style: cartoonStyle,
          ),
          child: SizedBox.square(
            dimension: radius * 2,
            child: cartoonStyle.accessory == null
                ? null
                : Align(
                    alignment: const Alignment(0.58, -0.62),
                    child: Icon(
                      cartoonStyle.accessory,
                      color: cartoonStyle.accessoryColor ?? avatar.color,
                      size: radius * 0.34,
                    ),
                  ),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: avatar.background,
      child: Icon(
        avatar.icon ?? Icons.face,
        color: avatar.color,
        size: radius,
      ),
    );
  }
}

class _CartoonAvatarPainter extends CustomPainter {
  final Color background;
  final _CartoonAvatarStyle style;

  const _CartoonAvatarPainter({
    required this.background,
    required this.style,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final center = Offset(width / 2, size.height / 2);
    final scale = width / 100;
    final bgPaint = Paint()..color = background;
    final hairPaint = Paint()..color = style.hair;
    final skinPaint = Paint()..color = style.skin;
    final shirtPaint = Paint()..color = style.shirt;
    final cheekPaint = Paint()..color = style.cheek.withValues(alpha: 0.75);
    final eyePaint = Paint()..color = const Color(0xFF263238);
    final mouthPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2 * scale;

    canvas.drawCircle(center, width / 2, bgPaint);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(50 * scale, 105 * scale),
        width: 78 * scale,
        height: 48 * scale,
      ),
      shirtPaint,
    );
    _paintHairBack(canvas, scale, hairPaint);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(50 * scale, 54 * scale),
        width: 50 * scale,
        height: 56 * scale,
      ),
      skinPaint,
    );
    _paintHairFront(canvas, scale, hairPaint, shirtPaint);

    canvas.drawCircle(Offset(39 * scale, 56 * scale), 3 * scale, eyePaint);
    canvas.drawCircle(Offset(61 * scale, 56 * scale), 3 * scale, eyePaint);
    canvas.drawCircle(Offset(35 * scale, 65 * scale), 5 * scale, cheekPaint);
    canvas.drawCircle(Offset(65 * scale, 65 * scale), 5 * scale, cheekPaint);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(50 * scale, 65 * scale),
        width: 18 * scale,
        height: 14 * scale,
      ),
      0.18,
      2.78,
      false,
      mouthPaint,
    );
  }

  void _paintHairBack(Canvas canvas, double scale, Paint hairPaint) {
    switch (style.hairStyle) {
      case _CartoonHairStyle.buns:
        canvas.drawCircle(
            Offset(25 * scale, 36 * scale), 14 * scale, hairPaint);
        canvas.drawCircle(
            Offset(75 * scale, 36 * scale), 14 * scale, hairPaint);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(50 * scale, 42 * scale),
            width: 56 * scale,
            height: 42 * scale,
          ),
          hairPaint,
        );
        break;
      case _CartoonHairStyle.bob:
      case _CartoonHairStyle.headband:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(24 * scale, 25 * scale, 52 * scale, 65 * scale),
            Radius.circular(22 * scale),
          ),
          hairPaint,
        );
        break;
      case _CartoonHairStyle.puffs:
        canvas.drawCircle(
            Offset(24 * scale, 42 * scale), 15 * scale, hairPaint);
        canvas.drawCircle(
            Offset(76 * scale, 42 * scale), 15 * scale, hairPaint);
        break;
      case _CartoonHairStyle.cap:
      case _CartoonHairStyle.curls:
      case _CartoonHairStyle.sidePart:
      case _CartoonHairStyle.swoop:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(50 * scale, 38 * scale),
            width: 52 * scale,
            height: 36 * scale,
          ),
          hairPaint,
        );
        break;
    }
  }

  void _paintHairFront(
    Canvas canvas,
    double scale,
    Paint hairPaint,
    Paint shirtPaint,
  ) {
    switch (style.hairStyle) {
      case _CartoonHairStyle.buns:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(50 * scale, 33 * scale),
            width: 48 * scale,
            height: 28 * scale,
          ),
          hairPaint,
        );
        break;
      case _CartoonHairStyle.bob:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(50 * scale, 33 * scale),
            width: 52 * scale,
            height: 30 * scale,
          ),
          hairPaint,
        );
        break;
      case _CartoonHairStyle.cap:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(50 * scale, 35 * scale),
            width: 54 * scale,
            height: 28 * scale,
          ),
          shirtPaint,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(66 * scale, 43 * scale),
            width: 32 * scale,
            height: 10 * scale,
          ),
          shirtPaint,
        );
        break;
      case _CartoonHairStyle.curls:
        for (final offset in const [
          Offset(31, 35),
          Offset(41, 30),
          Offset(51, 31),
          Offset(61, 33),
          Offset(69, 40),
        ]) {
          canvas.drawCircle(offset * scale, 8 * scale, hairPaint);
        }
        break;
      case _CartoonHairStyle.headband:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(50 * scale, 33 * scale),
            width: 52 * scale,
            height: 30 * scale,
          ),
          hairPaint,
        );
        final bandPaint = Paint()
          ..color = shirtPaint.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * scale
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          Rect.fromLTWH(28 * scale, 27 * scale, 44 * scale, 28 * scale),
          3.25,
          3.0,
          false,
          bandPaint,
        );
        break;
      case _CartoonHairStyle.puffs:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(50 * scale, 35 * scale),
            width: 44 * scale,
            height: 28 * scale,
          ),
          hairPaint,
        );
        break;
      case _CartoonHairStyle.sidePart:
        final path = Path()
          ..moveTo(25 * scale, 45 * scale)
          ..quadraticBezierTo(
            40 * scale,
            18 * scale,
            73 * scale,
            36 * scale,
          )
          ..quadraticBezierTo(
            62 * scale,
            47 * scale,
            25 * scale,
            45 * scale,
          );
        canvas.drawPath(path, hairPaint);
        break;
      case _CartoonHairStyle.swoop:
        final path = Path()
          ..moveTo(25 * scale, 43 * scale)
          ..quadraticBezierTo(
            54 * scale,
            14 * scale,
            76 * scale,
            44 * scale,
          )
          ..quadraticBezierTo(
            55 * scale,
            37 * scale,
            25 * scale,
            43 * scale,
          );
        canvas.drawPath(path, hairPaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _CartoonAvatarPainter oldDelegate) {
    return oldDelegate.background != background || oldDelegate.style != style;
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? avatarId;
  final double radius;

  const _ProfileAvatar({
    required this.photoUrl,
    required this.avatarId,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final cleanPhotoUrl = _cleanString(photoUrl);
    if (cleanPhotoUrl != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFF3E5F5),
        backgroundImage: NetworkImage(cleanPhotoUrl),
      );
    }

    final avatar = _avatarChoiceFor(avatarId);
    return _AvatarArt(avatar: avatar, radius: radius);
  }
}

class ProfileScreen extends StatefulWidget {
  final int initialTabIndex;
  final String? entryMessage;

  const ProfileScreen({
    super.key,
    this.initialTabIndex = 0,
    this.entryMessage,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldState> _profileScaffoldKey =
      GlobalKey<ScaffoldState>();
  User? _user;
  bool _entryMessageShown = false;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    if (_user != null) {
      _ensureUserDocExists();
    }
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entryMessage != widget.entryMessage) {
      _entryMessageShown = false;
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
        'avatarId': _avatarChoices.first.id,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      final data = snap.data() ?? {};
      final username = (data['username'] as String?)?.trim();
      if (username == null || username.isEmpty) {
        await docRef.set({'username': fallbackName}, SetOptions(merge: true));
      }
      final preserveContactEmail = data['childLoginWithoutOwnEmail'] == true;
      await docRef.set({
        if (!preserveContactEmail)
          'email': _user!.email?.trim().toLowerCase(),
        if (data['role'] == null) 'role': 'child',
        if (data['avatarId'] == null) 'avatarId': _avatarChoices.first.id,
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
    final safeInitialTab = widget.initialTabIndex.clamp(0, 2);

    if (!_entryMessageShown &&
        widget.entryMessage != null &&
        widget.entryMessage!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.entryMessage!.trim())),
        );
        _entryMessageShown = true;
      });
    }

    return DefaultTabController(
      length: 3,
      initialIndex: safeInitialTab,
      child: Scaffold(
        key: _profileScaffoldKey,
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
                Tab(text: "Saved"),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _StoriesTab(
                      title: "My Stories", status: "published", userId: userId),
                  _StoriesTab(title: "Drafts", status: "draft", userId: userId),
                  _SavedStoriesProfileTab(userId: userId),
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
    final String authFallbackEmail = _user?.email ?? "no-email@example.com";

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
              return _ProfileAvatar(
                photoUrl: _profilePhotoUrl(userData),
                avatarId: _profileAvatarId(userData),
                radius: 50,
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
              var contactEmail = authFallbackEmail;
              if (userDocSnap.hasData && userDocSnap.data!.exists) {
                final data = userDocSnap.data!.data() ?? {};
                final stored = (data['email'] as String?)?.trim();
                if (stored != null && stored.isNotEmpty) {
                  contactEmail = stored;
                }
                final dynamic usernameField =
                    data['username'] ?? data['displayName'];
                if (usernameField is String &&
                    usernameField.trim().isNotEmpty) {
                  displayName = usernameField.trim();
                } else if (_user?.displayName != null &&
                    _user!.displayName!.trim().isNotEmpty) {
                  displayName = _user!.displayName!.trim();
                } else {
                  displayName = contactEmail.split('@').first;
                }
              } else {
                if (_user?.displayName != null &&
                    _user!.displayName!.trim().isNotEmpty) {
                  displayName = _user!.displayName!.trim();
                } else {
                  displayName = contactEmail.split('@').first;
                }
              }
              final handle = '@${contactEmail.split('@').first}';

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
                currentAccountPicture: _ProfileAvatar(
                  photoUrl: _profilePhotoUrl(userData),
                  avatarId: _profileAvatarId(userData),
                  radius: 36,
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
                  _openDrawerRoute(
                    context,
                    builder: (_) => const BadgeScreen(),
                  );
                }),
                _buildParentApprovalDrawerItem(context),
                _buildDrawerItem(Icons.settings, "Settings", () {
                  _openDrawerRoute(
                    context,
                    builder: (_) => const SettingsScreen(),
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
                  _openDrawerRoute(
                    context,
                    builder: (_) => const FeedbackScreen(),
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
          _openDrawerRoute(
            context,
            builder: (_) => const ParentApprovalsScreen(),
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
    _openDrawerRoute(
      context,
      builder: (_) => _InfoPage(
        title: title,
        icon: icon,
        sections: sections,
      ),
    );
  }

  Future<void> _openDrawerRoute(
    BuildContext drawerContext, {
    required WidgetBuilder builder,
  }) async {
    Navigator.pop(drawerContext);

    await Navigator.of(context).push(
      MaterialPageRoute(builder: builder),
    );

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _profileScaffoldKey.currentState?.openDrawer();
    });
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
    return '';
  }

  String? _profileAvatarId(Map<String, dynamic>? data) {
    return _cleanString(data?['avatarId']);
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

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ContentModerationService _moderation = ContentModerationService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Timer? _moderationDebounce;
  ModerationLiveFeedback? _liveModeration;
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
  void initState() {
    super.initState();
    _messageController.addListener(_onFeedbackTextChanged);
  }

  void _onFeedbackTextChanged() {
    _moderationDebounce?.cancel();
    _moderationDebounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      final text = '$_category ${_messageController.text}';
      final fb = _moderation.previewWhileTyping(
        ModerationSurface.appFeedback,
        text,
      );
      setState(() => _liveModeration = fb);
    });
  }

  @override
  void dispose() {
    _moderationDebounce?.cancel();
    _messageController.removeListener(_onFeedbackTextChanged);
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

    final moderation = ContentModerationService().moderateWithSurface(
      ModerationSurface.appFeedback,
      '$_category $message',
    );
    if (!moderation.isSafe) {
      if (!mounted) return;
      await ModerationUi.showBlockDialog(
        context,
        result: moderation,
        surface: ModerationSurface.appFeedback,
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
                            setState(() {
                              _category = value;
                              _onFeedbackTextChanged();
                            });
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
                ModerationLiveBanner(feedback: _liveModeration),
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
  String? _avatarId;
  String _role = 'child';
  bool _saving = false;
  bool _photoSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _user?.displayName ?? "");
    _handleController = TextEditingController(text: _user?.email ?? "");
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
      final savedEmail = data['email'] as String?;
      if (savedEmail != null && savedEmail.trim().isNotEmpty) {
        _handleController.text = savedEmail.trim().toLowerCase();
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
      final avatarId = _cleanString(data['avatarId']);
      if (mounted) {
        setState(() {
          _avatarId = avatarId;
          if (photoUrl != null && photoUrl.trim().isNotEmpty) {
            _photoUrl = photoUrl.trim();
          }
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
      final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$');
      if (!emailRegex.hasMatch(parentEmail)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid parent email')),
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
      await _user!.reload();

      final hasUploadedPhoto =
          _photoUrl != null && _photoUrl!.trim().isNotEmpty;

      // Update users/{uid}.username (create doc if missing)
      await _db.collection('users').doc(_user!.uid).set({
        'username': newName,
        'displayName': newName,
        'email': _user!.email?.trim().toLowerCase(),
        'role': _role,
        'parentEmail': _role == 'child' && parentEmail.isNotEmpty
            ? parentEmail
            : FieldValue.delete(),
        'photoURL': hasUploadedPhoto ? _photoUrl : FieldValue.delete(),
        'profileImageUrl': hasUploadedPhoto ? _photoUrl : FieldValue.delete(),
        if (!hasUploadedPhoto) 'profileImagePath': FieldValue.delete(),
        'profileImageType': hasUploadedPhoto ? 'upload' : 'avatar',
        'avatarId': hasUploadedPhoto
            ? FieldValue.delete()
            : _avatarId ?? _avatarChoices.first.id,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _syncAuthoredStoryIdentity(newName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
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

  Future<void> _syncAuthoredStoryIdentity(String username) async {
    final user = _user;
    if (user == null) return;

    final stories = await _db
        .collection('stories')
        .where('authorId', isEqualTo: user.uid)
        .get();
    if (stories.docs.isEmpty) return;

    var batch = _db.batch();
    var writeCount = 0;
    final handle = username.replaceAll(' ', '').toLowerCase();

    for (final story in stories.docs) {
      batch.set(
        story.reference,
        {
          'authorName': username,
          'username': username,
          'handle': handle,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      writeCount++;

      if (writeCount == 450) {
        await batch.commit();
        batch = _db.batch();
        writeCount = 0;
      }
    }

    if (writeCount > 0) {
      await batch.commit();
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
        'profileImageType': 'upload',
        'avatarId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _photoUrl = downloadUrl;
        _avatarId = null;
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
      await _deleteStoredProfileImage(snap.data()?['profileImagePath']);
      final fallbackAvatarId = _avatarId ?? _avatarChoices.first.id;

      await _user!.updatePhotoURL(null);
      await userDoc.set({
        'photoURL': FieldValue.delete(),
        'profileImageUrl': FieldValue.delete(),
        'profileImagePath': FieldValue.delete(),
        'profileImageType': 'avatar',
        'avatarId': fallbackAvatarId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _photoUrl = null;
        _avatarId = fallbackAvatarId;
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

  Future<void> _selectAvatar(String avatarId) async {
    if (_user == null || _photoSaving) return;

    setState(() {
      _avatarId = avatarId;
      _photoSaving = true;
    });

    try {
      final userDoc = _db.collection('users').doc(_user!.uid);
      final snap = await userDoc.get();
      await _deleteStoredProfileImage(snap.data()?['profileImagePath']);

      await _user!.updatePhotoURL(null);
      await userDoc.set({
        'avatarId': avatarId,
        'photoURL': FieldValue.delete(),
        'profileImageUrl': FieldValue.delete(),
        'profileImagePath': FieldValue.delete(),
        'profileImageType': 'avatar',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _photoUrl = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avatar updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating avatar: $e'),
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

  Future<void> _deleteStoredProfileImage(dynamic storagePathValue) async {
    if (storagePathValue is! String || storagePathValue.trim().isEmpty) {
      return;
    }

    try {
      await _storage.ref(storagePathValue.trim()).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }

  Future<void> _showAvatarPicker() async {
    final selectedAvatarId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final availableHeight = mediaQuery.size.height -
            mediaQuery.padding.top -
            mediaQuery.padding.bottom -
            mediaQuery.viewInsets.bottom;
        final sheetHeight =
            (availableHeight * 0.72).clamp(320.0, 560.0).toDouble();

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              16 + mediaQuery.viewInsets.bottom,
            ),
            child: SizedBox(
              height: sheetHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose Avatar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount =
                            constraints.maxWidth >= 420 ? 4 : 3;

                        return GridView.builder(
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: _avatarChoices.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1,
                          ),
                          itemBuilder: (context, index) {
                            final avatar = _avatarChoices[index];
                            final isSelected = avatar.id == _avatarId;
                            return InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => Navigator.pop(context, avatar.id),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? kAppPrimary.withValues(alpha: 0.08)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? kAppPrimary
                                        : const Color(0xFFE3D8EF),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Center(
                                  child: _AvatarArt(avatar: avatar, radius: 30),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selectedAvatarId != null) {
      await _selectAvatar(selectedAvatarId);
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

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Scaffold(
      appBar: AppBar(
        title:
            const Text("Edit Profile", style: TextStyle(color: Colors.white)),
        backgroundColor: kAppPrimary,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 380 ? 12.0 : 16.0;
            final avatarRadius = constraints.maxHeight < 620 ? 42.0 : 50.0;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                24 + viewInsets.bottom,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            _ProfileAvatar(
                              radius: avatarRadius,
                              photoUrl: _photoUrl,
                              avatarId: _avatarId,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _photoSaving
                                      ? null
                                      : _showAvatarPicker,
                                  icon: const Icon(Icons.face),
                                  label: const Text('Choose Avatar'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _photoSaving
                                      ? null
                                      : _pickAndUploadProfilePhoto,
                                  icon: _photoSaving
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.photo_camera),
                                  label: Text(
                                    _photoUrl == null
                                        ? 'Upload Photo'
                                        : 'Update',
                                  ),
                                ),
                                if (_photoUrl != null)
                                  TextButton.icon(
                                    onPressed: _photoSaving
                                        ? null
                                        : _removeProfilePhoto,
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Remove Photo'),
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
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        textInputAction: TextInputAction.next,
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
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: "Email",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      if (_role == 'child') ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _parentEmailController,
                          enabled: false,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: "Parent Email",
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
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "Save Changes",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
            final likes = _readInt(data['likes']);

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
                        Icon(
                          likes > 0 ? Icons.favorite : Icons.favorite_border,
                          size: 14,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$likes',
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
    final contentBlocks = StoryContentCodec.parseContent(data['content']);

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
      contentBlocks: contentBlocks,
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

class _SavedStoriesProfileTab extends StatelessWidget {
  final String? userId;

  const _SavedStoriesProfileTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    final uid = userId;
    if (uid == null) return const Center(child: Text('User not logged in'));

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: kAppPrimary),
          );
        }

        final savedStoryIds = _readStringList(
          snapshot.data?.data()?['savedStoryIds'],
        );
        if (savedStoryIds.isEmpty) return _emptyState();

        return FutureBuilder<List<StoryPost>>(
          future: _loadSavedPosts(savedStoryIds, uid),
          builder: (context, postSnap) {
            if (postSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: kAppPrimary),
              );
            }

            final posts = postSnap.data ?? const <StoryPost>[];
            if (posts.isEmpty) return _emptyState();

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    onTap: () => _openSavedPost(context, post, uid),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        post.imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 50,
                          height: 50,
                          color: kAppPrimary,
                          child: const Icon(Icons.book, color: Colors.white),
                        ),
                      ),
                    ),
                    title: Text(
                      post.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'by ${post.author}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.bookmark, color: kAppPrimary),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<List<StoryPost>> _loadSavedPosts(
    List<String> storyIds,
    String uid,
  ) async {
    final posts = <StoryPost>[];

    for (final storyId in storyIds) {
      final storyDoc = await FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .get();
      final data = storyDoc.data();
      if (!storyDoc.exists || data == null || data['status'] != 'published') {
        continue;
      }

      final authorName =
          (data['authorName'] as String?)?.trim().isNotEmpty == true
              ? (data['authorName'] as String).trim()
              : 'Unknown';
      final coverUrl = data['coverUrl'] as String?;
      final likedBy = (data['likedBy'] as List?) ?? const [];

      final contentBlocks = StoryContentCodec.parseContent(data['content']);
      posts.add(
        StoryPost(
          id: storyDoc.id,
          author: authorName,
          handle: (data['handle'] as String?) ??
              authorName.replaceAll(' ', '').toLowerCase(),
          title: (data['title'] as String?) ?? 'Untitled',
          excerpt: (data['body'] as String?) ?? '',
          likes: _readInt(data['likes']),
          comments: _readInt(data['comments']),
          likedByMe: likedBy.contains(uid),
          accent: kAppPrimary,
          imageUrl: coverUrl != null && coverUrl.isNotEmpty
              ? coverUrl
              : 'https://picsum.photos/seed/${storyDoc.id}/600/300',
          contentBlocks: contentBlocks,
        ),
      );
    }

    return posts;
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No saved stories yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _openSavedPost(BuildContext context, StoryPost post, String uid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryReaderPage(
          post: post,
          service: StoryService(),
          userId: uid,
          userName: FirebaseAuth.instance.currentUser?.displayName ?? 'User',
        ),
      ),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<String>().where((id) => id.isNotEmpty).toList();
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
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _passwordController.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;

    if (currentPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your current password'),
        ),
      );
      return;
    }

    if (newPassword.isEmpty || newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters'),
        ),
      );
      return;
    }

    if (user == null || email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to verify this account'),
        ),
      );
      return;
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _currentPasswordController.clear();
        _passwordController.clear();
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        final message = switch (e.code) {
          'wrong-password' ||
          'invalid-credential' =>
            'Current password is incorrect',
          'weak-password' => 'New password is too weak',
          'requires-recent-login' =>
            'Please sign in again before changing your password',
          _ => e.message ?? 'Password update failed',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password update failed')),
        );
      }
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
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
              _currentPasswordController.clear();
              _passwordController.clear();
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Change Password"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _currentPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: "Enter current password",
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: "Enter new password",
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        _currentPasswordController.clear();
                        _passwordController.clear();
                        Navigator.pop(context);
                      },
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
