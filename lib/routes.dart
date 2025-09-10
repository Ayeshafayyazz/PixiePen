import 'package:flutter/material.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'auth/login_screen.dart';
import 'auth/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/community.dart';
import 'screens/ebook_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/reward_screen.dart';
import 'screens/write_story_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';

  // Extra app screens
  static const String community = '/community';
  static const String ebook = '/ebook';
  static const String profile = '/profile';
  static const String rewards = '/rewards';
  static const String myStories = '/my-stories';
  static const String writeStory = '/write-story';
}

final Map<String, WidgetBuilder> appRoutes = {
  AppRoutes.splash: (_) => const SplashScreen(),
  AppRoutes.onboarding: (_) => const OnboardingScreen(),
  AppRoutes.login: (_) => const LoginScreen(),
  AppRoutes.signup: (_) => const SignUpScreen(),
  // Extra routes
  AppRoutes.community: (_) => const CommunityScreen(),
  AppRoutes.ebook: (_) => const EbookScreen(),
  AppRoutes.profile: (_) => const ProfileScreen(),
  AppRoutes.rewards: (_) => const RewardScreen(),

};
