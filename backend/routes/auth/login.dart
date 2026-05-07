// dart:convert no longer required; using Request.json()
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import '../../lib/db.dart';
import '../../lib/services/auth_service.dart';

Future<Response> onRequest(RequestContext context) async {
  try {
    final request = context.request;
    Map<String, dynamic> body;
    try {
      body = await request.json() as Map<String, dynamic>;
    } on FormatException catch (e) {
      return Response.json(
          statusCode: 400,
          body: {'error': 'Invalid JSON', 'details': e.message});
    }
    final email = body['email']?.toString();
    final password = body['password']?.toString();
    if (email == null || password == null) {
      return Response.json(
          statusCode: 400, body: {'error': 'email and password required'});
    }

    final conn = await createConnection();
    final auth = AuthService(conn);
    try {
      final result = await auth.login(email, password);
      await conn.close();
      return Response.json(body: result);
    } catch (e, st) {
      print('Login error: $e');
      print(st);
      await conn.close();
      final msg = e.toString();
      if (msg.contains('not verified')) {
        return Response.json(statusCode: 403, body: {'error': msg});
      }
      return Response.json(statusCode: 401, body: {'error': msg});
    }
  } catch (e, st) {
    print('Unhandled error in /auth/login: $e');
    print(st);
    // If DEV=true in environment or .env, include error details in response (development only)
    var dev = Platform.environment['DEV'];
    if (dev == null) {
      final envFile = File('.env');
      if (envFile.existsSync()) {
        final content = envFile.readAsStringSync();
        if (content.contains('\nDEV=true') || content.startsWith('DEV=true')) {
          dev = 'true';
        }
      }
    }
    if (dev == 'true') {
      return Response.json(statusCode: 500, body: {
        'error': 'Internal Server Error',
        'details': e.toString(),
        'stack': st.toString()
      });
    }
    return Response.json(
        statusCode: 500, body: {'error': 'Internal Server Error'});
  }
}
