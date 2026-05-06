import 'package:flutter/material.dart';

import '../../routes.dart';

class AppNavigator {
  static const Set<String> _allowedRoutes = {
    AppRoutes.splash,
    AppRoutes.onboarding,
    AppRoutes.login,
    AppRoutes.signup,
    AppRoutes.verifyEmail,
    AppRoutes.community,
    AppRoutes.ebook,
    AppRoutes.profile,
    AppRoutes.parentApprovals,
    AppRoutes.rewards,
    AppRoutes.myStories,
    AppRoutes.writeStory,
  };

  static Future<T?> pushNamed<T extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    _assertAllowed(routeName);
    return Navigator.pushNamed<T>(context, routeName, arguments: arguments);
  }

  static Future<T?> pushReplacementNamed<T extends Object?, TO extends Object?>(
    BuildContext context,
    String routeName, {
    TO? result,
    Object? arguments,
  }) {
    _assertAllowed(routeName);
    return Navigator.pushReplacementNamed<T, TO>(
      context,
      routeName,
      result: result,
      arguments: arguments,
    );
  }

  static Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
    BuildContext context,
    String newRouteName,
    RoutePredicate predicate, {
    Object? arguments,
  }) {
    _assertAllowed(newRouteName);
    return Navigator.pushNamedAndRemoveUntil<T>(
      context,
      newRouteName,
      predicate,
      arguments: arguments,
    );
  }

  static void _assertAllowed(String routeName) {
    assert(
      _allowedRoutes.contains(routeName),
      'Route must use AppRoutes constant: $routeName',
    );
  }
}
