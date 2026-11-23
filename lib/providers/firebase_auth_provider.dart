import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseAuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? _user;
  bool _isLoading = false;
  bool _isCheckingAuth = true;
  String? _errorMessage;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isCheckingAuth => _isCheckingAuth;
  bool get isAuthenticated => _user != null;
  String? get errorMessage => _errorMessage;

  FirebaseAuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() {
    _auth.authStateChanges().listen((user) async {
      _user = user;
      _isCheckingAuth = false;
      notifyListeners();
    });
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _setLoading(true);
      _clearError();

      debugPrint('Attempting sign in for: $email');

      // 1. Authenticate with Firebase Auth
      UserCredential credential;
      try {
        credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } catch (e) {
        // Special case for admindryclean@gmail.com: try to create if it doesn't exist
        // Note: On Web/DDC, codes often have 'auth/' prefix or appear differently in toString()
        bool isUserNotFound = false;
        if (e is FirebaseAuthException) {
          isUserNotFound = e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code.contains('user-not-found');
        } else {
          isUserNotFound = e.toString().contains('user-not-found') || e.toString().contains('invalid-credential');
        }

        if (email == 'admindryclean@gmail.com' && isUserNotFound) {
          debugPrint('Admin account not found or initial setup needed, attempting to create...');
          credential = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        } else {
          rethrow;
        }
      }

      final user = credential.user;
      if (user == null) return false;

      // 2. Check Admin Permissions in Firestore
      final adminDocRef = _firestore.collection('admin_users').doc(email);
      final adminDoc = await adminDocRef.get();

      if (!adminDoc.exists || adminDoc.data()?['isActive'] != true) {
        // If it's the special admin account, auto-create or update the record
        if (email == 'admindryclean@gmail.com') {
          debugPrint('Creating/Updating initial admin record in Firestore: $email');
          final existingData = adminDoc.data() as Map<String, dynamic>?;
          
          await adminDocRef.set({
            'email': email,
            'uid': user.uid,
            'isActive': true,
            'role': 'super_admin',
            'createdAt': existingData != null ? existingData['createdAt'] : FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          return true;
        } else {
          debugPrint('Access denied: $email is not an active admin');
          await _auth.signOut();
          _setError('Access denied. You do not have admin permissions.');
          return false;
        }
      }

      // 3. Update Last Login
      await adminDocRef.update({
        'lastLogin': FieldValue.serverTimestamp(),
        'uid': user.uid, // Ensure UID is always up to date
      });

      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_getAuthErrorMessage(e));
      return false;
    } catch (e) {
      debugPrint('Sign in error: $e');
      _setError('An unexpected error occurred. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      _setLoading(true);
      _clearError();
      
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      _setError(_getAuthErrorMessage(e));
    } catch (e) {
      _setError('Failed to send password reset email.');
    } finally {
      _setLoading(false);
    }
  }

  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found. Use admindryclean@gmail.com with any password (6+ chars) for first-time setup.';
      case 'wrong-password':
        return 'Incorrect password. If this is your first time, use admindryclean@gmail.com with a new password.';
      case 'invalid-email':
        return 'Please enter a valid email address (use admindryclean@gmail.com).';
      case 'user-disabled':
        return 'This admin account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'email-already-in-use':
        return 'This email is already registered. Try signing in instead.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'invalid-credential':
        return 'Incorrect email or password. For first-time setup, use admindryclean@gmail.com with any password (6+ chars).';
      default:
        return 'Authentication failed: ${e.message ?? e.code}';
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
