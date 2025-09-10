import 'package:flutter/material.dart';
import 'theme.dart'; // 👈 for kAppPrimary

class AiImageGeneratorScreen extends StatefulWidget {
  const AiImageGeneratorScreen({super.key});

  @override
  State<AiImageGeneratorScreen> createState() =>
      _AiImageGeneratorScreenState();
}

class _AiImageGeneratorScreenState extends State<AiImageGeneratorScreen> {
  final TextEditingController _promptController = TextEditingController();
  String? generatedImageUrl;

  void _simulateGeneration() {
    setState(() {
      generatedImageUrl =
      "https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/500/300";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kAppPrimary,
        title: const Text(
          "AI Image Generator",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _promptController,
              decoration: InputDecoration(
                labelText: "Enter story prompt",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: kAppPrimary.withOpacity(0.05),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _simulateGeneration,
              style: ElevatedButton.styleFrom(
                backgroundColor: kAppPrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              icon: const Icon(Icons.auto_awesome),
              label: const Text("Generate Image"),
            ),
            const SizedBox(height: 20),
            if (generatedImageUrl != null)
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    generatedImageUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
