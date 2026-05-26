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
        body: {'error': 'Invalid JSON', 'details': e.message},
      );
    }
    final email = body['email']?.toString();
    final phone = (body['phone'] ?? body['telefono'])?.toString();
    final password = body['password']?.toString();
    final passwordConfirm =
        (body['password_confirmation'] ?? body['confirm_password'])?.toString();
    final name = body['name']?.toString() ?? '';
    if (email == null ||
        phone == null ||
        password == null ||
        name.trim().isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'name, email, phone and password required'},
      );
    }

    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'invalid email format'},
      );
    }

    if (phone.trim().isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'phone is required'},
      );
    }

    // If client sent a confirmation field, validate it matches the password
    if (passwordConfirm != null && password != passwordConfirm) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'password and password_confirmation do not match'},
      );
    }

    // Password strength: require minimum 8 characters, at least one letter and one number
    final pwd = password;
    final pwdPattern = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$');
    if (!pwdPattern.hasMatch(pwd)) {
      return Response.json(
        statusCode: 400,
        body: {
          'error':
              'password must be at least 8 characters and include at least one letter and one number',
        },
      );
    }

    // Esta ruta no guarda directamente en la tabla final: delega al servicio.
    // El servicio crea pending_users y el token de verificación en Supabase.
    final conn = await createConnection();
    final auth = AuthService(conn);
    try {
      final user = await auth.register(email, phone, password, name);
      await conn.close();
      final verificationEmailSent = user['verification_email_sent'] == true;
      // If running in DEV mode, the service may include the verification token
      if (user.containsKey('verification_token')) {
        return Response.json(body: {'user': user});
      }
      if (!verificationEmailSent) {
        return Response.json(
          statusCode: 202,
          body: {
            'message':
                'Registration created, but the verification email could not be sent. Check backend logs or use resend verification.',
            'user': user,
          },
        );
      }
      return Response.json(
        statusCode: 201,
        body: {
          'message':
              'Registration successful. A verification email was sent if the address is valid.',
          'user': user,
        },
      );
    } catch (e, st) {
      // Log and return a conflict if user exists or other known issue
      print('Register error: $e');
      print(st);
      await conn.close();
      return Response.json(statusCode: 409, body: {'error': e.toString()});
    }
  } catch (e, st) {
    // Unexpected error — log stacktrace for debugging and return 500
    print('Unhandled error in /auth/register: $e');
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
      return Response.json(
        statusCode: 500,
        body: {
          'error': 'Internal Server Error',
          'details': e.toString(),
          'stack': st.toString(),
        },
      );
    }
    return Response.json(
      statusCode: 500,
      body: {'error': 'Internal Server Error'},
    );
  }
}
