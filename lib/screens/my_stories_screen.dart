import 'package:flutter/material.dart';

class MyStoriesScreen extends StatefulWidget {
  const MyStoriesScreen({super.key});

  @override
  State<MyStoriesScreen> createState() => _MyStoriesScreenState();
}

class _MyStoriesScreenState extends State<MyStoriesScreen> {
  final List<Map<String, dynamic>> _stories = [
    {
      'id': '1',
      'title': 'The Magical Forest',
      'excerpt': 'Once upon a time, in a forest full of glowing trees…',
      'selected': false,
    },
    {
      'id': '2',
      'title': 'Adventures of Pixie',
      'excerpt': 'Pixie woke up to find her pen glowing with magic…',
      'selected': false,
    },
    {
      'id': '3',
      'title': 'The Hidden Castle',
      'excerpt': 'Behind the mountains, a castle shimmered under the moonlight…',
      'selected': false,
    },
  ];

  void _toggleSelect(int index) {
    setState(() {
      _stories[index]['selected'] = !_stories[index]['selected'];
    });
  }

  void _convertToEbook() {
    final selected = _stories.where((s) => s['selected']).toList();
    if (selected.isEmpty) return;

    // TODO: send selected stories to EbookScreen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Converting ${selected.length} stories into eBook...")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _stories.where((s) => s['selected']).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.purple,
        title: const Text("My Stories", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _stories.length,
        itemBuilder: (context, index) {
          final story = _stories[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 3,
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: Checkbox(
                value: story['selected'],
                activeColor: Colors.purple,
                onChanged: (_) => _toggleSelect(index),
              ),
              title: Text(
                story['title'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              subtitle: Text(
                story['excerpt'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Edit ${story['title']}")),
                    );
                  } else if (value == 'delete') {
                    setState(() => _stories.removeAt(index));
                  } else if (value == 'post') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Posted ${story['title']}")),
                    );
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text("Edit")),
                  PopupMenuItem(value: 'delete', child: Text("Delete")),
                  PopupMenuItem(value: 'post', child: Text("Post")),
                ],
              ),
            ),
          );
        },
      ),

      // ✅ Only show button when stories are selected
      floatingActionButton: selectedCount > 0
          ? FloatingActionButton.extended(
        backgroundColor: Colors.purple,
        onPressed: _convertToEbook,
        icon: const Icon(Icons.menu_book, color: Colors.white),
        label: Text("Convert ($selectedCount)"),
      )
          : null,
    );
  }
}
