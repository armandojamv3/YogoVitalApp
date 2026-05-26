import 'package:postgres/postgres.dart';
import 'package:bcrypt/bcrypt.dart';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'dart:math';
import 'dart:convert';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:http/http.dart' as http;

/// Custom exception for login errors
/// Includes which field failed (email or password) and the HTTP status code
class LoginException implements Exception {
  final String message;
  final String field; // 'email' or 'password'
  final int statusCode; // 401, 403, 404

  LoginException(this.message, this.field, this.statusCode);

  @override
  String toString() => message;
}

class AuthService {
  final PostgreSQLConnection connection;

  AuthService(this.connection);

  Future<Map<String, dynamic>> register(
    String email,
    String phone,
    String password,
    String name,
  ) async {
    var verificationEmailSent = false;

    // 1) Primero revisa si ya existe un usuario confirmado en la tabla final.
    final existsUser = await connection.query(
      'SELECT id_usuario FROM public.usuario WHERE correo = @correo',
      substitutionValues: {'correo': email},
    );
    if (existsUser.isNotEmpty) {
      throw Exception('User already exists');
    }

    // 2) Si existe un registro temporal, también se rechaza para evitar duplicados.
    final existsPending = await connection.query(
      'SELECT id FROM public.pending_users WHERE email = @email',
      substitutionValues: {'email': email},
    );
    if (existsPending.isNotEmpty) {
      throw Exception('User already exists');
    }

    final passwordHash = BCrypt.hashpw(password, BCrypt.gensalt());

    final insert = await connection.query(
      '''
      INSERT INTO public.pending_users (email, password_hash, name, telefono)
      VALUES (@email, @password_hash, @name, @telefono)
      RETURNING id, email, name, telefono, created_at
    ''',
      substitutionValues: {
        'email': email,
        'password_hash': passwordHash,
        'name': name,
        'telefono': phone,
      },
    );
    final row = insert.first;
    final pendingId = row[0].toString();
    final rowMap = {
      'id': row[0],
      'email': row[1],
      'name': row[2],
      'telefono': row[3],
      'created_at': row[4].toString(),
    };

    // 3) Genera un token de verificación y lo asocia al registro pendiente.
    final token = _generateToken();
    final expiresAt = DateTime.now().toUtc().add(const Duration(hours: 24));
    await connection.query(
      '''
        INSERT INTO public.email_verification_tokens (pending_user_id, token, expires_at)
      VALUES (@pending_user_id, @token, @expires_at)
    ''',
      substitutionValues: {
        'pending_user_id': pendingId,
        'token': token,
        'expires_at': expiresAt.toIso8601String(),
      },
    );

    // 4) Intenta enviar el correo de verificación; si falla, el flujo no se rompe.
    try {
      await _sendVerificationEmail(email, token);
      verificationEmailSent = true;
    } catch (e) {
      print('Warning: failed to send verification email: $e');
    }

    final dev = _isDev();
    final base = rowMap;
    if (dev) {
      base['verification_token'] = token;
      base['verification_expires_at'] = expiresAt.toIso8601String();
    }
    base['verification_email_sent'] = verificationEmailSent;
    return base;
  }

