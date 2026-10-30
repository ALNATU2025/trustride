import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Phone-number sign-in with SMS codes (Firebase Authentication).
class AuthService {
  static final _auth = FirebaseAuth.instance;

  static String? _verificationId;
  static int? _resendToken;
  static ConfirmationResult? _webConfirmation;

  static User? get user => _auth.currentUser;
  static Stream<User?> changes() => _auth.authStateChanges();

  /// +232 and 8 digits, e.g. +23276123456.
  static String normalise(String local) {
    var digits = local.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('232')) digits = digits.substring(3);
    if (digits.startsWith('0')) digits = digits.substring(1);
    return '+232$digits';
  }

  /// Sends the SMS code. Completes when the code is sent, or when Android
  /// verifies the number automatically (then [user] is already set).
  static Future<void> sendCode(String phoneE164) async {
    if (kIsWeb) {
      _webConfirmation = await _auth.signInWithPhoneNumber(phoneE164);
      return;
    }
    final done = Completer<void>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      forceResendingToken: _resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        try {
          await _auth.signInWithCredential(credential);
        } catch (_) {}
        if (!done.isCompleted) done.complete();
      },
      verificationFailed: (e) {
        if (!done.isCompleted) done.completeError(friendlyError(e));
      },
      codeSent: (id, token) {
        _verificationId = id;
        _resendToken = token;
        if (!done.isCompleted) done.complete();
      },
      codeAutoRetrievalTimeout: (id) => _verificationId = id,
    );
    return done.future;
  }

  static Future<void> verifyCode(String code) async {
    if (_auth.currentUser != null) return; // auto-verified on Android
    if (kIsWeb) {
      if (_webConfirmation == null) throw 'Please request a new code.';
      await _webConfirmation!.confirm(code);
      return;
    }
    if (_verificationId == null) throw 'Please request a new code.';
    try {
      await _auth.signInWithCredential(PhoneAuthProvider.credential(
          verificationId: _verificationId!, smsCode: code));
    } on FirebaseAuthException catch (e) {
      throw friendlyError(e);
    }
  }

  static Future<void> signOut() => _auth.signOut();

  static String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-phone-number':
          return 'That phone number is not valid.';
        case 'invalid-verification-code':
          return 'That code is not right. Check the SMS and try again.';
        case 'session-expired':
        case 'code-expired':
          return 'The code expired. Request a new one.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a few minutes.';
        case 'network-request-failed':
          return 'No internet connection.';
        default:
          return e.message ?? 'Sign-in failed (${e.code}).';
      }
    }
    return e.toString().replaceFirst('Exception: ', '');
  }
}
