import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import '../../lib/db.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final conn = await createConnection();
  try {
    final rows = await conn.query(
      'SELECT id, nombre, precio FROM public.tamanos_yogur ORDER BY precio ASC',
    );
    final list = rows.map((r) => {
      'id': r[0],
      'nombre': r[1],
      'precio': double.tryParse(r[2].toString()) ?? 0.0,
    }).toList();

    return Response.json(body: list);
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': e.toString()});
  } finally {
    await conn.close();
  }
}
