import 'package:flutter/material.dart';
import 'speech_to_text_screen.dart';
import 'theme.dart';
import 'ai_image_generator_screen.dart';

class WriteStoryScreen extends StatefulWidget {
  const WriteStoryScreen({super.key});

  @override
  State<WriteStoryScreen> createState() => _WriteStoryScreenState();
}

class _WriteStoryScreenState extends State<WriteStoryScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  String? _storyCoverUrl;

  int get _wordCount {
    if (_bodyController.text.trim().isEmpty) return 0;
    return _bodyController.text.trim().split(RegExp(r"\s+")).length;
  }

  double get _wordProgress => (_wordCount / 200).clamp(0.0, 1.0);

  void _saveStory() {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Story saved successfully ✅")),
    );
  }

  void _publishStory() {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Your story is now live! 🚀")),
    );
  }

  Future<void> _goToAiGenerator() async {
    final storyDescription = _bodyController.text.trim();
    if (storyDescription.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Write some story before generating image.")),
      );
      return;
    }

    final selectedImage = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiImageGeneratorScreen(
          initialPrompt: storyDescription,
        ),
      ),
    );

    if (selectedImage != null && mounted) {
      setState(() {
        _storyCoverUrl = selectedImage;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Cover image added successfully!")),
      );
    }
  }

  Future<void> _goToSpeechToText() async {
    final spokenText = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SpeechToTextScreen()),
    );

    if (spokenText != null && mounted) {
      setState(() {
        _bodyController.text = spokenText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressColor =
    _wordProgress < 1.0 ? kAppPrimary : Colors.green.shade600;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FF),
      appBar: AppBar(
        backgroundColor: kAppPrimary,
        centerTitle: true,
        title: const Text(
          "Write Your Story ✏️",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // --- Title Input ---
              _buildTextField(
                controller: _titleController,
                hint: "Enter story title...",
                icon: Icons.title,
                maxLines: 1,
              ),

              if (_storyCoverUrl != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    _storyCoverUrl!,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // --- Story Body ---
              Expanded(
                child: _buildTextField(
                  controller: _bodyController,
                  hint: "Start writing your magical story here...",
                  icon: Icons.menu_book,
                  maxLines: null,
                  expands: true,
                  onChanged: (_) => setState(() {}),
                  outlined: true,
                ),
              ),

              const SizedBox(height: 12),

              // --- Word Count ---
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: _wordProgress,
                    color: progressColor,
                    backgroundColor: Colors.grey.shade300,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "Word count: $_wordCount / 200",
                      style: TextStyle(
                        color: progressColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // --- Quick Actions ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: Icons.image,
                    label: "To Picture",
                    onTap: _goToAiGenerator,
                    color: kAppPrimary,
                  ),
                  _buildActionButton(
                    icon: Icons.mic,
                    label: "Speak",
                    onTap: _goToSpeechToText,
                    color: kAppPrimary,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // --- Save & Publish ---
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saveStory,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kAppPrimary,
                        side: const BorderSide(color: kAppPrimary, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
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
      ),
    );
  }

  // --------------------- Helper Widgets ---------------------

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int? maxLines,
    bool expands = false,
    Function(String)? onChanged,
    bool outlined = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: outlined
            ? Border.all(color: kAppPrimary, width: 1.8)
            : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade100.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        expands: expands,
        maxLines: maxLines,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: kAppPrimary),
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
