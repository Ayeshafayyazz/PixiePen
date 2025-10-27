import 'package:flutter/material.dart';
import 'routes.dart';
import 'screens/theme.dart'; // 👈 import our theme file
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Ensure Firebase is initialized before the app runs.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PixiePen',
      theme: appTheme.copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Poppins'),
      ),
      initialRoute: AppRoutes.splash,
      routes: appRoutes,
    );
  }
}
