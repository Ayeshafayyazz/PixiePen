import 'package:flutter/material.dart';
import '../routes.dart';
import '../shared/utils/app_navigator.dart';
import '../shared/utils/responsive.dart';
import 'widgets/auth_card.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Responsive.size(context);
          final safePadding = MediaQuery.paddingOf(context);
          final availableHeight =
              constraints.maxHeight - safePadding.top - safePadding.bottom;
          final logoHeight = (availableHeight * 0.16).clamp(94.0, 132.0);
          final logoWidth = (size.width * 0.45).clamp(150.0, 190.0);
          final logoTop =
              safePadding.top + (availableHeight * 0.025).clamp(14.0, 26.0);
          final taglineTop = logoTop + logoHeight + 4;
          final cardGap = (availableHeight * 0.06).clamp(36.0, 62.0);
          final lowerSectionOffset =
              (availableHeight * 0.035).clamp(18.0, 32.0);
          final cardTop = taglineTop + 24 + cardGap + lowerSectionOffset;
          final loginCardHeight = (availableHeight * 0.39).clamp(300.0, 318.0);
          final purplePadding = (availableHeight * 0.05).clamp(36.0, 46.0);
          final purpleTop = cardTop - purplePadding;
          final signupGapFromPurple =
              (availableHeight * 0.04).clamp(30.0, 42.0);
          final desiredPurpleHeight = loginCardHeight + (purplePadding * 2);
          final maxPurpleHeight = size.height -
              safePadding.bottom -
              purpleTop -
              signupGapFromPurple -
              46;
          final purpleHeight = desiredPurpleHeight.clamp(
            280.0,
            maxPurpleHeight < 280 ? desiredPurpleHeight : maxPurpleHeight,
          );
          final signupTop = purpleTop + purpleHeight + signupGapFromPurple;

          return Stack(
            children: [
              Positioned(
                top: purpleTop,
                right: size.width * 0.42,
                child: Container(
                  width: size.width * 0.92,
                  height: purpleHeight,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF7B1FA2), Color(0xFF4A148C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(60),
                      bottomRight: Radius.circular(60),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: logoTop,
                left: 0,
                right: 0,
                child: Center(
                  child: Image.asset(
                    'assets/images/LOGOpIXIEPEN.png',
                    width: logoWidth,
                    height: logoHeight,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: taglineTop,
                left: 0,
                right: 0,
                child: const Center(
                  child: Text(
                    'Shift, Shine, Storytime',
                    style: TextStyle(color: Colors.black54, fontSize: 16),
                  ),
                ),
              ),
              Positioned(
                top: cardTop,
                left: 0,
                right: 0,
                child: const AuthCard(isLogin: true),
              ),
              Positioned(
                top: signupTop,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      AppNavigator.pushReplacementNamed(
                        context,
                        AppRoutes.signup,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: RichText(
                        text: const TextSpan(
                          text: "Don't Have An Account? ",
                          style: TextStyle(color: Colors.black),
                          children: [
                            TextSpan(
                              text: "SIGNUP",
                              style: TextStyle(
                                color: Colors.purple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
