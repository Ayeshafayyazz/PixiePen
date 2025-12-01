import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ListTile(
            title: Text("Notifications"),
            subtitle: Text("Manage push and email alerts"),
            trailing: Icon(Icons.notifications_outlined),
          ),
          const Divider(),
          const ListTile(
            title: Text("Privacy"),
            subtitle: Text("Manage who can see your stories"),
            trailing: Icon(Icons.privacy_tip_outlined),
          ),
          const Divider(),
          const ListTile(
            title: Text("Language"),
            subtitle: Text("Select app language"),
            trailing: Icon(Icons.language_outlined),
          ),
          const Divider(),
          const ListTile(
            title: Text("About PixiePen"),
            subtitle: Text("Version 1.0.0"),
            trailing: Icon(Icons.info_outline),
          ),
          const Divider(),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text("Back"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B1FA2),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
