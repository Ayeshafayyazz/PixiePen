import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import 'ebook_screen.dart';
import 'mystories_screen.dart';
import 'write_story_screen.dart';
import 'community.dart';
import 'reward_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CommunityScreen()),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const RewardScreen()),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    } else {
      setState(() => _selectedIndex = index);
      _pageController.jumpToPage(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // 🌟 Drawer (Side Menu)
      drawer: _buildSideMenu(),

      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        // <-- menu icon white
        title: Text(
          "PixiePen ✨",
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),

      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildHomeContent(),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.deepPurple,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.public), label: "Community"),
          BottomNavigationBarItem(
              icon: Icon(Icons.card_giftcard), label: "Rewards"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  // 🏠 Home Content
  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🌈 Greeting Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.deepPurple, Color(0xFF7E57C2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Hi Writer 👋",
                          style: GoogleFonts.baloo2(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 6),
                      Text("Ready to create your next magical story?",
                          style: GoogleFonts.baloo2(
                              fontSize: 16, color: Colors.white70)),
                    ],
                  ),
                ),
                SizedBox(
                  height: 90,
                  width: 90,
                  child: Lottie.asset("assets/lottie/Celebrations.json"),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 🎯 Quick Actions
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildFancyCard(
                gradient: const LinearGradient(
                  colors: [Colors.deepPurple, Colors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                icon: Icons.edit,
                title: "Write a Story",
                subtitle: "Create magical tales",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const WriteStoryScreen()),
                  );
                },
              ),
              _buildFancyCard(
                gradient: const LinearGradient(
                  colors: [Colors.teal, Colors.blueAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                icon: Icons.mic,
                title: "Speak a Story",
                subtitle: "Use your voice",
                onTap: () {},
              ),
              _buildFancyCard(
                gradient: const LinearGradient(
                  colors: [Colors.orange, Colors.yellow],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                icon: Icons.book,
                title: "My Stories",
                subtitle: "Your collection",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const MyStoriesScreen()),
                  );
                },
              ),
              _buildFancyCard(
                gradient: const LinearGradient(
                  colors: [Colors.pink, Colors.deepPurpleAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                icon: Icons.menu_book,
                title: "My E-Book",
                subtitle: "Make books",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                      const EBookScreen(),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ✨ Inspiration Zone
          Text("✨ Inspiration Zone",
              style: GoogleFonts.baloo2(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepPurple)),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.deepPurple, Colors.blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "What if your toys could come alive? 🧸🤖",
                    style: GoogleFonts.baloo2(
                        fontSize: 16, color: Colors.white),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () {
                    setState(() {}); // refresh prompt
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 Fancy Action Card
  Widget _buildFancyCard({
    required LinearGradient gradient,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.6),
                    Colors.white.withOpacity(0.1)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 14),
            Text(title,
                style: GoogleFonts.baloo2(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(subtitle,
                style: GoogleFonts.baloo2(
                    fontSize: 13, color: Colors.white70),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

// add this at top of your _HomeDashboardState
  int _selectedDrawerIndex = 0;

  Drawer _buildSideMenu() {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.deepPurple,
              ),
              accountName: Text(
                "Pixie Writer",
                style: GoogleFonts.baloo2(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              accountEmail: Text(
                "pixiepen@magic.com",
                style: GoogleFonts.baloo2(color: Colors.white70),
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Colors.deepPurple),
              ),
            ),

            // 🏠 Home
            _buildDrawerTile(
              index: 0,
              icon: Icons.settings,
              title: "Settings",
              onTap: () {
                setState(() => _selectedDrawerIndex = 0);
                Navigator.pop(context);
              },
            ),

            // ✍️ Write a Story
            _buildDrawerTile(
              index: 1,
              icon: Icons.help,
              title: "Help/Tutorials",
              onTap: () {
                setState(() => _selectedDrawerIndex = 1);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const WriteStoryScreen()));
              },
            ),



            // 📖 My E-Book
            _buildDrawerTile(
              index: 3,
              icon: Icons.feedback,
              title: "Feedback",
              onTap: () {
                setState(() => _selectedDrawerIndex = 3);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const EBookScreen()));
              },
            ),




            const Spacer(),
            const Divider(color: Colors.black12),

            // 🚪 Logout
            _buildDrawerTile(
              index: 7,
              icon: Icons.logout,
              title: "Logout",
              iconColor: Colors.red,
              textColor: Colors.red,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Logout"),
                    content: const Text("Are you sure you want to logout?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                          // TODO: Add logout logic
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
    );
  }

  /// Drawer ListTile with highlight effect
  Widget _buildDrawerTile({
    required int index,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color iconColor = Colors.deepPurple,
    Color textColor = Colors.deepPurple,
  }) {
    final bool selected = _selectedDrawerIndex == index;

    return Container(
      color: selected ? Colors.deepPurple.withOpacity(0.1) : Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: selected ? Colors.deepPurple : iconColor),
        title: Text(
          title,
          style: GoogleFonts.baloo2(
            color: selected ? Colors.deepPurple : textColor,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: onTap,
      ),
    );
  }



}