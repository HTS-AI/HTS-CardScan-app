import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

class AuthException implements Exception {
  AuthException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _tokenKey = 'auth_token';
  static const _emailKey = 'auth_email';
  static const _nameKey = 'auth_name';

  String? token;
  String? email;
  String? displayName;
  bool ready = false;

  bool get isSignedIn => (token ?? '').isNotEmpty;

  String get greetingName {
    final stored = (displayName ?? '').trim();
    if (stored.isNotEmpty) return stored.split(RegExp(r'\s+')).first;
    final local = (email ?? '').split('@').first.trim();
    if (local.isEmpty) return 'there';
    final cleaned = local.replaceAll(RegExp(r'[._\-+]+'), ' ').trim();
    final first = cleaned.split(RegExp(r'\s+')).first;
    if (first.isEmpty) return 'there';
    return first[0].toUpperCase() + first.substring(1).toLowerCase();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_tokenKey);
    email = prefs.getString(_emailKey);
    displayName = prefs.getString(_nameKey);
    ready = true;
    notifyListeners();
    if (isSignedIn) {
      unawaited(refreshProfile());
    }
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if ((token ?? '').isEmpty) {
      await prefs.remove(_tokenKey);
      await prefs.remove(_emailKey);
      await prefs.remove(_nameKey);
      return;
    }
    await prefs.setString(_tokenKey, token!);
    await prefs.setString(_emailKey, email ?? '');
    if ((displayName ?? '').isNotEmpty) {
      await prefs.setString(_nameKey, displayName!);
    }
  }

  Future<void> _persist(String? newToken, String newEmail, {String? name}) async {
    final tokenValue = (newToken ?? '').trim();
    if (tokenValue.isEmpty || tokenValue == 'null') {
      throw AuthException('Sign-in failed. Try again.');
    }
    token = tokenValue;
    email = newEmail;
    final trimmedName = (name ?? '').trim();
    if (trimmedName.isNotEmpty && trimmedName != 'null') {
      displayName = trimmedName;
    }
    await _savePrefs();
    notifyListeners();
  }

  Future<void> logout() async {
    token = null;
    email = null;
    displayName = null;
    await _savePrefs();
    notifyListeners();
  }

  Map<String, String> get authHeaders => {
        ...AppConfig.headers,
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> _send(
    String url,
    Map<String, dynamic>? body, {
    bool auth = false,
    String method = 'POST',
  }) async {
    if (!AppConfig.isReady) {
      throw AuthException(
        'App is not configured. Set BASE_URL and API_KEY in mobile/.env.',
      );
    }
    late http.Response response;
    try {
      final headers = {
        'Content-Type': 'application/json',
        ...(auth ? authHeaders : AppConfig.headers),
      };
      final uri = Uri.parse(url);
      if (method == 'GET') {
        response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));
      } else {
        response = await http
            .post(uri, headers: headers, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 30));
      }
    } on TimeoutException {
      throw AuthException('Request timed out. Try again.');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Cannot reach the server. Check the API URL and try again.');
    }

    Map<String, dynamic> decoded = {};
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}

    if (response.statusCode == 401 && auth) {
      final err = decoded['error']?.toString() ?? '';
      if (err == 'Sign in required.') {
        await logout();
        throw AuthException('Please sign in again.', statusCode: 401);
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        decoded['error']?.toString() ?? 'Request failed (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  Future<Map<String, dynamic>> _post(String url, Map<String, dynamic> body) {
    return _send(url, body);
  }

  Future<void> signup(String userEmail) async {
    await _post(AppConfig.signupUrl, {'email': userEmail.trim()});
  }

  Future<String?> verifyEmailCode(String userEmail, String code) async {
    final body = await _post(AppConfig.verifyUrl, {
      'email': userEmail.trim(),
      'code': code.trim(),
    });
    final signupToken = body['signup_token']?.toString().trim() ?? '';
    if (signupToken.isNotEmpty && signupToken != 'null') {
      return signupToken;
    }
    if (body['needs_password'] == true) {
      throw AuthException('Verification succeeded, but we could not continue. Try again.');
    }
    await _persist(
      body['token']?.toString(),
      body['email']?.toString() ?? userEmail.trim(),
      name: body['name']?.toString(),
    );
    return null;
  }

  Future<void> completeSignup(String userEmail, String signupToken, String password) async {
    final body = await _post(AppConfig.completeSignupUrl, {
      'email': userEmail.trim(),
      'signup_token': signupToken,
      'password': password,
    });
    await _persist(
      body['token']?.toString(),
      body['email']?.toString() ?? userEmail.trim(),
      name: body['name']?.toString(),
    );
  }

  Future<void> login(String userEmail, String password) async {
    final body = await _post(AppConfig.loginUrl, {
      'email': userEmail.trim(),
      'password': password,
    });
    await _persist(
      body['token']?.toString(),
      body['email']?.toString() ?? userEmail.trim(),
      name: body['name']?.toString(),
    );
  }

  Future<void> verify(String userEmail, String code) async {
    await verifyEmailCode(userEmail, code);
  }

  Future<void> forgot(String userEmail) async {
    await _post(AppConfig.forgotUrl, {'email': userEmail.trim()});
  }

  Future<void> reset(String userEmail, String code, String password) async {
    final body = await _post(AppConfig.resetUrl, {
      'email': userEmail.trim(),
      'code': code.trim(),
      'password': password,
    });
    try {
      await _persist(
        body['token']?.toString(),
        body['email']?.toString() ?? userEmail.trim(),
        name: body['name']?.toString(),
      );
    } on AuthException {
      throw AuthException('Password updated. Sign in with your new password.');
    }
  }

  Future<void> resend(String userEmail, String purpose) async {
    await _post(AppConfig.resendUrl, {
      'email': userEmail.trim(),
      'purpose': purpose,
    });
  }

  Future<void> refreshProfile() async {
    if (!isSignedIn) return;
    try {
      final body = await _send(AppConfig.meUrl, null, auth: true, method: 'GET');
      email = body['email']?.toString() ?? email;
      final name = body['name']?.toString().trim() ?? '';
      if (name.isNotEmpty) displayName = name;
      await _savePrefs();
      notifyListeners();
    } on AuthException {
      // Expired sessions are already cleared inside _send. Do not rethrow —
      // this runs in the background at startup.
    }
  }

  Future<void> updateName(String name) async {
    final body = await _send(AppConfig.profileUrl, {'name': name.trim()}, auth: true);
    displayName = body['name']?.toString() ?? name.trim();
    await _savePrefs();
    notifyListeners();
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _send(
      AppConfig.changePasswordUrl,
      {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
      auth: true,
    );
  }
}
