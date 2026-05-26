import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import '../../lib/db.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response.json(
      statusCode: 405,
      body: {'error': 'Method not allowed'},
    );
  }

  final email = context.request.uri.queryParameters['email']?.trim();
  if (email == null || email.isEmpty) {
    return Response.json(statusCode: 400, body: {'error': 'Missing email'});
  }

  final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  if (!emailRegex.hasMatch(email)) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'invalid email format'},
    );
  }

  final connection = await createConnection();
  try {
    final confirmed = await connection.query(
      'SELECT 1 FROM public.usuario WHERE correo = @correo LIMIT 1',
      substitutionValues: {'correo': email},
    );
    final pending = await connection.query(
      'SELECT 1 FROM public.pending_users WHERE email = @email LIMIT 1',
      substitutionValues: {'email': email},
    );

    final exists = confirmed.isNotEmpty || pending.isNotEmpty;
    if (exists) {
      return Response.json(
        statusCode: 409,
        body: {
          'exists': true,
          'available': false,
          'message': 'correo ya registrado',
        },
      );
    }

    return Response.json(
      statusCode: 200,
      body: {
        'exists': false,
        'available': true,
        'message': 'correo disponible',
      },
    );
  } catch (e, st) {
    final dev = _isDev();
    return Response.json(
      statusCode: 500,
      body: {
        'error': dev ? e.toString() : 'Internal server error',
        if (dev) 'stack': st.toString(),
      },
    );
  } finally {
    await connection.close();
  }
}

bool _isDev() {
  final env = Platform.environment['DEV'];
  if (env != null) return env.toLowerCase() == 'true';
  return false;
}
