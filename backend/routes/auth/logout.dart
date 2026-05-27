import 'package:dart_frog/dart_frog.dart';

// Ruta: POST /auth/logout
// Propósito: Endpoint ligero que confirma el cierre de sesión en el servidor.
// NOTAS:
// - El frontend ya borra el token local; este endpoint es útil para auditoría
//   o para implementar en el futuro listas negras (blacklist) de tokens.
// - Actualmente no invalida tokens en la base de datos; sólo responde 200 OK.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  // Leemos la cabecera Authorization opcionalmente para registros.
  final authHeader = context.request.headers['authorization'];
  if (authHeader != null) {
    // Log básico (no imprimas el token completo en producción)
    final snippet = authHeader.length > 40
        ? '${authHeader.substring(0, 40)}...'
        : authHeader;
    print('Logout request - Authorization header: $snippet');
  } else {
    print('Logout request - sin Authorization header');
  }

  // Respuesta simple: OK. Si quieres invalidar tokens, implementa una tabla
  // `blacklisted_tokens` y guarda aquí el token (o session id) recibido.
  return Response.json(body: {'ok': true, 'message': 'Sesión cerrada'});
}
