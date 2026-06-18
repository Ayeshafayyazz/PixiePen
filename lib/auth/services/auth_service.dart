import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Lowercase [a-z0-9_], max 20 chars — stable identity with parent email for Auth login.
  static String normalizeChildUsername(String raw) {
    final s = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    return s.length > 20 ? s.substring(0, 20) : s;
  }

  /// Deterministic Firebase Auth email (unique per parent + username). Not a real inbox.
  static String childSyntheticAuthEmail(String parentEmail, String username) {
    final p = parentEmail.trim().toLowerCase();
    final u = normalizeChildUsername(username);
    final digest = sha256.convert(utf8.encode('$p|$u')).toString();
    return '$digest@pixiepen-child.invalid';
  }

  /// Sign up with email and password
  Future<UserCredential> signUp(
    String email,
    String password, {
    required String username,
    required String role,
    String? parentEmail,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw 'Unable to create account. Please try again.';
      }

      await user.updateDisplayName(username.trim());
      await _db.collection('users').doc(user.uid).set({
        'username': username.trim(),
        'email': email.trim().toLowerCase(),
        'role': role,
        'parentEmail': parentEmail?.trim().toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await sendEmailVerification(user);

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Child has no own email: Auth uses a synthetic address; [users] stores parent email for contact / linking.
  Future<UserCredential> signUpChildNoOwnEmail({
    required String parentEmail,
    required String username,
    required String password,
  }) async {
    final pe = parentEmail.trim().toLowerCase();
    final u = normalizeChildUsername(username);
    if (u.length < 3) {
      throw 'Username must be at least 3 letters or numbers.';
    }
    final synthetic = childSyntheticAuthEmail(pe, u);
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: synthetic,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw 'Unable to create account. Please try again.';
      }
      await user.updateDisplayName(u);
      await _db.collection('users').doc(user.uid).set({
        'username': u,
        'email': '',
        'parentEmail': pe,
        'role': 'child',
        'childLoginWithoutOwnEmail': true,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<UserCredential> signInChildNoOwnEmail({
    required String parentEmail,
    required String username,
    required String password,
  }) {
    final synthetic = childSyntheticAuthEmail(parentEmail, username);
    return signIn(synthetic, password);
  }

  Future<bool> shouldSkipEmailVerificationGate(User? user) async {
    if (user == null) return false;
    final doc = await _db.collection('users').doc(user.uid).get();
    return doc.data()?['childLoginWithoutOwnEmail'] == true;
  }

  /// True if the user may use the app: verified email, or no-email child account.
  Future<bool> canProceedPastEmailVerification(User? user) async {
    if (user == null) return false;
    if (user.emailVerified) return true;
    return shouldSkipEmailVerificationGate(user);
  }

  // Sign in with email and password
  Future<UserCredential> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> sendEmailVerification([User? user]) async {
    final currentUser = user ?? _auth.currentUser;
    if (currentUser == null || currentUser.emailVerified) return;
    if (await shouldSkipEmailVerificationGate(currentUser)) return;

    try {
      await currentUser.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<bool> reloadAndCheckEmailVerified() async {
    try {
      await _auth.currentUser?.reload();
      return _auth.currentUser?.emailVerified ?? false;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Use for navigation after sign-in / splash: includes no-email child accounts.
  Future<bool> reloadAndCheckEffectiveVerified() async {
    try {
      await _auth.currentUser?.reload();
      final u = _auth.currentUser;
      if (u == null) return false;
      if (u.emailVerified) return true;
      return shouldSkipEmailVerificationGate(u);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<String> readRole(String? uid) async {
    if (uid == null) return 'child';
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['role'] == 'parent' ? 'parent' : 'child';
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Shown when email/password don’t match (includes Firebase `invalid-credential`).
  static const String wrongEmailOrPassword =
      'Wrong email or password. Please try again.';

  /// Shown after sign-in when the inbox was never verified.
  static const String emailNotVerifiedYet =
      'Please verify your email first — check your inbox for the PixiePen link.';

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'email-already-in-use':
        return 'That email is already in use. Try signing in instead.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return wrongEmailOrPassword;
      case 'invalid-email':
        return 'That email doesn’t look valid.';
      case 'too-many-requests':
        return 'Too many tries. Wait a minute and try again.';
      case 'operation-not-allowed':
        return 'Sign-in isn’t available right now. Try again later.';
      case 'network-request-failed':
        return 'Check your internet connection and try again.';
      case 'user-disabled':
        return 'This account can’t sign in. Ask support if you need help.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  static bool isValidEmailFormat(String value) {
    final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$');
    return emailRegex.hasMatch(value.trim());
  }

  /// Returns:
  /// - true: domain resolves for email delivery checks
  /// - false: domain appears invalid/non-existent
  /// - null: could not verify (network/offline/server issue)
  static Future<bool?> hasResolvableEmailDomain(String email) async {
    final normalized = email.trim().toLowerCase();
    if (!isValidEmailFormat(normalized)) return false;

    final atIndex = normalized.lastIndexOf('@');
    if (atIndex <= 0 || atIndex == normalized.length - 1) return false;
    final domain = normalized.substring(atIndex + 1);
    if (domain.startsWith('.') ||
        domain.endsWith('.') ||
        domain.contains('..')) {
      return false;
    }

    final mx = await _queryDnsHasAnswer(domain: domain, type: 'MX');
    if (mx == true) return true;
    if (mx == null) return null;

    final a = await _queryDnsHasAnswer(domain: domain, type: 'A');
    if (a == true) return true;
    if (a == null) return null;

    return false;
  }

  static Future<bool?> _queryDnsHasAnswer({
    required String domain,
    required String type,
  }) async {
    try {
      final uri = Uri.https('dns.google', '/resolve', {
        'name': domain,
        'type': type,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return null;

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) return null;

      final status = payload['Status'];
      if (status is int && status == 3) return false; // NXDOMAIN
      if (status is int && status != 0) return null;

      final answer = payload['Answer'];
      if (answer is List) return answer.isNotEmpty;
      return false;
    } catch (_) {
      return null;
    }
  }
}
