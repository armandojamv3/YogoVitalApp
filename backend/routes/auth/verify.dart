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

  // Este endpoint confirma el token y convierte la cuenta temporal en final.
  final connection = await createConnection();
  try {
    final rows = await connection.query(
      '''
      SELECT id, user_id, pending_user_id, used, expires_at
      FROM public.email_verification_tokens
      WHERE token = @token
    ''',
      substitutionValues: {'token': token},
    );

    if (rows.isEmpty) {
      return Response.json(statusCode: 404, body: {'error': 'Token not found'});
    }

    final row = rows.first;
    final id = row[0].toString();
    final userId = row[1]?.toString();
    final pendingUserId = row[2]?.toString();
    final used = row[3] as bool;
    final expiresAt = row[4] as DateTime;

    if (used) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'Token already used'},
      );
    }
    if (DateTime.now().toUtc().isAfter(expiresAt)) {
      return Response.json(statusCode: 400, body: {'error': 'Token expired'});
    }

    if (pendingUserId != null) {
      // 1) Buscar los datos que quedaron en pending_users.
      final pendingRows = await connection.query(
        'SELECT email, password_hash, name FROM public.pending_users WHERE id = @id',
        substitutionValues: {'id': pendingUserId},
      );
      if (pendingRows.isEmpty) {
        return Response.json(
          statusCode: 404,
          body: {'error': 'Pending user not found'},
        );
      }
      final prow = pendingRows.first;
      final email = prow[0] as String;
      final passwordHash = prow[1] as String;
      final name = prow[2] as String?;

      try {
        // 2) Crear el usuario definitivo en la tabla usuario.
        // Insert into usuario and get the id
        final usuarioRows = await connection.query(
          '''
          INSERT INTO public.usuario (nombre, correo, password_hash, rol, email_verified)
          VALUES (@nombre, @correo, @password_hash, 'cliente', true)
          RETURNING id_usuario
        ''',
          substitutionValues: {
            'nombre': name,
            'correo': email,
            'password_hash': passwordHash,
          },
        );

        if (usuarioRows.isNotEmpty) {
          final idUsuario = usuarioRows.first[0];
          // 3) Crear el perfil cliente ligado al usuario recién creado.
          await connection.query(
            'INSERT INTO public.cliente (id_usuario) VALUES (@id_usuario)',
            substitutionValues: {'id_usuario': idUsuario},
          );
        }

        // 4) Marcar el token como usado y borrar el registro temporal.
        await connection.query(
          'UPDATE public.email_verification_tokens SET used = true, used_at = NOW() WHERE id = @id',
          substitutionValues: {'id': id},
        );
        await connection.query(
          'DELETE FROM public.pending_users WHERE id = @id',
          substitutionValues: {'id': pendingUserId},
        );
      } catch (e) {
        // Si ya existía el usuario, solo lo marcamos como verificado.
        try {
          await connection.query(
            'UPDATE public.usuario SET email_verified = true, rol = COALESCE(rol, \'cliente\'), updated_at = NOW() WHERE correo = @correo',
            substitutionValues: {'correo': prow[0]},
          );
          await connection.query(
            'UPDATE public.email_verification_tokens SET used = true, used_at = NOW() WHERE id = @id',
            substitutionValues: {'id': id},
          );
          // delete pending user if exists
          await connection.query(
            'DELETE FROM public.pending_users WHERE id = @id',
            substitutionValues: {'id': pendingUserId},
          );
        } catch (e2) {
          rethrow;
        }
      }
    } else if (userId != null) {
      // mark user as verified and token as used
      await connection.query(
        'UPDATE public.usuario SET email_verified = true, rol = COALESCE(rol, \'cliente\'), updated_at = NOW() WHERE id_usuario = @id',
        substitutionValues: {'id': userId},
      );
      await connection.query(
        'UPDATE public.email_verification_tokens SET used = true, used_at = NOW() WHERE id = @id',
        substitutionValues: {'id': id},
      );
    } else {
      return Response.json(
        statusCode: 400,
        body: {'error': 'Token not linked to any user'},
      );
    }

    return Response.json(
      statusCode: 200,
      body: {'ok': true, 'message': 'Email verified'},
    );
  } catch (e, st) {
    final dev = _isDev();
    return Response.json(
      statusCode: 500,
      body: {
        'error': dev
            ? e.toString() + '\n' + st.toString()
            : 'Internal server error',
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
