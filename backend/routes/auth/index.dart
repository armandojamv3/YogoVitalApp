import 'package:dart_frog/dart_frog.dart';
import '../../lib/db.dart';
import '../../lib/services/auth_service.dart' as svc;

// POST /auth/password_reset
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }
  final body = await context.request.json() as Map<String, dynamic>;
  final email = body['email']?.toString();
  if (email == null) {
    return Response.json(statusCode: 400, body: {'error': 'email required'});
  }
  final conn = await createConnection();
  final auth = svc.AuthService(conn);
  try {
    final res = await auth.createAndSendPasswordReset(email);
    final body = <String, dynamic>{
      'ok': true,
      'message':
          'Si existe una cuenta con ese correo, recibirás un email con instrucciones.'
    };
    // Merge any DEV-only fields (like token) into the response
    body.addAll(res);
    return Response.json(body: body);
  } catch (e) {
    final errBody = {
      'ok': false,
      'message': e.toString(),
    };
    return Response.json(statusCode: 400, body: errBody);
  } finally {
    await conn.close();
  }
}
