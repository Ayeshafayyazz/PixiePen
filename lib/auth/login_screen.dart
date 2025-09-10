import 'package:flutter/material.dart';
import '../routes.dart';
import 'widgets/auth_card.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned(
            top: 240,
            right: 180,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: 490,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7B1FA2), Color(0xFF4A148C)],
                ),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(60),
                  bottomRight: Radius.circular(60),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 40),
                Image.asset(
                  'assets/images/LOGOpIXIEPEN.png',
                  width: 190,
                  height: 150,
                  fit: BoxFit.contain,
                ),
                const Text(
                  'Shift, Shine, Storytime',
                  style: TextStyle(color: Colors.black54, fontSize: 16),
                ),
                const SizedBox(height: 110),
                const AuthCard(isLogin: true),
                const SizedBox(height: 120),
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacementNamed(context, AppRoutes.signup);
                  },
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
