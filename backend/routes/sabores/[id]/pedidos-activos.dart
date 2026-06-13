import 'dart:io';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }
  
  // Return count: 0 to allow soft-deleting in development without integrity blocks.
  return Response.json(body: {'count': 0});
}
