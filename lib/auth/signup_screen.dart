import 'package:flutter/material.dart';
import '../routes.dart';
import 'widgets/auth_card.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = MediaQuery.sizeOf(context);
          final safePadding = MediaQuery.paddingOf(context);
          final availableHeight =
              constraints.maxHeight - safePadding.top - safePadding.bottom;
          final logoHeight = (availableHeight * 0.16).clamp(92.0, 130.0);
          final logoWidth = (size.width * 0.45).clamp(150.0, 190.0);
          final topGap = (availableHeight * 0.035).clamp(18.0, 34.0);
          final taglineGap = (availableHeight * 0.025).clamp(12.0, 22.0);
          final accountGap = (availableHeight * 0.025).clamp(12.0, 24.0);
          final purpleTop = availableHeight * 0.35;
          final purpleHeight = (availableHeight * 0.48).clamp(350.0, 430.0);

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
                    ),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(70),
                      bottomLeft: Radius.circular(70),
                      bottomRight: Radius.circular(70),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: size.width,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: topGap),
                          Image.asset(
                            'assets/images/LOGOpIXIEPEN.png',
                            width: logoWidth,
                            height: logoHeight,
                            fit: BoxFit.contain,
                          ),
                          const Text(
                            'Shift, Shine, Storytime',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: taglineGap),
                          const AuthCard(isLogin: false),
                          SizedBox(height: accountGap),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushReplacementNamed(
                                context,
                                AppRoutes.login,
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
                                  text: "Already Have An Account?",
                                  style: TextStyle(color: Colors.black),
                                  children: [
                                    TextSpan(
                                      text: " LOGIN",
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
                          SizedBox(height: accountGap),
                        ],
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
