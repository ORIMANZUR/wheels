import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Stream of user tokens
  Stream<int> getUserTokens(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return 0;
      return doc.data()?['tokens'] ?? 0;
    });
  }

  // Get user's rides
  Stream<Map<String, List<String>>> getUserRides(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return {'created': [], 'joined': []};
      final data = doc.data()?['rides'] as Map<String, dynamic>?;
      return {
        'created': List<String>.from(data?['created'] ?? []),
        'joined': List<String>.from(data?['joined'] ?? []),
      };
    });
  }

  // Sign in with email and password
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Update last login timestamp
      if (result.user != null) {
        await _firestore.collection('users').doc(result.user!.uid).update({
          'last_login': FieldValue.serverTimestamp(),
        });
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Sign in error: $e');
      throw _handleAuthException(e);
    }
  }

  // Register with email and password
  Future<bool> registerWithEmailAndPassword(
    String email,
    String password,
    String name,
  ) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (result.user != null) {
        // Create user profile in Firestore
        await _createUserProfile(result.user!.uid, name.trim(), email.trim());
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Registration error: $e');
      throw _handleAuthException(e);
    }
  }

  // Create user profile in Firestore
  Future<void> _createUserProfile(String uid, String name, String email) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'email': email,
        'created_at': FieldValue.serverTimestamp(),
        'last_login': FieldValue.serverTimestamp(),
        'profile_picture': null,
        'phone_number': null,
        'tokens': 1, // New user gets 1 token
        'rides_completed': 0,
        'rating': 5.0,
        'rides': {
          'created': [], // Rides created by the user
          'joined': [], // Rides joined by the user
        },
      });
    } catch (e) {
      debugPrint('Error creating user profile: $e');
      throw 'Failed to create user profile';
    }
  }

  // Update user tokens
  Future<void> updateUserTokens(String uid, int change) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'tokens': FieldValue.increment(change),
      });
    } catch (e) {
      debugPrint('Error updating tokens: $e');
      throw 'Failed to update tokens';
    }
  }

  // Add ride to user's rides
  Future<void> addUserRide(String uid, String rideId, bool isCreated) async {
    try {
      final field = isCreated ? 'created' : 'joined';
      await _firestore.collection('users').doc(uid).update({
        'rides.$field': FieldValue.arrayUnion([rideId]),
      });
    } catch (e) {
      debugPrint('Error adding ride: $e');
      throw 'Failed to add ride';
    }
  }

  // Remove ride from user's rides
  Future<void> removeUserRide(String uid, String rideId, bool isCreated) async {
    try {
      final field = isCreated ? 'created' : 'joined';
      await _firestore.collection('users').doc(uid).update({
        'rides.$field': FieldValue.arrayRemove([rideId]),
      });
    } catch (e) {
      debugPrint('Error removing ride: $e');
      throw 'Failed to remove ride';
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
      throw 'Failed to sign out';
    }
  }

  // Get user profile data
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      throw 'Failed to update profile';
    }
  }

  // Check if user has enough tokens
  Future<bool> hasEnoughTokens(String uid, int required) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final tokens = doc.data()?['tokens'] ?? 0;
      return tokens >= required;
    } catch (e) {
      debugPrint('Error checking tokens: $e');
      return false;
    }
  }

  // Update user photo
  Future<void> updateProfilePhoto(String uid, String photoUrl) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'profile_picture': photoUrl,
      });
    } catch (e) {
      debugPrint('Error updating profile photo: $e');
      throw 'Failed to update profile photo';
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      debugPrint('Password reset error: $e');
      throw _handleAuthException(e);
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Delete user data from Firestore
        await _firestore.collection('users').doc(user.uid).delete();
        // Delete user account
        await user.delete();
      }
    } catch (e) {
      debugPrint('Account deletion error: $e');
      throw 'Failed to delete account';
    }
  }

  // Check if email exists
  Future<bool> checkEmailExists(String email) async {
    try {
      final List<String> providers =
          await _auth.fetchSignInMethodsForEmail(email.trim());
      return providers.isNotEmpty;
    } catch (e) {
      debugPrint('Email check error: $e');
      return false;
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No user found with this email.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'email-already-in-use':
          return 'The email address is already in use.';
        case 'invalid-email':
          return 'The email address is invalid.';
        case 'weak-password':
          return 'The password is too weak.';
        case 'operation-not-allowed':
          return 'Email/password accounts are not enabled.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'user-disabled':
          return 'This account has been disabled.';
        default:
          return 'An error occurred. Please try again.';
      }
    }
    return e.toString();
  }
}
