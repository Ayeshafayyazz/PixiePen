import 'package:flutter/material.dart';
import 'routes.dart';
import 'screens/theme.dart'; // 👈 import our theme file

void main() => runApp(const MyApp());

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