  String _generateToken([int length = 32]) {
    final rnd = Random.secure();
    final bytes = List<int>.generate(length, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  bool _isDev() {
    final env = Platform.environment['DEV'];
    if (env != null) return env.toLowerCase() == 'true';
    final envFile = File('.env');
    if (envFile.existsSync()) {
      final content = envFile.readAsStringSync();
      if (content.contains('\nDEV=true') || content.startsWith('DEV=true'))
        return true;
    }
    return false;
  }

  Future<void> _sendVerificationEmail(String toEmail, String token) async {
    // En producción puede usar SendGrid; si no, cae a SMTP configurado en .env.
    String? sendgridKey = Platform.environment['SENDGRID_API_KEY'];
    String? sendgridFrom = Platform.environment['SENDGRID_FROM'];
    String? appBase = Platform.environment['APP_BASE_URL'];

    // Try to read missing values from .env
    if (sendgridKey == null || sendgridFrom == null || appBase == null) {
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
          switch (key) {
            case 'SENDGRID_API_KEY':
              sendgridKey = value;
              break;
            case 'SENDGRID_FROM':
              sendgridFrom = value;
              break;
            case 'APP_BASE_URL':
              appBase = value;
              break;
          }
        }
      }
    }

    appBase ??= 'http://localhost:8080';
    final verificationLink = Uri.parse(
      appBase,
    ).resolve('/auth/verify?token=$token').toString();

    if (sendgridKey != null && sendgridKey.isNotEmpty) {
      final from = sendgridFrom ?? 'no-reply@localhost';
      final url = Uri.parse('https://api.sendgrid.com/v3/mail/send');
      final body = jsonEncode({
        'personalizations': [
          {
            'to': [
              {'email': toEmail},
            ],
          },
        ],
        'from': {'email': from},
        'subject': 'Verifica tu correo',
        'content': [
          {
            'type': 'text/plain',
            'value': 'Por favor verifica tu correo: $verificationLink',
          },
          {
            'type': 'text/html',
            'value':
                '<p>Por favor verifica tu correo haciendo click en el siguiente enlace:</p><p><a href="$verificationLink">Verificar email</a></p>',
          },
        ],
      });

      final resp = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $sendgridKey',
          'Content-Type': 'application/json',
        },
        body: body,
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        print('Verification email sent via SendGrid to $toEmail');
        return;
      } else {
        throw Exception(
          'SendGrid send failed: ${resp.statusCode} ${resp.body}',
        );
      }
    }

    // Fall back to SMTP if SendGrid not configured
    String? host = Platform.environment['SMTP_HOST'];
    String? portStr = Platform.environment['SMTP_PORT'];
    String? username = Platform.environment['SMTP_USERNAME'];
    String? password = Platform.environment['SMTP_PASSWORD'];
    String? from = Platform.environment['SMTP_FROM'];

    if (host == null ||
        portStr == null ||
        username == null ||
        password == null ||
        from == null) {
      // attempt to read SMTP from .env as last resort
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
          switch (key) {
            case 'SMTP_HOST':
              host = value;
              break;
            case 'SMTP_PORT':
              portStr = value;
              break;
            case 'SMTP_USERNAME':
              username = value;
              break;
            case 'SMTP_PASSWORD':
              password = value;
              break;
            case 'SMTP_FROM':
              from = value;
              break;
          }
        }
      }
    }

    if (host == null ||
        portStr == null ||
        username == null ||
        password == null ||
        from == null) {
      throw Exception('No mailer configured (SendGrid or SMTP)');
    }

    final port = int.tryParse(portStr) ?? 587;
    // Allow explicit SSL mode via env or enable automatically for port 465
    bool smtpUseSsl = false;
    final smtpUseSslEnv = Platform.environment['SMTP_USE_SSL'];
    if (smtpUseSslEnv != null)
      smtpUseSsl = smtpUseSslEnv.toLowerCase() == 'true';
    if (port == 465) smtpUseSsl = true;

    final smtpServer = SmtpServer(
      host,
      port: port,
      username: username,
      password: password,
      ssl: smtpUseSsl,
      ignoreBadCertificate: true,
    );
    // Normalize `from` to separate display name and email address.
    String rawFrom = from;
    String fromEmail = rawFrom;
    String? fromName;
    final match = RegExp(
      r'^(?:"?(.+?)"?\s*)?<([^>]+)>\s*\$',
    ).firstMatch(rawFrom + ' ');
    if (match != null) {
      // pattern captures optional name and the address inside <>
      final namePart = match.group(1);
      final addrPart = match.group(2);
      if (addrPart != null) fromEmail = addrPart.trim();
      if (namePart != null) fromName = namePart.trim();
    } else {
      // also handle simple `Name <email@x>` without strict quoting
      final loose = RegExp(r'^(.*)<([^>]+)>').firstMatch(rawFrom);
      if (loose != null) {
        final namePart = loose.group(1);
        final addrPart = loose.group(2);
        if (addrPart != null) fromEmail = addrPart.trim();
        if (namePart != null)
          fromName = namePart.trim().replaceAll('"', '').trim();
      }
    }

    // Ensure envelope uses only the email address; pass display name separately
    final message = Message()
      ..from = Address(fromEmail, fromName)
      ..recipients.add(toEmail)
      ..subject = 'Verifica tu correo'
      ..text =
          'Por favor verifica tu correo haciendo click en el siguiente enlace: $verificationLink'
      ..html =
          '<p>Por favor verifica tu correo haciendo click en el siguiente enlace:</p><p><a href="$verificationLink">Verificar email</a></p>';

    final sendReport = await send(message, smtpServer);
    print('Verification email send via SMTP: ' + sendReport.toString());
  }

  Future<void> _sendPasswordResetEmail(String toEmail, String token) async {
    String? sendgridKey = Platform.environment['SENDGRID_API_KEY'];
    String? sendgridFrom = Platform.environment['SENDGRID_FROM'];
    String? appBase = Platform.environment['APP_BASE_URL'];

    if (sendgridKey == null || sendgridFrom == null || appBase == null) {
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
          switch (key) {
            case 'SENDGRID_API_KEY':
              sendgridKey = value;
              break;
            case 'SENDGRID_FROM':
              sendgridFrom = value;
              break;
            case 'APP_BASE_URL':
              appBase = value;
              break;
          }
        }
      }
    }

    appBase ??= 'http://localhost:8080';
    String resetLink;
    try {
      // If the configured APP_BASE_URL contains a hash fragment (used by Flutter web),
      // build the link keeping the fragment so the frontend router can handle it.
      if (appBase.contains('#')) {
        // Ensure no trailing slash before appending
        final base = appBase.endsWith('/')
            ? appBase.substring(0, appBase.length - 1)
            : appBase;
        // If the base already ends with '#', append '/reset-password?token=...'
        if (base.endsWith('#')) {
          resetLink = '$base/\reset-password?token=$token'.replaceAll('\\', '');
        } else {
          resetLink = '$base/reset-password?token=$token';
        }
      } else {
        resetLink = Uri.parse(
          appBase,
        ).resolve('/reset-password?token=$token').toString();
      }
    } catch (_) {
      resetLink = Uri.parse(
        'http://localhost:8080',
      ).resolve('/reset-password?token=$token').toString();
    }

    if (sendgridKey != null && sendgridKey.isNotEmpty) {
      final from = sendgridFrom ?? 'no-reply@localhost';
      final url = Uri.parse('https://api.sendgrid.com/v3/mail/send');
      final body = jsonEncode({
        'personalizations': [
          {
            'to': [
              {'email': toEmail},
            ],
          },
        ],
        'from': {'email': from},
        'subject': 'Restablece tu contraseña',
        'content': [
          {
            'type': 'text/plain',
            'value': 'Para restablecer tu contraseña visita: $resetLink',
          },
          {
            'type': 'text/html',
            'value':
                '<p>Haz click en el siguiente enlace para restablecer tu contraseña:</p><p><a href="$resetLink">Restablecer contraseña</a></p>',
          },
        ],
      });

      final resp = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $sendgridKey',
          'Content-Type': 'application/json',
        },
        body: body,
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        print('Password reset email sent via SendGrid to $toEmail');
        return;
      } else {
        throw Exception(
          'SendGrid send failed: ${resp.statusCode} ${resp.body}',
        );
      }
    }

    // fallback to SMTP
    String? host = Platform.environment['SMTP_HOST'];
    String? portStr = Platform.environment['SMTP_PORT'];
    String? username = Platform.environment['SMTP_USERNAME'];
    String? password = Platform.environment['SMTP_PASSWORD'];
    String? from = Platform.environment['SMTP_FROM'];

    if (host == null ||
        portStr == null ||
        username == null ||
        password == null ||
        from == null) {
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
          switch (key) {
            case 'SMTP_HOST':
              host = value;
              break;
            case 'SMTP_PORT':
              portStr = value;
              break;
            case 'SMTP_USERNAME':
              username = value;
              break;
            case 'SMTP_PASSWORD':
              password = value;
              break;
            case 'SMTP_FROM':
              from = value;
              break;
          }
        }
      }
    }

    if (host == null ||
        portStr == null ||
        username == null ||
        password == null ||
        from == null) {
      throw Exception('No mailer configured (SendGrid or SMTP)');
    }

    final port = int.tryParse(portStr) ?? 587;
    bool smtpUseSsl = false;
    final smtpUseSslEnv = Platform.environment['SMTP_USE_SSL'];
    if (smtpUseSslEnv != null)
      smtpUseSsl = smtpUseSslEnv.toLowerCase() == 'true';
    if (port == 465) smtpUseSsl = true;

    final smtpServer = SmtpServer(
      host,
      port: port,
      username: username,
      password: password,
      ssl: smtpUseSsl,
      ignoreBadCertificate: true,
    );

    String rawFrom = from;
    String fromEmail = rawFrom;
    String? fromName;
    final match = RegExp(
      r'^(?:"?(.+?)"?\s*)?<([^>]+)>\s*\$',
    ).firstMatch(rawFrom + ' ');
    if (match != null) {
      final namePart = match.group(1);
      final addrPart = match.group(2);
      if (addrPart != null) fromEmail = addrPart.trim();
      if (namePart != null) fromName = namePart.trim();
    } else {
      final loose = RegExp(r'^(.*)<([^>]+)>').firstMatch(rawFrom);
      if (loose != null) {
        final namePart = loose.group(1);
        final addrPart = loose.group(2);
        if (addrPart != null) fromEmail = addrPart.trim();
        if (namePart != null)
          fromName = namePart.trim().replaceAll('"', '').trim();
      }
    }

    final message = Message()
      ..from = Address(fromEmail, fromName)
      ..recipients.add(toEmail)
      ..subject = 'Restablece tu contraseña'
      ..text = 'Para restablecer tu contraseña visita: $resetLink'
      ..html =
          '<p>Haz click en el siguiente enlace para restablecer tu contraseña:</p><p><a href="$resetLink">Restablecer contraseña</a></p>';

    final sendReport = await send(message, smtpServer);
    print('Password reset email send via SMTP: ' + sendReport.toString());
  }

  Future<Map<String, dynamic>> createAndSendPasswordReset(String email) async {
    final userRes = await connection.query(
      'SELECT id_usuario FROM public.usuario WHERE correo = @correo',
      substitutionValues: {'correo': email},
    );
    if (userRes.isEmpty) {
      throw Exception('User not found');
    }
    final userId = userRes.first[0].toString();
    final token = _generateToken();
    final expiresAt = DateTime.now().toUtc().add(const Duration(hours: 2));
    await connection.query(
      '''
      INSERT INTO public.password_reset_tokens (user_id, token, expires_at)
      VALUES (@user_id, @token, @expires_at)
    ''',
      substitutionValues: {
        'user_id': userId,
        'token': token,
        'expires_at': expiresAt.toIso8601String(),
      },
    );

    try {
      await _sendPasswordResetEmail(email, token);
    } catch (e) {
      print('Warning: failed to send password reset email: $e');
    }

    // For security / UX we do NOT return the token in the HTTP response.
    // If running in development, log the token to the server console so
    // developers can use it for testing. In production the token is never
    // exposed in responses.
    if (_isDev()) {
      print(
        'DEV password reset token for $email: $token, expires_at: ${expiresAt.toIso8601String()}',
      );
    }
    return {};
  }

  Future<void> confirmPasswordReset(String token, String newPassword) async {
    final res = await connection.query(
      'SELECT id, user_id, expires_at, used_at FROM public.password_reset_tokens WHERE token = @token',
      substitutionValues: {'token': token},
    );
    if (res.isEmpty) throw Exception('Invalid or expired token');
    final row = res.first;
    final id = row[0].toString();
    final userId = row[1]?.toString();
    final expiresAt = row[2] as DateTime;
    final usedAt = row[3] as DateTime?;
    if (usedAt != null) throw Exception('Token already used');
    if (expiresAt.isBefore(DateTime.now().toUtc()))
      throw Exception('Token expired');
    if (userId == null) throw Exception('Invalid token');

    final passwordHash = BCrypt.hashpw(newPassword, BCrypt.gensalt());
    await connection.query(
      '''
      UPDATE public.usuario SET password_hash = @password_hash WHERE id_usuario = @id
    ''',
      substitutionValues: {'password_hash': passwordHash, 'id': userId},
    );

    await connection.query(
      '''
      UPDATE public.password_reset_tokens SET used_at = @used_at WHERE id = @id
    ''',
      substitutionValues: {
        'used_at': DateTime.now().toUtc().toIso8601String(),
        'id': id,
      },
    );
  }

  /// Public wrapper to send verification email (used by resend endpoint)
  Future<void> sendVerificationEmail(String toEmail, String token) async {
    await _sendVerificationEmail(toEmail, token);
  }

  /// Create a new verification token for the given email, persist it and send the
  /// verification email. Returns a map containing `verification_token` when in
  /// DEV mode so callers (tests / Postman) can read it.
  Future<Map<String, dynamic>> createAndSendVerificationToken(
    String email,
  ) async {
    // Try to find a confirmed user first
    final userRes = await connection.query(
      'SELECT id_usuario, email_verified FROM public.usuario WHERE correo = @correo',
      substitutionValues: {'correo': email},
    );
    String? userId;
    String? pendingId;
    if (userRes.isNotEmpty) {
      userId = userRes.first[0].toString();
      final emailVerified = userRes.first[1] as bool;
      if (emailVerified) {
        throw Exception('Email already verified');
      }
    } else {
      // try pending_users
      final pendingRes = await connection.query(
        'SELECT id FROM public.pending_users WHERE email = @email',
        substitutionValues: {'email': email},
      );
      if (pendingRes.isEmpty) {
        throw Exception('User not found');
      }
      pendingId = pendingRes.first[0].toString();
    }

    final token = _generateToken();
    final expiresAt = DateTime.now().toUtc().add(const Duration(hours: 24));
    if (userId != null) {
      await connection.query(
        '''
        INSERT INTO public.email_verification_tokens (user_id, token, expires_at)
        VALUES (@user_id, @token, @expires_at)
      ''',
        substitutionValues: {
          'user_id': userId,
          'token': token,
          'expires_at': expiresAt.toIso8601String(),
        },
      );
    } else {
      await connection.query(
        '''
        INSERT INTO public.email_verification_tokens (pending_user_id, token, expires_at)
        VALUES (@pending_user_id, @token, @expires_at)
      ''',
        substitutionValues: {
          'pending_user_id': pendingId,
          'token': token,
          'expires_at': expiresAt.toIso8601String(),
        },
      );
    }

    try {
      await _sendVerificationEmail(email, token);
    } catch (e) {
      print(
        'Warning: failed to send verification email in createAndSendVerificationToken: $e',
      );
    }

    if (_isDev()) {
      return {
        'verification_token': token,
        'verification_expires_at': expiresAt.toIso8601String(),
      };
    }
    return {};
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await connection.query(
      'SELECT id_usuario, password_hash, nombre, email_verified FROM public.usuario WHERE correo = @correo',
      substitutionValues: {'correo': email},
    );
    if (res.isEmpty) throw LoginException('User not found', 'email', 404);
    final row = res.first;
    final id = row[0].toString();
    final passwordHash = row[1] as String;
    final name = row[2] as String;
    final emailVerified = row[3] as bool;

    final ok = BCrypt.checkpw(password, passwordHash);
    if (!ok) throw LoginException('Invalid password', 'password', 401);
    if (!emailVerified) throw LoginException('Email not verified', 'email', 403);
    // Read JWT secret from environment or fallback to a local `.env` file.
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
    final jwt = JWT({'id': id, 'email': email});
    final token = jwt.sign(
      SecretKey(secret),
      expiresIn: const Duration(hours: 24),
    );

    return {
      'token': token,
      'user': {'id': id, 'email': email, 'name': name},
    };
  }
}
