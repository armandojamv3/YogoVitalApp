import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import '../../lib/db.dart';
import '../../lib/auth_helper.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _getSabor(context, id);
    case HttpMethod.put:
      return _updateSabor(context, id);
    case HttpMethod.patch:
      return _patchSabor(context, id);
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

Future<Response> _getSabor(RequestContext context, String id) async {
  final conn = await createConnection();
  try {
    final rows = await conn.query(
      'SELECT id, nombre, descripcion, precio_base, activo, created_at FROM public.sabores WHERE id = @id',
      substitutionValues: {'id': id},
    );
    if (rows.isEmpty) {
      return Response.json(statusCode: 404, body: {'error': 'Sabor no encontrado'});
    }
    final r = rows.first;
    return Response.json(body: {
      'id': r[0],
      'nombre': r[1],
      'descripcion': r[2],
      'precio_base': double.tryParse(r[3].toString()) ?? 0.0,
      'activo': r[4],
      'created_at': (r[5] as DateTime).toIso8601String(),
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': e.toString()});
  } finally {
    await conn.close();
  }
}

Future<Response> _updateSabor(RequestContext context, String id) async {
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
    // Check if sabor exists
    final exists = await conn.query('SELECT id FROM public.sabores WHERE id = @id', substitutionValues: {'id': id});
    if (exists.isEmpty) {
      return Response.json(statusCode: 404, body: {'error': 'Sabor no encontrado'});
    }

    // Check duplicate name excluding current ID
    final duplicate = await conn.query(
      'SELECT id FROM public.sabores WHERE LOWER(nombre) = LOWER(@nombre) AND id != @id',
      substitutionValues: {'nombre': nombre, 'id': id},
    );
    if (duplicate.isNotEmpty) {
      return Response.json(statusCode: 409, body: {'error': 'Ya existe otro sabor con ese nombre.'});
    }

    final update = await conn.query('''
      UPDATE public.sabores
      SET nombre = @nombre, descripcion = @descripcion, precio_base = @precio_base
      WHERE id = @id
      RETURNING id, nombre, descripcion, precio_base, activo, created_at
    ''', substitutionValues: {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio_base': precioBase,
    });

    final row = update.first;
    return Response.json(body: {
      'id': row[0],
      'nombre': row[1],
      'descripcion': row[2],
      'precio_base': double.tryParse(row[3].toString()) ?? 0.0,
      'activo': row[4],
      'created_at': (row[5] as DateTime).toIso8601String(),
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': e.toString()});
  } finally {
    await conn.close();
  }
}

Future<Response> _patchSabor(RequestContext context, String id) async {
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

  final activo = body['activo'];
  if (activo == null || activo is! bool) {
    return Response.json(statusCode: 400, body: {'error': 'El campo "activo" es obligatorio y debe ser booleano'});
  }

  final conn = await createConnection();
  try {
    // Check if sabor exists
    final exists = await conn.query('SELECT id FROM public.sabores WHERE id = @id', substitutionValues: {'id': id});
    if (exists.isEmpty) {
      return Response.json(statusCode: 404, body: {'error': 'Sabor no encontrado'});
    }

    final update = await conn.query('''
      UPDATE public.sabores
      SET activo = @activo
      WHERE id = @id
      RETURNING id, nombre, descripcion, precio_base, activo, created_at
    ''', substitutionValues: {
      'id': id,
      'activo': activo,
    });

    final row = update.first;
    return Response.json(body: {
      'id': row[0],
      'nombre': row[1],
      'descripcion': row[2],
      'precio_base': double.tryParse(row[3].toString()) ?? 0.0,
      'activo': row[4],
      'created_at': (row[5] as DateTime).toIso8601String(),
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': e.toString()});
  } finally {
    await conn.close();
  }
}
