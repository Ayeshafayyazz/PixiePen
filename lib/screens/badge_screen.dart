import 'package:flutter/material.dart';

class BadgeScreen extends StatelessWidget {
  const BadgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final badges = [
      {"name": "Story Starter", "icon": Icons.star_border},
      {"name": "Creative Writer", "icon": Icons.create_outlined},
      {"name": "Top Reader", "icon": Icons.book_outlined},
      {"name": "Community Helper", "icon": Icons.favorite_border},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Badges"),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: badges.length,
        itemBuilder: (context, index) {
          final badge = badges[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: Icon(badge["icon"] as IconData, color: const Color(0xFF7B1FA2)),
              title: Text(badge["name"].toString()),
              trailing: const Icon(Icons.check_circle, color: Colors.green),
            ),
          );
        },
      ),
    );
  }
}
