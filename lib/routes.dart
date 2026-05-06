import 'package:flutter/material.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'auth/login_screen.dart';
import 'auth/signup_screen.dart';
import 'auth/verify_email_screen.dart';
import 'screens/community.dart';
import 'screens/ebook_screen.dart';
import 'screens/parent_approvals_screen.dart';
import 'screens/pixie_dash_screen.dart';
import 'screens/profile_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String verifyEmail = '/verify-email';
  static const String community = '/community';
  static const String ebook = '/ebook';
  static const String profile = '/profile';
  static const String parentApprovals = '/parent-approvals';
  static const String pixieDash = '/pixie-dash';
  static const String rewards = '/rewards';
  static const String myStories = '/my-stories';
  static const String writeStory = '/write-story';
}

final Map<String, WidgetBuilder> appRoutes = {
  AppRoutes.splash: (_) => const SplashScreen(),
  AppRoutes.onboarding: (_) => const OnboardingScreen(),
  AppRoutes.login: (_) => const LoginScreen(),
  AppRoutes.signup: (_) => const SignUpScreen(),
  AppRoutes.verifyEmail: (_) => const VerifyEmailScreen(),
  // Extra routes
  AppRoutes.community: (_) => const CommunityScreen(),
  AppRoutes.ebook: (_) => const EbookScreen(),
  AppRoutes.profile: (_) => const ProfileScreen(),
  AppRoutes.parentApprovals: (_) => const ParentApprovalsScreen(),
  AppRoutes.pixieDash: (_) => const PixieDashScreen(),
};
