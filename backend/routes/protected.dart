import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../lib/db.dart';

Future<Response> onRequest(RequestContext context) async {
  try {
    final auth = context.request.headers['authorization'];
    if (auth == null || !auth.toLowerCase().startsWith('bearer ')) {
      return Response.json(
          statusCode: 401,
          body: {'error': 'Missing or invalid Authorization header'});
    }
    final token = auth.substring(7).trim();

    // Read JWT secret from environment or fallback to .env
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
    secret ??= 'secret';

    try {
      final jwt = JWT.verify(token, SecretKey(secret));
      // require that the user is verified in the database
      final payload = jwt.payload;
      final userId = payload['id'];
      if (userId == null) {
        return Response.json(
            statusCode: 401, body: {'error': 'Invalid token payload'});
      }
      final conn = await createConnection();
      try {
        final rows = await conn.query(
            'SELECT email_verified FROM public.users WHERE id = @id',
            substitutionValues: {'id': userId});
        if (rows.isEmpty) {
          return Response.json(
              statusCode: 404, body: {'error': 'User not found'});
        }
        final emailVerified = rows.first[0] as bool;
        if (!emailVerified) {
          return Response.json(
              statusCode: 403, body: {'error': 'Email not verified'});
        }
      } finally {
        await conn.close();
      }

      return Response.json(body: {
        'ok': true,
        'message': 'Protected content',
        'claims': jwt.payload
      });
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('expired')) {
        return Response.json(statusCode: 401, body: {'error': 'Token expired'});
      }
      return Response.json(statusCode: 401, body: {'error': 'Invalid token'});
    }
  } catch (e, st) {
    print('Error in /protected: $e');
    print(st);
    return Response.json(
        statusCode: 500, body: {'error': 'Internal Server Error'});
  }
}
