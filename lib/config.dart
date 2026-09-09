import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void logApi(String message) {
  debugPrint('\x1B[32m$message\x1B[0m');
}

/// Backend connection for the Android app.
///
/// Flavor is selected at build time:
/// `--dart-define=FLUTTER_ENV=development|staging|production`
///
/// Values resolve in this order:
/// 1. `--dart-define=BASE_URL` / `--dart-define=API_KEY`
/// 2. `.env.<FLUTTER_ENV>` (see `.env.development`, `.env.staging`, `.env.production`)
/// 3. Flavor defaults below
class AppConfig {
  static const flutterEnv = String.fromEnvironment(
    'FLUTTER_ENV',
    defaultValue: 'development',
  );

  static const _defineBaseUrl = String.fromEnvironment('BASE_URL');
  static const _defineApiKey = String.fromEnvironment('API_KEY');

  static const _flavorBaseUrl = {
    'development': 'https://business-card-scanner-backend.app.knowerai.com',
    'staging': 'https://business-card-scanner-backend.app.knowerai.com',
    'production': 'https://business-card-scanner-backend.app.knowerai.com',
  };

  static const _flavorApiKey = {
    'development': 'R8CyDUgPwRla5C9CU93gnFDy4JewYw8bxFsa1zDk2_M',
    'staging': 'R8CyDUgPwRla5C9CU93gnFDy4JewYw8bxFsa1zDk2_M',
    'production': 'R8CyDUgPwRla5C9CU93gnFDy4JewYw8bxFsa1zDk2_M',
  };

  static String get envFileName => '.env.$flutterEnv';

  static Future<void> load() async {
    try {
      await dotenv.load(fileName: envFileName);
    } catch (_) {
      try {
        await dotenv.load(fileName: '.env');
      } catch (_) {
        dotenv.testLoad(fileInput: '');
      }
    }
    logApi('FLUTTER_ENV=$flutterEnv file=$envFileName');
    logApi('API base URL: $origin');
  }

  static String _read(String key) {
    try {
      return (dotenv.env[key] ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  static String get baseUrl {
    if (_defineBaseUrl.trim().isNotEmpty) return _defineBaseUrl.trim();
    final fromFile = _read('BASE_URL');
    if (fromFile.isNotEmpty) return fromFile;
    return (_flavorBaseUrl[flutterEnv] ?? _flavorBaseUrl['development']!).trim();
  }

  static String get apiKey {
    if (_defineApiKey.trim().isNotEmpty) return _defineApiKey.trim();
    final fromFile = _read('API_KEY');
    if (fromFile.isNotEmpty) return fromFile;
    return (_flavorApiKey[flutterEnv] ?? _flavorApiKey['development']!).trim();
  }

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
