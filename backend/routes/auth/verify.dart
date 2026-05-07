import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import '../../lib/db.dart';

Future<Response> onRequest(RequestContext context) async {
  final request = context.request;
  if (request.method == HttpMethod.get) {
    return await _handle(request);
  }
  return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
}

Future<Response> _handle(Request request) async {
  final params = request.uri.queryParameters;
  final token = params['token'];
  if (token == null || token.isEmpty) {
    return Response.json(statusCode: 400, body: {'error': 'Missing token'});
  }

  final connection = await createConnection();
  try {
    final rows = await connection.query('''
      SELECT id, user_id, pending_user_id, used, expires_at
      FROM public.email_verification_tokens
      WHERE token = @token
    ''', substitutionValues: {'token': token});

    if (rows.isEmpty) {
      return Response.json(statusCode: 404, body: {'error': 'Token not found'});
    }

    final row = rows.first;
    final id = row[0] as int;
    final userId = row[1] as int?;
    final pendingUserId = row[2] as int?;
    final used = row[3] as bool;
    final expiresAt = row[4] as DateTime;

    if (used) {
      return Response.json(
          statusCode: 400, body: {'error': 'Token already used'});
    }
    if (DateTime.now().toUtc().isAfter(expiresAt)) {
      return Response.json(statusCode: 400, body: {'error': 'Token expired'});
    }

    if (pendingUserId != null) {
      // promote pending user to final users table
      final pendingRows = await connection.query(
          'SELECT email, password_hash, name FROM public.pending_users WHERE id = @id',
          substitutionValues: {'id': pendingUserId});
      if (pendingRows.isEmpty) {
        return Response.json(
            statusCode: 404, body: {'error': 'Pending user not found'});
      }
      final prow = pendingRows.first;
      final email = prow[0] as String;
      final passwordHash = prow[1] as String;
      final name = prow[2] as String?;

      try {
        final insert = await connection.query('''
          INSERT INTO public.users (email, password_hash, name, email_verified)
          VALUES (@email, @password_hash, @name, true)
          RETURNING id
        ''', substitutionValues: {
          'email': email,
          'password_hash': passwordHash,
          'name': name,
        });
        // mark token used
        await connection.query(
            'UPDATE public.email_verification_tokens SET used = true, used_at = NOW() WHERE id = @id',
            substitutionValues: {'id': id});
        // delete pending user record
        await connection.query(
            'DELETE FROM public.pending_users WHERE id = @id',
            substitutionValues: {'id': pendingUserId});
      } catch (e) {
        // If insert failed (e.g., unique constraint), try to mark existing user as verified
        try {
          await connection.query(
              'UPDATE public.users SET email_verified = true, updated_at = NOW() WHERE email = @email',
              substitutionValues: {'email': prow[0]});
          await connection.query(
              'UPDATE public.email_verification_tokens SET used = true, used_at = NOW() WHERE id = @id',
              substitutionValues: {'id': id});
          // delete pending user if exists
          await connection.query(
              'DELETE FROM public.pending_users WHERE id = @id',
              substitutionValues: {'id': pendingUserId});
        } catch (e2) {
          rethrow;
        }
      }
    } else if (userId != null) {
      // mark user as verified and token as used
      await connection.query(
          'UPDATE public.users SET email_verified = true, updated_at = NOW() WHERE id = @id',
          substitutionValues: {'id': userId});
      await connection.query(
          'UPDATE public.email_verification_tokens SET used = true, used_at = NOW() WHERE id = @id',
          substitutionValues: {'id': id});
    } else {
      return Response.json(
          statusCode: 400, body: {'error': 'Token not linked to any user'});
    }

    return Response.json(
        statusCode: 200, body: {'ok': true, 'message': 'Email verified'});
  } catch (e, st) {
    final dev = _isDev();
    return Response.json(statusCode: 500, body: {
      'error':
          dev ? e.toString() + '\n' + st.toString() : 'Internal server error'
    });
  } finally {
    await connection.close();
  }
}

bool _isDev() {
  final env = Platform.environment['DEV'];
  if (env != null) return env.toLowerCase() == 'true';
  return false;
}
