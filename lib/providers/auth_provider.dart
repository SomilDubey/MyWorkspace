import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

final authProvider = Provider((ref) => FirebaseAuth.instance);

final authStateProvider = StreamProvider<User?>((ref) => ref.watch(authProvider).authStateChanges());

final authServiceProvider = Provider((ref) => AuthService(ref));

class AuthService {
  final Ref _ref;
  AuthService(this._ref);

  FirebaseAuth get _auth => _ref.read(authProvider);

  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      debugPrint('signInWithEmail failed: $e');
      rethrow;
    }
  }

  Future<UserCredential> signUpWithEmail(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      debugPrint('signUpWithEmail failed: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);

      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      debugPrint('signInWithGoogle failed: $e');
      rethrow;
    }
  }

  Future<void> signInWithPhone(
    String phoneNumber,
    void Function(String) codeSentCallback, {
    Future<void> Function()? verificationCompletedCallback,
  }) async {
    final result = Completer<void>();

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _auth.signInWithCredential(credential);
            if (verificationCompletedCallback != null) {
              await verificationCompletedCallback();
            }
            if (!result.isCompleted) result.complete();
          } catch (e, st) {
            if (!result.isCompleted) result.completeError(e, st);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!result.isCompleted) result.completeError(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          codeSentCallback(verificationId);
          if (!result.isCompleted) result.complete();
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
      await result.future;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      debugPrint('signInWithPhone failed: $e');
      rethrow;
    }
  }

  Future<UserCredential> verifyOTP(String verificationId, String smsCode) async {
    try {
      final credential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      debugPrint('verifyOTP failed: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (e) {
      debugPrint('Google signOut ignored: $e');
    }
    await _auth.signOut();
  }

  static String friendlyAuthError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'email-already-in-use':
          return 'This email is already registered. Try signing in instead.';
        case 'user-not-found':
          return 'No account found for this email.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'weak-password':
          return 'Password is too weak. Use at least 6 characters.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'operation-not-allowed':
          return 'This sign-in method isn’t enabled yet.';
        case 'network-request-failed':
          return 'Network error. Please check your connection and try again.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a bit and try again.';
        case 'invalid-phone-number':
          return 'Enter a valid phone number with the correct country code.';
        case 'invalid-verification-code':
          return 'The OTP is incorrect. Please check it and try again.';
        case 'session-expired':
          return 'This OTP has expired. Please request a new OTP.';
        default:
          final msg = error.message?.trim();
          return (msg == null || msg.isEmpty) ? 'Authentication failed. Please try again.' : msg;
      }
    }

    return 'Something went wrong. Please try again.';
  }
}
