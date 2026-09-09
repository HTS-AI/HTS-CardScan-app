import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/entities.dart';
import 'auth_service.dart';

class ScanResult {
  ScanResult({required this.entities, this.ocrText = ''});

  final ContactEntities entities;
  final String ocrText;
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ApiService {
  Future<ScanResult> scanImage(File image) async {
    final bytes = await image.readAsBytes();
    final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';

    if (!AppConfig.isReady) {
      throw ApiException(
        'App is not configured. Set BASE_URL and API_KEY in .env.${AppConfig.flutterEnv}.',
      );
    }
    final url = AppConfig.scanUrl;
    logApi('FLUTTER_ENV=${AppConfig.flutterEnv} API base URL: ${AppConfig.origin}');
    logApi('API request: POST $url');
    late http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              ...AuthService.instance.authHeaders,
            },
            body: jsonEncode({'image': dataUrl}),
          )
          .timeout(const Duration(seconds: 90));
    } on TimeoutException {
      logApi('API timeout: POST $url');
      throw ApiException('Scan timed out. Try again with a clearer photo.');
    } catch (e) {
      logApi('API error: POST $url → $e');
      if (e is ApiException) rethrow;
      throw ApiException('Cannot reach the server. Check your connection and try again.');
    }
    logApi('API response (${response.statusCode}): ${response.body}');

    Map<String, dynamic> body = {};
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}

    if (response.statusCode == 401) {
      final err = body['error']?.toString() ?? '';
      if (err == 'Sign in required.') {
        await AuthService.instance.logout();
        throw ApiException('Please sign in again.');
      }
      throw ApiException(
        err.isNotEmpty ? err : 'Request failed (401). Check the API key and URL.',
      );
    }

    if (response.statusCode != 200) {
      throw ApiException(
        body['error']?.toString() ?? 'Server error (${response.statusCode})',
      );
    }

    final entitiesJson = body['entities'];
    if (entitiesJson is! Map<String, dynamic>) {
      throw ApiException('Backend did not return contact fields.');
    }

    return ScanResult(
      entities: ContactEntities.fromJson(entitiesJson),
      ocrText: body['ocr_text']?.toString() ?? '',
    );
  }
}
