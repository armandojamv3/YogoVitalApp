import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import '../../lib/db.dart';
import '../../lib/auth_helper.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _getExtras(context);
    case HttpMethod.post:
      return _createExtra(context);
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

Future<Response> _getExtras(RequestContext context) async {
  final conn = await createConnection();
  try {
    final queryParams = context.request.uri.queryParameters;
    final soloDisponibles = queryParams['disponible'] == 'true';

    final query = soloDisponibles
        ? 'SELECT id, nombre, precio_adicional, disponible, imagen_url, created_at FROM public.extras WHERE disponible = true ORDER BY nombre ASC'
        : 'SELECT id, nombre, precio_adicional, disponible, imagen_url, created_at FROM public.extras ORDER BY nombre ASC';

    final rows = await conn.query(query);
    final list = rows.map((r) => {
      'id': r[0],
      'nombre': r[1],
      'precio_adicional': double.tryParse(r[2].toString()) ?? 0.0,
      'disponible': r[3],
      'imagen_url': r[4],
      'created_at': (r[5] as DateTime).toIso8601String(),
    }).toList();

    return Response.json(body: list);
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': e.toString()});
  } finally {
    await conn.close();
  }
}

Future<Response> _createExtra(RequestContext context) async {
  final payload = AuthHelper.verifyToken(context);
  if (payload == null) {
    return Response.json(statusCode: 401, body: {'error': 'No autorizado'});
  }
  if (!AuthHelper.isAdmin(payload)) {
    return Response.json(statusCode: 403, body: {'error': 'Permiso denegado'});
  }

  Map<String, dynamic> body;
  try {
    body = await context.request.json() as Map<String, dynamic>;
  } catch (_) {
    return Response.json(statusCode: 400, body: {'error': 'JSON inválido'});
  }

  final nombre = body['nombre']?.toString().trim();
  final precioAdicional = double.tryParse(body['precio_adicional']?.toString() ?? '');
  final disponible = body['disponible'] as bool? ?? true;
  final imagenUrl = body['imagen_url']?.toString().trim();

  if (nombre == null || nombre.isEmpty || precioAdicional == null || precioAdicional < 0) {
    return Response.json(statusCode: 422, body: {'error': 'Datos incompletos o inválidos'});
  }

  final conn = await createConnection();
  try {
    // Check if duplicate nombre exists
    final duplicate = await conn.query(
      'SELECT id FROM public.extras WHERE LOWER(nombre) = LOWER(@nombre)',
      substitutionValues: {'nombre': nombre},
    );
    if (duplicate.isNotEmpty) {
      return Response.json(statusCode: 409, body: {'error': 'Ya existe un extra con ese nombre.'});
    }

    final insert = await conn.query('''
      INSERT INTO public.extras (nombre, precio_adicional, disponible, imagen_url)
      VALUES (@nombre, @precio_adicional, @disponible, @imagen_url)
      RETURNING id, nombre, precio_adicional, disponible, imagen_url, created_at
    ''', substitutionValues: {
      'nombre': nombre,
      'precio_adicional': precioAdicional,
      'disponible': disponible,
      'imagen_url': imagenUrl,
    });

    final row = insert.first;
    return Response.json(
      statusCode: 201,
      body: {
        'id': row[0],
        'nombre': row[1],
        'precio_adicional': double.tryParse(row[2].toString()) ?? 0.0,
        'disponible': row[3],
        'imagen_url': row[4],
        'created_at': (row[5] as DateTime).toIso8601String(),
      },
    );
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': e.toString()});
  } finally {
    await conn.close();
  }
}
