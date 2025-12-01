import 'package:flutter/material.dart';

class AiImageGeneratorScreen extends StatefulWidget {
  final String? initialPrompt;
  const AiImageGeneratorScreen({super.key, this.initialPrompt});

  @override
  State<AiImageGeneratorScreen> createState() => _AiImageGeneratorScreenState();
}

class _AiImageGeneratorScreenState extends State<AiImageGeneratorScreen> {
  final TextEditingController _promptController = TextEditingController();
  bool _isLoading = false;
  final List<String> _generatedImageUrls = [];

  @override
  void initState() {
    super.initState();
    // If user comes with story text, set it as prompt
    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      _promptController.text = widget.initialPrompt!;
      _generateImages(); // Auto-generate based on story description
    }
  }

  Future<void> _generateImages() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isLoading = true;
      _generatedImageUrls.clear();
    });

    // Simulate AI generation delay
    await Future.delayed(const Duration(seconds: 2));

    // Generate placeholder images based on prompt hash
    setState(() {
      _generatedImageUrls.addAll([
        'https://picsum.photos/seed/${prompt.hashCode + 1}/512',
        'https://picsum.photos/seed/${prompt.hashCode + 2}/512',
        'https://picsum.photos/seed/${prompt.hashCode + 3}/512',
        'https://picsum.photos/seed/${prompt.hashCode + 4}/512',
      ]);
      _isLoading = false;
    });
  }

  void _selectImageAsCover(String imageUrl) {
    Navigator.of(context).pop(imageUrl);
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
                  : _generatedImageUrls.isEmpty
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
                itemCount: _generatedImageUrls.length,
                itemBuilder: (context, index) {
                  final imageUrl = _generatedImageUrls[index];
                  return InkWell(
                    onTap: () => _selectImageAsCover(imageUrl),
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
                          Image.network(imageUrl, fit: BoxFit.cover),
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
