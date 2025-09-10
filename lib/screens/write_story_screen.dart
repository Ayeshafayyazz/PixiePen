import 'package:flutter/material.dart';
import 'speech_to_text_screen.dart';
import 'ai_image_generator_screen.dart';
import 'theme.dart'; // 👈 for kAppPrimary

class WriteStoryScreen extends StatefulWidget {
  const WriteStoryScreen({super.key});

  @override
  State<WriteStoryScreen> createState() => _WriteStoryScreenState();
}

class _WriteStoryScreenState extends State<WriteStoryScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  int get _wordCount {
    if (_bodyController.text.trim().isEmpty) return 0;
    return _bodyController.text.trim().split(RegExp(r"\s+")).length;
  }

  void _saveStory() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Story saved ✅")),
    );
  }

  void _publishStory() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Story published 🚀")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kAppPrimary,
        centerTitle: true,
        title: const Text(
          "Write Story ✏️",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Title field
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: "Story Title",
                filled: true,
                fillColor: kAppPrimary.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Story field
            Expanded(
              child: TextField(
                controller: _bodyController,
                onChanged: (_) => setState(() {}),
                maxLines: null,
                expands: true,
                decoration: InputDecoration(
                  hintText: "Start writing your magical story here...",
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Word count
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "Word count: $_wordCount",
                style: const TextStyle(color: kAppPrimary),
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons (AI Images, Speech)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  color: kAppPrimary,
                  icon: Icons.image,
                  label: "To Pictures",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AiImageGeneratorScreen(),
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  color: kAppPrimary,
                  icon: Icons.mic,
                  label: "Speak",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SpeechToTextScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Save and Publish
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saveStory,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kAppPrimary,
                      side: const BorderSide(color: kAppPrimary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.save),
                    label: const Text("Save"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _publishStory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAppPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.send),
                    label: const Text("Publish"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
