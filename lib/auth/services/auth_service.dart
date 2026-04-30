import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Sign up with email and password
  Future<UserCredential?> signUp(
    String email,
    String password, {
    required String username,
    required String role,
    String? parentEmail,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(username);
        await _db.collection('users').doc(user.uid).set({
          'username': username,
          'email': email.trim().toLowerCase(),
          'role': role,
          'parentEmail': parentEmail?.trim().toLowerCase(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is not valid.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}
