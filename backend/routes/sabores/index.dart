import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import '../../lib/db.dart';
import '../../lib/auth_helper.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _getSabores(context);
    case HttpMethod.post:
      return _createSabor(context);
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

Future<Response> _getSabores(RequestContext context) async {
  final conn = await createConnection();
  try {
    final queryParams = context.request.uri.queryParameters;
    final soloActivos = queryParams['activo'] == 'true';

    final query = soloActivos
        ? 'SELECT id, nombre, descripcion, precio_base, activo, created_at FROM public.sabores WHERE activo = true ORDER BY nombre ASC'
        : 'SELECT id, nombre, descripcion, precio_base, activo, created_at FROM public.sabores ORDER BY nombre ASC';

    final rows = await conn.query(query);
    final list = rows.map((r) => {
      'id': r[0],
      'nombre': r[1],
      'descripcion': r[2],
      'precio_base': double.tryParse(r[3].toString()) ?? 0.0,
      'activo': r[4],
      'created_at': (r[5] as DateTime).toIso8601String(),
    }).toList();

    return Response.json(body: list);
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': e.toString()});
  } finally {
    await conn.close();
  }
}

Future<Response> _createSabor(RequestContext context) async {
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
  final descripcion = body['descripcion']?.toString().trim();
  final precioBase = double.tryParse(body['precio_base']?.toString() ?? '');

  if (nombre == null || nombre.isEmpty ||
      descripcion == null || descripcion.isEmpty ||
      precioBase == null || precioBase <= 0) {
    return Response.json(statusCode: 422, body: {'error': 'Datos incompletos o inválidos'});
  }

  final conn = await createConnection();
  try {
    // Check if duplicate nombre exists
    final duplicate = await conn.query(
      'SELECT id FROM public.sabores WHERE LOWER(nombre) = LOWER(@nombre)',
      substitutionValues: {'nombre': nombre},
    );
    if (duplicate.isNotEmpty) {
      return Response.json(statusCode: 409, body: {'error': 'Ya existe un sabor con ese nombre.'});
    }

    final insert = await conn.query('''
      INSERT INTO public.sabores (nombre, descripcion, precio_base, activo)
      VALUES (@nombre, @descripcion, @precio_base, true)
      RETURNING id, nombre, descripcion, precio_base, activo, created_at
    ''', substitutionValues: {
      'nombre': nombre,
      'descripcion': descripcion,
      'precio_base': precioBase,
    });

    final row = insert.first;
    return Response.json(
      statusCode: 201,
      body: {
        'id': row[0],
        'nombre': row[1],
        'descripcion': row[2],
        'precio_base': double.tryParse(row[3].toString()) ?? 0.0,
        'activo': row[4],
        'created_at': (row[5] as DateTime).toIso8601String(),
      },
    );
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': e.toString()});
  } finally {
    await conn.close();
  }
}
