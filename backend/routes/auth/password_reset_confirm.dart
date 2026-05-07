import 'package:dart_frog/dart_frog.dart';
import '../../lib/db.dart';
import '../../lib/services/auth_service.dart' as svc;

// POST /auth/password_reset/confirm
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post)
    return Response(statusCode: 405);
  final body = await context.request.json() as Map<String, dynamic>;
  final token = body['token']?.toString();
  final password = body['password']?.toString();
  final passwordConfirm = body['password_confirmation']?.toString();
  if (token == null || password == null) {
    return Response.json(
        statusCode: 400, body: {'error': 'token and password required'});
  }
  if (passwordConfirm != null && password != passwordConfirm) {
    return Response.json(
        statusCode: 400, body: {'error': 'passwords do not match'});
  }
  final conn = await createConnection();
  final auth = svc.AuthService(conn);
  try {
    await auth.confirmPasswordReset(token, password);
    return Response.json(
        body: {'ok': true, 'message': 'Password reset successful'});
  } catch (e) {
    return Response.json(statusCode: 400, body: {'error': e.toString()});
  } finally {
    await conn.close();
  }
}
