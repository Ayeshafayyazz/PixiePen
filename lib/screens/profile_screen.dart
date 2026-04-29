// profile_screen.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'my_stories_screen.dart';
import 'write_story_screen.dart';
import 'community.dart';
import 'ebook_screen.dart';
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
    final fallbackName = (_user!.displayName != null && _user!.displayName!.trim().isNotEmpty)
        ? _user!.displayName!.trim()
        : (_user!.email?.split('@').first ?? 'guest');

    if (!snap.exists) {
      await docRef.set({
        'username': fallbackName,
        'email': _user!.email,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      final data = snap.data() ?? {};
      final username = (data['username'] as String?)?.trim();
      if (username == null || username.isEmpty) {
        await docRef.set({'username': fallbackName}, SetOptions(merge: true));
      }
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
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
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
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
          ],
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
                  _StoriesTab(title: "My Stories", status: "published", userId: userId),
                  _StoriesTab(title: "Drafts", status: "draft", userId: userId),
                ],
              ),
            ),
          ],
        ),
      ),
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
            stream: userId != null ? _db.collection('users').doc(userId).snapshots() : const Stream.empty(),
            builder: (context, userDocSnap) {
              String displayName = "Guest User";

              if (userDocSnap.hasData && userDocSnap.data!.exists) {
                final data = userDocSnap.data!.data() ?? {};
                final dynamic usernameField = data['username'] ?? data['displayName'];
                if (usernameField is String && usernameField.trim().isNotEmpty) {
                  displayName = usernameField.trim();
                } else if (_user?.displayName != null && _user!.displayName!.trim().isNotEmpty) {
                  displayName = _user!.displayName!.trim();
                } else {
                  displayName = email.split('@').first;
                }
              } else {
                if (_user?.displayName != null && _user!.displayName!.trim().isNotEmpty) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLikesStatCard(userId),
              _buildStatCardStream(
                icon: Icons.book,
                label: "Stories",
                color: Colors.blue,
                userId: userId,
                isLikes: false,
              ),
            ],
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
            return _buildStatCard(Icons.favorite, totalLikesRaw.toString(), "Likes", Colors.red);
          }
          if (totalLikesRaw is String) {
            final parsed = int.tryParse(totalLikesRaw) ?? 0;
            return _buildStatCard(Icons.favorite, parsed.toString(), "Likes", Colors.red);
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

  Widget _buildStatCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      width: 95,
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
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
            stream: _user != null ? _db.collection('users').doc(_user!.uid).snapshots() : const Stream.empty(),
            builder: (context, snap) {
              String displayName = _user?.displayName ?? "Guest User";
              Map<String, dynamic>? userData;
              if (snap.hasData && snap.data!.exists) {
                userData = snap.data!.data() ?? {};
                final username = (userData['username'] as String?)?.trim();
                if (username != null && username.isNotEmpty) {
                  displayName = username;
                } else if (_user?.displayName != null && _user!.displayName!.trim().isNotEmpty) {
                  displayName = _user!.displayName!.trim();
                } else {
                  displayName = email.split('@').first;
                }
              } else {
                if (_user?.displayName != null && _user!.displayName!.trim().isNotEmpty) {
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
          _buildDrawerItem(Icons.book, "My Stories", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyStoriesScreen()),
            );
          }),
          _buildDrawerItem(Icons.edit_note, "Write Story", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WriteStoryScreen()),
            );
          }),
          _buildDrawerItem(Icons.people, "Community", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CommunityScreen()),
            );
          }),
          _buildDrawerItem(Icons.menu_book, "Ebooks", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EbookScreen()),
            );
          }),
          const Spacer(),
          _buildDrawerItem(Icons.settings, "Settings", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: kAppPrimary),
      title: Text(title),
      onTap: onTap,
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
/// BADGE SCREEN
/// =============================================================================

class BadgeScreen extends StatelessWidget {
  const BadgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final badges = [
      {"icon": Icons.star, "label": "Rookie"},
      {"icon": Icons.bolt, "label": "Fast Writer"},
      {"icon": Icons.favorite, "label": "Loved"},
      {"icon": Icons.public, "label": "Explorer"},
    ];

    int unlocked = 3;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Badges", style: TextStyle(color: Colors.white)),
        backgroundColor: kAppPrimary,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            "$unlocked / ${badges.length} Badges Unlocked 🎉",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LinearProgressIndicator(
              value: unlocked / badges.length,
              minHeight: 8,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation(kAppPrimary),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: badges.length,
              itemBuilder: (context, index) {
                final isUnlocked = index < unlocked;
                return Opacity(
                  opacity: isUnlocked ? 1.0 : 0.5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isUnlocked ? kAppPrimary : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          badges[index]['icon'] as IconData,
                          size: 32,
                          color: isUnlocked ? Colors.white : Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          badges[index]['label'] as String,
                          style: TextStyle(
                            color: isUnlocked ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.bold,
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
      ),
    );
  }
}

/// =============================================================================
/// EDIT PROFILE SCREEN (saves to both Auth and users/{uid}.username)
/// =============================================================================

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
  String? _photoUrl;
  bool _saving = false;
  bool _photoSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _user?.displayName ?? "");
    _handleController = TextEditingController(text: _user?.email?.split('@').first ?? "");
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
      final photoUrl = (data['photoURL'] as String?) ??
          (data['profileImageUrl'] as String?);
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
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_user == null) return;
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
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
        'photoURL': _photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e'), backgroundColor: Colors.red),
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
        title: const Text("Edit Profile", style: TextStyle(color: Colors.white)),
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
                                child: CircularProgressIndicator(strokeWidth: 2),
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
                      '${data['wordCount'] ?? 0} words',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Row(
                      children: [
                        Icon(Icons.favorite, size: 14, color: Colors.red),
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
    final authorName =
        (data['authorName'] as String?) ??
        FirebaseAuth.instance.currentUser?.displayName ??
        'You';
    final handle =
        (data['handle'] as String?) ??
        authorName.replaceAll(' ', '').toLowerCase();
    final likes = _readInt(data['likes']);
    final comments = _readInt(data['comments']);
    final likedBy = (data['likedBy'] as List?) ?? [];
    final likedByMe =
        widget.userId != null && likedBy.contains(widget.userId);
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
          userName:
              currentUser?.displayName ?? currentUser?.email ?? 'User',
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
              FirebaseFirestore.instance.collection('stories').doc(storyId).delete();
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
