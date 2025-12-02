import 'package:flutter/material.dart';
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(
          10,
              (index) => Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.notification_important),
              title: Text('Notification ${index + 1}'),
              subtitle: const Text('This is the detail of the notification.'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Clicked Notification ${index + 1}')),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
