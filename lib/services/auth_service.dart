import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Register with email and password
  Future<UserCredential?> registerWithEmailAndPassword(
    String email,
    String password,
    String name,
  ) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await result.user?.updateDisplayName(name);

      // Create user document in Firestore
      try {
        await _firestore.collection('users').doc(result.user!.uid).set({
          'name': name,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        if (kIsWeb) {
          print('Warning: Could not create user document: $e');
        }
        // Continue even if Firestore write fails
      }

      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out with timeout and force
  Future<void> signOut() async {
    try {
      if (kIsWeb) {
        print('Attempting signout...');
      }

      // Set a timeout for signout
      await _auth.signOut().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          if (kIsWeb) {
            print('Signout timeout - forcing reload');
          }
          // Force page reload on web to clear auth state
          if (kIsWeb) {
            // This will be handled by the app
          }
        },
      );

      if (kIsWeb) {
        print('Signout successful');
      }
    } catch (e) {
      if (kIsWeb) {
        print('Signout error: $e');
      }
      // Even if signout fails, we'll reload the page to clear state
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Delete user data from Firestore
        try {
          await _firestore.collection('users').doc(user.uid).delete();
        } catch (e) {
          if (kIsWeb) {
            print('Warning: Could not delete user document: $e');
          }
        }

        // Delete user account
        await user.delete();
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password is too weak. Use at least 6 characters.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'operation-not-allowed':
        return 'Email/password sign in is not enabled.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  // Get user name
  Future<String?> getUserName() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        return doc.data()?['name'];
      } catch (e) {
        if (kIsWeb) {
          print('Could not fetch user name: $e');
        }
        return user.displayName;
      }
    }
    return null;
  }

  // Update user name
  Future<void> updateUserName(String name) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updateDisplayName(name);
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'name': name,
        });
      } catch (e) {
        if (kIsWeb) {
          print('Could not update user name in Firestore: $e');
        }
      }
    }
  }
}
