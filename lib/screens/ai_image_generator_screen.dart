import 'package:flutter/material.dart';

import '../models/generated_story_image.dart';
import '../services/content_moderation_service.dart';
import '../services/story_image_generation_service.dart';
import '../widgets/moderation_ui.dart';
import '../widgets/storage_image.dart';

class AiImageGeneratorScreen extends StatefulWidget {
  final String? initialPrompt;
  const AiImageGeneratorScreen({super.key, this.initialPrompt});

  @override
  State<AiImageGeneratorScreen> createState() => _AiImageGeneratorScreenState();
}

class _AiImageGeneratorScreenState extends State<AiImageGeneratorScreen> {
  final TextEditingController _promptController = TextEditingController();
  final StoryImageGenerationService _imageGen = StoryImageGenerationService();
  final ContentModerationService _moderation = ContentModerationService();

  bool _isLoading = false;
  final List<GeneratedStoryImage> _generatedImages = [];

  @override
  void initState() {
    super.initState();
    // If user comes with story text, set it as prompt
    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      _promptController.text = widget.initialPrompt!;
      _generateImages(); // Auto-generate based on story description
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generateImages() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    final mod = _moderation.moderateWithSurface(
      ModerationSurface.aiPrompt,
      prompt,
    );
    if (!mod.isSafe) {
      if (!mounted) return;
      await ModerationUi.showBlockDialog(
        context,
        result: mod,
        surface: ModerationSurface.aiPrompt,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _generatedImages.clear();
    });

    try {
      final images = await _imageGen.generateImages(prompt, count: 4);
      if (!mounted) return;
      setState(() {
        _generatedImages.addAll(images);
        _isLoading = false;
      });
    } on ImageGenerationException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate images: $e')),
      );
    }
  }

  void _selectImageAsCover(GeneratedStoryImage image) {
    if (image.url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This image is not ready yet. Please try another.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(image);
  }

  Widget _buildGeneratedImage(GeneratedStoryImage image) {
    return StorageImage(
      url: image.url,
      bytes: image.bytes,
      fit: BoxFit.cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Image Generator 🎨"),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- Prompt TextField ---
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: themeColor, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _promptController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: "Image Prompt",
                    hintText: "Describe your story’s theme or scene...",
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _promptController.clear(),
                    ),
                  ),
                  onSubmitted: (_) => _generateImages(),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- Generate Button ---
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _generateImages,
              icon: const Icon(Icons.auto_awesome),
              label: const Text("Generate Images"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // --- Generated Images Grid ---
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: themeColor))
                  : _generatedImages.isEmpty
                  ? const Center(
                child: Text(
                  "Generated images will appear here.",
                  style: TextStyle(fontSize: 16),
                ),
              )
                  : GridView.builder(
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _generatedImages.length,
                itemBuilder: (context, index) {
                  final image = _generatedImages[index];
                  return InkWell(
                    onTap: () => _selectImageAsCover(image),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: themeColor, width: 1.5),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildGeneratedImage(image),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.all(6),
                              child: const Text(
                                "Select as Cover",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
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
      ),
    );
  }
}
