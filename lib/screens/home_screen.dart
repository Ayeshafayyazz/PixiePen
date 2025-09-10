/*import 'package:flutter/material.dart';

import 'mystories_screen.dart';
import 'write_story_screen.dart';
import 'community.dart';
import 'reward_screen.dart';
import 'profile_screen.dart';
import 'ebook_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<String> _prompts = const [
    "What if animals could talk? 🐶🐱",
    "Imagine a secret door in your room 🚪✨",
    "What if toys came alive? 🧸🤖",
    "A magical world where kids rule 👑",
  ];
  late String _currentPrompt;

  @override
  void initState() {
    super.initState();
    _currentPrompt = _prompts.first;
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    if (index == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunityScreen()));
    } else if (index == 2) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const EbookScreen()));
    } else if (index == 3) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
    }
  }

  void _refreshPrompt() {
    setState(() {
      final shuffled = List<String>.from(_prompts)..shuffle();
      _currentPrompt = shuffled.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "PixiePen ✨",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
      ),

      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const _DrawerHeader(),
              _drawerItem(
                icon: Icons.home_rounded,
                label: "Home",
                onTap: () => Navigator.pop(context),
              ),
              _drawerItem(
                icon: Icons.book_rounded,
                label: "My Stories",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyStoriesScreen()),
                ),
              ),
              _drawerItem(
                icon: Icons.menu_book_rounded,
                label: "Ebooks",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EbookScreen()),
                ),
              ),
              _drawerItem(
                icon: Icons.emoji_events_rounded,
                label: "Rewards",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RewardScreen()),
                ),
              ),
              _drawerItem(
                icon: Icons.person_rounded,
                label: "Profile",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
              ),
              const Divider(),
              _drawerItem(
                icon: Icons.logout,
                label: "Logout",
                iconColor: Colors.red,
                textColor: Colors.red,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Logout"),
                      content: const Text("Are you sure you want to logout?"),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context); // close dialog
                            Navigator.pop(context); // close drawer
                          },
                          child: const Text("Logout", style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hi Ayesha! 👋",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Ready to create your next story?",
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _BouncyCard(
                  color: Colors.indigo,
                  icon: Icons.edit,
                  title: "Write Story",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WriteStoryScreen(
                        onPost: (title, content) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Story '$title' posted!")),
                          );
                          // TODO: optionally send this to Community feed
                        },
                      ),
                    ),
                  ),
                ),
                _BouncyCard(
                  color: Colors.teal,
                  icon: Icons.mic,
                  title: "Speak Story",
                  onTap: () {},
                ),
                _BouncyCard(
                  color: Colors.blue,
                  icon: Icons.book,
                  title: "My Stories",
                  onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const MyStoriesScreen()),
                  ),
                ),
                _BouncyCard(
                  color: Colors.amber,
                  icon: Icons.emoji_events,
                  title: "Badges",
                  onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const RewardScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.deepPurple, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb, color: Colors.deepPurple, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Story Inspiration: $_currentPrompt",
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.deepPurple),
                    onPressed: _refreshPrompt,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.group_rounded), label: "Community"),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book_rounded), label: "Ebooks"),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "Profile"),
        ],
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = Colors.deepPurple,
    Color textColor = Colors.black87,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(label, style: TextStyle(color: textColor, fontSize: 16)),
      onTap: onTap,
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.deepPurple,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: const [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: Icon(Icons.person, size: 40, color: Colors.deepPurple),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 6),
                Text(
                  "Ayesha",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  "ayesha@email.com",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BouncyCard extends StatefulWidget {
  final Color color;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _BouncyCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  State<_BouncyCard> createState() => _BouncyCardState();
}

class _BouncyCardState extends State<_BouncyCard> {
  double _scale = 1.0;

  void _press(bool down) {
    setState(() {
      _scale = down ? 0.94 : 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _press(true),
      onTapCancel: () => _press(false),
      onTapUp: (_) {
        _press(false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutBack,
        child: Container(
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 40),
              const SizedBox(height: 10),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
*/
