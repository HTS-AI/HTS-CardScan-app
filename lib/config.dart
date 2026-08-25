import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Backend connection for the Android app.
///
/// Values come from `mobile/.env` (copy `mobile/.env.example`):
/// - BASE_URL — API origin only, no `/scan`
/// - API_KEY  — same as `API_KEY` in the server `.env`
///
/// Do not load the repo-root `.env` into Flutter. That file has SMTP and LLM
/// keys and must not be bundled into the APK.
class AppConfig {
  static String _read(String key) {
    try {
      return (dotenv.env[key] ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  static String get baseUrl => _read('BASE_URL');
  static String get apiKey => _read('API_KEY');

  static String get origin {
    var raw = baseUrl.trim();
    if (raw.isEmpty) return '';
    raw = raw.replaceAll(RegExp(r'/+$'), '');
    final lower = raw.toLowerCase();
    if (lower.endsWith('/scan')) {
      raw = raw.substring(0, raw.length - 5).replaceAll(RegExp(r'/+$'), '');
    }
    if (!raw.contains('://')) {
      final host = raw.split('/').first.split(':').first;
      final local = host == 'localhost' ||
          host == '10.0.2.2' ||
          RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host);
      raw = '${local ? 'http' : 'https'}://$raw';
    }
    return raw;
  }

  static String get trimmedApiKey => apiKey.trim();

  static bool get isReady {
    final uri = Uri.tryParse(origin);
    return uri != null &&
        uri.hasScheme &&
        uri.host.isNotEmpty &&
        trimmedApiKey.isNotEmpty;
  }

  static const String scanPath = '/scan';
  static const String healthPath = '/health';

  static String get scanUrl => '$origin$scanPath';
  static String get healthUrl => '$origin$healthPath';
  static String get signupUrl => '$origin/auth/signup';
  static String get loginUrl => '$origin/auth/login';
  static String get verifyUrl => '$origin/auth/verify';
  static String get forgotUrl => '$origin/auth/forgot';
  static String get resetUrl => '$origin/auth/reset';
  static String get resendUrl => '$origin/auth/resend';
  static String get completeSignupUrl => '$origin/auth/complete-signup';
  static String get meUrl => '$origin/auth/me';
  static String get profileUrl => '$origin/auth/profile';
  static String get changePasswordUrl => '$origin/auth/change-password';

  static Map<String, String> get headers => {
        if (origin.contains('ngrok')) 'ngrok-skip-browser-warning': 'true',
        if (trimmedApiKey.isNotEmpty) 'X-API-Key': trimmedApiKey,
      };
}
