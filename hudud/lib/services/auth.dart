import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';

/// Who is signed in, as the app shows it.
class Account {
  const Account({required this.uid, this.name, this.email, this.phone, this.photoUrl, required this.via});

  final String uid;
  final String? name;
  final String? email;
  final String? phone;
  final String? photoUrl;

  /// 'google' or 'telegram'.
  final String via;

  String get label => name ?? email ?? phone ?? uid;
}

enum SignInError { cancelled, notConfigured, network, failed }

class SignInException implements Exception {
  const SignInException(this.error, [this.detail]);

  final SignInError error;
  final String? detail;

  @override
  String toString() => 'SignInException($error, $detail)';
}

/// Sign-in with Google (Firebase) or with a phone number confirmed by
/// Telegram. Both are free: Firebase Auth costs nothing for Google and
/// custom sign-ins, and Telegram's bot API is free.
///
/// Until Firebase is set up (google-services.json) everything still works
/// offline, as a guest.
class AuthService extends ChangeNotifier {
  AuthService(this._prefs);

  final SharedPreferences _prefs;
  bool _firebaseReady = false;
  StreamSubscription<User?>? _sub;
  Account? _account;

  /// Whether Firebase is configured in this build.
  bool get available => _firebaseReady;
  bool get telegramAvailable => _firebaseReady && Config.telegramReady;

  Account? get account => _account;
  bool get signedIn => _account != null;

  /// The player chose to try the app without an account.
  bool get guest => _prefs.getBool('guest') ?? false;

  /// Whether to show the sign-in screen at start.
  bool get needsSignIn => !signedIn && !guest;

  static Future<AuthService> start() async {
    final service = AuthService(await SharedPreferences.getInstance());
    await service._init();
    return service;
  }

  Future<void> _init() async {
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
      _sub = FirebaseAuth.instance.authStateChanges().listen(_onUser);
      _onUser(FirebaseAuth.instance.currentUser);
    } catch (e) {
      debugPrint('Hudud: Firebase is not set up yet ($e); running as guest.');
    }
  }

  void _onUser(User? user) {
    if (user == null) {
      _account = null;
    } else {
      final google = user.providerData.any((p) => p.providerId == 'google.com');
      _account = Account(
        uid: user.uid,
        name: user.displayName,
        email: user.email,
        phone: user.phoneNumber ?? _prefs.getString('phone_${user.uid}'),
        photoUrl: user.photoURL,
        via: google ? 'google' : 'telegram',
      );
    }
    notifyListeners();
  }

  Future<void> continueAsGuest() async {
    await _prefs.setBool('guest', true);
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    if (!_firebaseReady) throw const SignInException(SignInError.notConfigured);
    try {
      final google = GoogleSignIn.instance;
      await google.initialize();
      final user = await google.authenticate();
      final idToken = user.authentication.idToken;
      if (idToken == null) throw const SignInException(SignInError.failed, 'no id token');
      await FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
      await _prefs.setBool('guest', false);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw const SignInException(SignInError.cancelled);
      throw SignInException(SignInError.failed, e.description);
    } on FirebaseAuthException catch (e) {
      throw SignInException(
        e.code == 'network-request-failed' ? SignInError.network : SignInError.failed,
        e.message,
      );
    }
  }

  /// Opens the Telegram bot; it asks for the phone number with one tap and
  /// tells the app when it is confirmed. Completes once signed in.
  Future<void> signInWithTelegram({Duration timeout = const Duration(minutes: 5)}) async {
    if (!telegramAvailable) throw const SignInException(SignInError.notConfigured);
    final nonce = _nonce();
    final opened = await launchUrl(
      Uri.parse('https://t.me/${Config.telegramBot}?start=$nonce'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) throw const SignInException(SignInError.failed, 'Telegram did not open');
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final http.Response response;
      try {
        response = await http.get(Uri.parse('${Config.authServer}/auth/poll?nonce=$nonce'));
      } catch (_) {
        continue; // Offline for a moment; keep waiting.
      }
      if (response.statusCode != 200) continue;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      try {
        final result = await FirebaseAuth.instance.signInWithCustomToken(body['token'] as String);
        final user = result.user!;
        final name = body['name'] as String?;
        if (name != null && user.displayName == null) await user.updateDisplayName(name);
        await _prefs.setString('phone_${user.uid}', body['phone'] as String? ?? '');
        await _prefs.setBool('guest', false);
        await user.reload();
        _onUser(FirebaseAuth.instance.currentUser);
        return;
      } on FirebaseAuthException catch (e) {
        throw SignInException(SignInError.failed, e.message);
      }
    }
    throw const SignInException(SignInError.cancelled);
  }

  Future<void> signOut() async {
    if (!_firebaseReady) return;
    await FirebaseAuth.instance.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

  /// Deletes the account (a Play Store requirement). The runs on the phone
  /// stay; they were never uploaded.
  Future<void> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await user.delete();
    await signOut();
  }

  static String _nonce() {
    final rnd = Random.secure();
    return base64Url.encode(List<int>.generate(24, (_) => rnd.nextInt(256))).replaceAll('=', '');
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
