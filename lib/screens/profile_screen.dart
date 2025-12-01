import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
  }

  Future<void> _logout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Logout")),
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
              icon: const Icon(Icons.notifications, color: Colors.white),
              onPressed: () {},
            ),
          ],
        ),
        extendBodyBehindAppBar: true,
        body: Column(
          children: [
            _buildHeader(context),
            const TabBar(
              indicatorColor: kAppPrimary,
              labelColor: kAppPrimary,
              unselectedLabelColor: Colors.grey,
              labelStyle: TextStyle(fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: "My Stories"),
                Tab(text: "Saved"),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _StoriesTab(title: "My Stories"),
                  _StoriesTab(title: "Saved Stories"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final String displayName = _user?.displayName ?? "Guest User";
    final String email = _user?.email ?? "no-email@example.com";
    final String photoURL = _user?.photoURL ?? "https://i.pravatar.cc/150?img=12";
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
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
          ),
          const SizedBox(height: 20),
          CircleAvatar(radius: 50, backgroundImage: NetworkImage(photoURL)),
          const SizedBox(height: 12),
          Text(displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(handle, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCard(Icons.book_rounded, "12", "Stories", Colors.orange),
              _buildStatCard(Icons.favorite, "230", "Likes", Colors.pink),
              _buildStatCard(Icons.emoji_events, "5", "Badges", Colors.amber,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const BadgeScreen()));
                  }),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: kAppPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.edit, size: 20),
            label: const Text("Edit Profile"),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        width: 95,
        decoration: BoxDecoration(
          color: color.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 3))],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final String displayName = _user?.displayName ?? "Guest User";
    final String email = _user?.email ?? "no-email@example.com";
    final String photoURL = _user?.photoURL ?? "https://i.pravatar.cc/150?img=12";

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: kAppPrimary),
            currentAccountPicture: CircleAvatar(backgroundImage: NetworkImage(photoURL)),
            accountName: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            accountEmail: Text(email),
          ),
          _buildDrawerItem(Icons.book, "My Stories", () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MyStoriesScreen()));
          }),
          _buildDrawerItem(Icons.edit_note, "Write Story", () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const WriteStoryScreen()));
          }),
          _buildDrawerItem(Icons.people, "Community", () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunityScreen()));
          }),
          _buildDrawerItem(Icons.menu_book, "Ebooks", () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const EbookScreen()));
          }),
          const Spacer(),
          _buildDrawerItem(Icons.settings, "Settings", () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
          }),
          _buildDrawerItem(Icons.logout, "Logout", _logout),
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
}

// Badge Screen
class BadgeScreen extends StatelessWidget {
  const BadgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final badges = [
      {"icon": Icons.star, "label": "Rookie"},
      {"icon": Icons.bolt, "label": "Fast Writer"},
      {"icon": Icons.favorite, "label": "Loved"},
      {"icon": Icons.public, "label": "Explorer"},
      {"icon": Icons.lightbulb, "label": "Creative"},
      {"icon": Icons.emoji_events, "label": "Champion"},
    ];

    int unlocked = 3;

    return Scaffold(
      appBar: AppBar(title: const Text("My Badges", style: TextStyle(color: Colors.white)), backgroundColor: kAppPrimary),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Text("$unlocked / ${badges.length} Badges Unlocked 🎉", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LinearProgressIndicator(
              value: unlocked / badges.length,
              backgroundColor: Colors.grey.shade300,
              color: kAppPrimary,
              minHeight: 10,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16),
              itemCount: badges.length,
              itemBuilder: (context, index) {
                final badge = badges[index];
                final isUnlocked = index < unlocked;
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isUnlocked ? [kAppPrimary, Colors.purple.shade300] : [Colors.grey.shade400, Colors.grey.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: const Offset(0, 3))],
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(badge["icon"] as IconData, color: Colors.white, size: 48),
                    const SizedBox(height: 8),
                    Text(badge["label"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Edit Profile Screen
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _handleController;
  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _user?.displayName ?? "");
    _handleController = TextEditingController(text: _user?.email?.split('@').first ?? "");
  }

  @override
  void dispose() {
    _nameController.dispose();
    _handleController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saving changes...')));
    try {
      await _user?.updateDisplayName(_nameController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update profile: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profile", style: TextStyle(color: Colors.white)), backgroundColor: kAppPrimary),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(radius: 50, backgroundImage: NetworkImage(_user?.photoURL ?? "https://i.pravatar.cc/150?img=12")),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    backgroundColor: kAppPrimary,
                    radius: 18,
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(
            controller: _handleController,
            readOnly: true,
            decoration: const InputDecoration(labelText: "Handle (from email)", border: OutlineInputBorder(), filled: true, fillColor: Color.fromARGB(255, 236, 236, 236)),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saveChanges,
            style: ElevatedButton.styleFrom(backgroundColor: kAppPrimary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
            child: const Text("Save Changes"),
          ),
        ]),
      ),
    );
  }
}

// Stories Tab
class _StoriesTab extends StatelessWidget {
  final String title;
  const _StoriesTab({required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stories = List.generate(5, (i) => {"title": "$title #$i", "excerpt": "This is a short preview of $title #$i..."});

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: stories.length,
      itemBuilder: (context, index) {
        final story = stories[index];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(story["title"]!, style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurface)),
            subtitle: Text(story["excerpt"]!, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
        );
      },
    );
  }
}

// Settings Screen
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
              // TODO: Implement Change Password
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text("Notifications"),
            onTap: () {
              // TODO: Implement Notifications Settings
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text("About"),
            onTap: () {
              // TODO: Implement About
            },
          ),
        ],
      ),
    );
  }
}
