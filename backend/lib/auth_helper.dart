import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// Helper class to deal with JWT auth in Dart Frog routes.
class AuthHelper {
  static String? _jwtSecret;

  static String getJwtSecret() {
    if (_jwtSecret != null) return _jwtSecret!;

    String? secret = Platform.environment['JWT_SECRET'];
    if (secret == null) {
      final envFile = File('.env');
      if (envFile.existsSync()) {
        final lines = envFile.readAsLinesSync();
        for (final raw in lines) {
          final line = raw.trim();
          if (line.isEmpty || line.startsWith('#')) continue;
          final idx = line.indexOf('=');
          if (idx <= 0) continue;
          final key = line.substring(0, idx).trim();
          var value = line.substring(idx + 1).trim();
          if ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'"))) {
            value = value.substring(1, value.length - 1);
          }
          if (key == 'JWT_SECRET') {
            secret = value;
            break;
          }
        }
      }
    }
    _jwtSecret = secret ?? 'secret';
    return _jwtSecret!;
  }

  /// Verifies token and returns the payload if valid.
  /// Returns null if token is missing or invalid.
  static Map<String, dynamic>? verifyToken(RequestContext context) {
    try {
      final auth = context.request.headers['authorization'];
      if (auth == null || !auth.toLowerCase().startsWith('bearer ')) {
        return null;
      }
      final token = auth.substring(7).trim();
      final secret = getJwtSecret();
      final jwt = JWT.verify(token, SecretKey(secret));
      return jwt.payload as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Checks if the payload belongs to an administrator.
  static bool isAdmin(Map<String, dynamic>? payload) {
    if (payload == null) return false;
    return payload['rol'] == 'administrador';
  }

  /// Extracts userId from the payload.
  static dynamic getUserId(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    return payload['id'];
  }
}
