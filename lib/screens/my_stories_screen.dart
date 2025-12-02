import 'package:flutter/material.dart';
import 'theme.dart'; // ✅ make sure this file contains your kAppPrimary and appTheme

class MyStoriesScreen extends StatefulWidget {
  const MyStoriesScreen({super.key});

  @override
  State<MyStoriesScreen> createState() => _MyStoriesScreenState();
}

class _MyStoriesScreenState extends State<MyStoriesScreen>
    with SingleTickerProviderStateMixin {
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
    {
      'id': '4',
      'title': 'The Enchanted River',
      'excerpt': 'A river sparkled with colors that changed with every step…',
      'selected': false,
    },
  ];

  bool _selectionMode = false;

  void _toggleSelect(int index) {
    setState(() {
      _stories[index]['selected'] = !_stories[index]['selected'];
      _selectionMode = _stories.any((story) => story['selected']);
    });
  }

  void _convertToEbook() {
    final selected = _stories.where((s) => s['selected']).toList();
    if (selected.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "📚 Converting ${selected.length} stories into an eBook...",
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: kAppPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _stories.where((s) => s['selected']).length;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: kAppPrimary,
        centerTitle: true,
        title: const Text(
          "📖 My Stories",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _stories.length,
        itemBuilder: (context, index) {
          final story = _stories[index];
          final isSelected = story['selected'] as bool;

          return GestureDetector(
            onLongPress: () => _toggleSelect(index),
            onTap: () {
              if (_selectionMode) _toggleSelect(index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? kAppPrimary : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? kAppPrimary.withOpacity(0.25)
                        : Colors.black12,
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                title: Text(
                  story['title'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: kAppPrimary,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    story['excerpt'],
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("✏️ Editing ${story['title']}")),
                      );
                    } else if (value == 'delete') {
                      setState(() => _stories.removeAt(index));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("🗑️ Deleted ${story['title']}")),
                      );
                    } else if (value == 'post') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("🚀 Posted ${story['title']}")),
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
            ),
          );
        },
      ),
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: selectedCount > 0 ? 70 : 0,
        curve: Curves.easeInOut,
        child: selectedCount > 0
            ? Container(
          decoration: BoxDecoration(
            color: kAppPrimary,
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: kAppPrimary.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton.icon(
                onPressed: _convertToEbook,
                icon: const Icon(Icons.menu_book, color: Colors.white),
                label: Text(
                  "Convert $selectedCount Story${selectedCount > 1 ? 'ies' : ''} to eBook",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        )
            : const SizedBox.shrink(),
      ),
    );
  }
}
