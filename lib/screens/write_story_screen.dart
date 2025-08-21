import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WriteStoryScreen extends StatefulWidget {
  const WriteStoryScreen({super.key});

  @override
  State<WriteStoryScreen> createState() => _WriteStoryScreenState();
}

class _WriteStoryScreenState extends State<WriteStoryScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _storyController = TextEditingController();
  int _wordCount = 0;

  void _updateWordCount() {
    setState(() {
      _wordCount = _storyController.text.trim().isEmpty
          ? 0
          : _storyController.text.trim().split(RegExp(r"\s+")).length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🔝 Top Bar
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: TextField(
          controller: _titleController,
          style: GoogleFonts.baloo2(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          decoration: const InputDecoration(
            hintText: "My Magical Adventure...",
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      // ✍️ Main Writing Area with gradient background
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEDE7F6), Color(0xFFE3F2FD)], // soft purple + blue
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white, // white "storybook" pad
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: TextField(
                  controller: _storyController,
                  onChanged: (_) => _updateWordCount(),
                  maxLines: null,
                  expands: true,
                  style: GoogleFonts.baloo2(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  cursorColor: Colors.deepPurple,
                  decoration: const InputDecoration(
                    hintText: "Once upon a time... ✨",
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),

            // 🎛️ Floating Tool Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildToolbarButton(Icons.people, "Perspective"),
                  _buildToolbarButton(Icons.mic, "Speak"),
                  _buildToolbarButton(Icons.image, "Image"),
                ],
              ),
            ),

            // 📑 Bottom Action Bar
            Container(
              color: Colors.white.withOpacity(0.9),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Word Counter / XP
                  Text(
                    "Words: $_wordCount",
                    style: GoogleFonts.baloo2(
                      fontSize: 14,
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Row(
                    children: [
                      _bottomActionButton(Icons.preview, "Preview"),
                      const SizedBox(width: 12),
                      _bottomActionButton(Icons.save, "Save"),
                      const SizedBox(width: 12),
                      _bottomActionButton(Icons.rocket_launch, "Next"),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🎛️ Toolbar button
  Widget _buildToolbarButton(IconData icon, String label) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: Colors.deepPurple,
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.baloo2(
            fontSize: 12,
            color: Colors.deepPurple,
          ),
        ),
      ],
    );
  }

  // 📑 Bottom Action Button
  Widget _bottomActionButton(IconData icon, String label) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      icon: Icon(icon, size: 16, color: Colors.white),
      label: Text(
        label,
        style: GoogleFonts.baloo2(color: Colors.white, fontSize: 14),
      ),
      onPressed: () {
        // TODO: Add functionality later
      },
    );
  }
}
