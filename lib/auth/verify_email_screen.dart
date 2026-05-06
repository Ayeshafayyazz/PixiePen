import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../routes.dart';
import '../shared/utils/app_navigator.dart';
import '../shared/utils/message_helper.dart';
import 'services/auth_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final AuthService _authService = AuthService();
  bool _isChecking = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSkipIfAllowed());
  }

  Future<void> _autoSkipIfAllowed() async {
    final ok = await _authService.reloadAndCheckEffectiveVerified();
    if (!ok || !mounted) return;
    final role = await _authService.readRole(
      FirebaseAuth.instance.currentUser?.uid,
    );
    if (!mounted) return;
    AppNavigator.pushReplacementNamed(
      context,
      role == 'parent' ? AppRoutes.parentApprovals : AppRoutes.community,
    );
  }

  Future<void> _checkVerification() async {
    setState(() => _isChecking = true);

    try {
      final isVerified = await _authService.reloadAndCheckEffectiveVerified();
      if (!mounted) return;

      if (!isVerified) {
        MessageHelper.error(context, 'Email is not verified yet.');
        return;
      }

      final role = await _authService.readRole(
        FirebaseAuth.instance.currentUser?.uid,
      );
      if (!mounted) return;

      AppNavigator.pushReplacementNamed(
        context,
        role == 'parent' ? AppRoutes.parentApprovals : AppRoutes.community,
      );
    } catch (e) {
      if (!mounted) return;
      MessageHelper.error(context, e.toString());
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _resendEmail() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u != null &&
        await _authService.shouldSkipEmailVerificationGate(u)) {
      if (!mounted) return;
      MessageHelper.error(
        context,
        'No inbox is linked for this account. Tap below if you are verified.',
      );
      return;
    }

    setState(() => _isResending = true);

    try {
      await _authService.sendEmailVerification();
      if (!mounted) return;
      MessageHelper.success(context, 'Verification email sent again.');
    } catch (e) {
      if (!mounted) return;
      MessageHelper.error(context, e.toString());
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _useAnotherAccount() async {
    await _authService.signOut();
    if (!mounted) return;
    AppNavigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'your email';

    return Scaffold(
      backgroundColor: const Color(0xFFF8EDFF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7B1FA2).withValues(alpha: 0.2),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      color: Color(0xFF7B1FA2),
                      size: 62,
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Text(
                    'Check Your Email',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF4A148C),
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We sent a verification link to $email. Open the link, then come back to PixiePen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isChecking ? null : _checkVerification,
                      icon: _isChecking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.verified_outlined),
                      label: const Text('I Verified My Email'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B1FA2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _isResending ? null : _resendEmail,
                    icon: _isResending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Resend Email'),
                  ),
                  TextButton(
                    onPressed: _useAnotherAccount,
                    child: const Text('Use another account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
