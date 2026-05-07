import 'package:dart_frog/dart_frog.dart';
import 'dart:math';
import 'dart:convert';

import '../../lib/db.dart';
import '../../lib/services/auth_service.dart';

// We'll persist resend attempts in the DB (table: email_verification_resends)
// and enforce a limit of 3 attempts per 5-minute window.
const int _maxResends = 3;
final Duration _resendWindow = Duration(minutes: 5);

Future<Response> onRequest(RequestContext context) async {
  final request = context.request;
  if (request.method != HttpMethod.post) {
    return Response.json(
        statusCode: 405, body: {'error': 'Method not allowed'});
  }

  try {
    Map<String, dynamic> body;
    try {
      body = await request.json() as Map<String, dynamic>;
    } on FormatException catch (e) {
      return Response.json(
          statusCode: 400,
          body: {'error': 'Invalid JSON', 'details': e.message});
    }
    final email = body['email']?.toString();
    if (email == null || email.isEmpty) {
      return Response.json(statusCode: 400, body: {'error': 'email required'});
    }

    final conn = await createConnection();
    final auth = AuthService(conn);
    try {
      // Privacy: don't reveal whether the email exists
      final rows = await conn.query(
          'SELECT id, email_verified FROM public.users WHERE email = @email',
          substitutionValues: {'email': email});

      int? userId;
      int? pendingId;
      bool emailVerified = false;

      if (rows.isEmpty) {
        // try pending_users
        final pend = await conn.query(
            'SELECT id FROM public.pending_users WHERE email = @email',
            substitutionValues: {'email': email});
        if (pend.isEmpty) {
          await conn.close();
          return Response.json(body: {
            'message':
                'If the email exists, a verification email has been sent.'
          });
        }
        pendingId = pend.first[0] as int;
      } else {
        final row = rows.first;
        userId = row[0] as int;
        emailVerified = row[1] as bool;
        if (emailVerified) {
          await conn.close();
          return Response.json(body: {'message': 'Email already verified.'});
        }
      }

      // Count attempts in window
      final countRes = await conn.query(
        "SELECT COUNT(*) FROM public.email_verification_resends WHERE email = @email AND created_at > (NOW() - INTERVAL '${_resendWindow.inMinutes} minutes')",
        substitutionValues: {'email': email},
      );
      final attempts = (countRes.first[0] as int);
      if (attempts >= _maxResends) {
        await conn.close();
        return Response.json(statusCode: 429, body: {
          'error': 'Too many requests',
          'retry_after_seconds': _resendWindow.inSeconds
        });
      }

      // generate new token and insert (for user or pending_user)
      final token = _generateToken();
      final expiresAt = DateTime.now().toUtc().add(const Duration(hours: 24));
      if (pendingId != null) {
        await conn.query('''
          INSERT INTO public.email_verification_tokens (pending_user_id, token, expires_at)
          VALUES (@pending_user_id, @token, @expires_at)
        ''', substitutionValues: {
          'pending_user_id': pendingId,
          'token': token,
          'expires_at': expiresAt.toIso8601String(),
        });
      } else {
        await conn.query('''
          INSERT INTO public.email_verification_tokens (user_id, token, expires_at)
          VALUES (@user_id, @token, @expires_at)
        ''', substitutionValues: {
          'user_id': userId,
          'token': token,
          'expires_at': expiresAt.toIso8601String(),
        });
      }

      // record resend attempt
      await conn.query(
          'INSERT INTO public.email_verification_resends (email) VALUES (@email)',
          substitutionValues: {'email': email});

      // send email
      await auth.sendVerificationEmail(email, token);
      await conn.close();
      return Response.json(body: {
        'message': 'If the email exists, a verification email has been sent.'
      });
    } catch (e, st) {
      print('Resend verification error: $e');
      print(st);
      await conn.close();
      return Response.json(
          statusCode: 500, body: {'error': 'Internal server error'});
    }
  } catch (e, st) {
    print('Unhandled error in /auth/resend_verification: $e');
    print(st);
    return Response.json(
        statusCode: 500, body: {'error': 'Internal server error'});
  }
}

String _generateToken([int length = 32]) {
  final rnd = Random.secure();
  final bytes = List<int>.generate(length, (_) => rnd.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}
