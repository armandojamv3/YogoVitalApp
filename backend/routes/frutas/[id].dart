import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import '../../lib/db.dart';
import '../../lib/auth_helper.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  switch (context.request.method) {
    case HttpMethod.put:
      return _updateFruta(context, id);
    case HttpMethod.patch:
      return _patchFruta(context, id);
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

Future<Response> _updateFruta(RequestContext context, String id) async {
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

  if (nombre == null || nombre.isEmpty || precioAdicional == null || precioAdicional < 0) {
    return Response.json(statusCode: 422, body: {'error': 'Datos incompletos o inválidos'});
  }

  final conn = await createConnection();
  try {
    // Check if duplicate name excluding current ID
    final duplicate = await conn.query(
      'SELECT id FROM public.frutas WHERE LOWER(nombre) = LOWER(@nombre) AND id != @id',
      substitutionValues: {'nombre': nombre, 'id': id},
    );
    if (duplicate.isNotEmpty) {
      return Response.json(statusCode: 409, body: {'error': 'Ya existe otra fruta con ese nombre.'});
    }

    final update = await conn.query('''
      UPDATE public.frutas
      SET nombre = @nombre, precio_adicional = @precio_adicional
      WHERE id = @id
      RETURNING id, nombre, precio_adicional, disponible, imagen_url, created_at
    ''', substitutionValues: {
      'id': id,
      'nombre': nombre,
      'precio_adicional': precioAdicional,
    });

    if (update.isEmpty) {
      return Response.json(statusCode: 404, body: {'error': 'Fruta no encontrada'});
    }

    final row = update.first;
    return Response.json(body: {
      'id': row[0],
      'nombre': row[1],
      'precio_adicional': double.tryParse(row[2].toString()) ?? 0.0,
      'disponible': row[3],
      'imagen_url': row[4],
      'created_at': (row[5] as DateTime).toIso8601String(),
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': e.toString()});
  } finally {
    await conn.close();
  }
}

Future<Response> _patchFruta(RequestContext context, String id) async {
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

  final disponible = body['disponible'];
  if (disponible == null || disponible is! bool) {
    return Response.json(statusCode: 400, body: {'error': 'El campo "disponible" es obligatorio y debe ser booleano'});
  }

  final conn = await createConnection();
  try {
    final update = await conn.query('''
      UPDATE public.frutas
      SET disponible = @disponible
      WHERE id = @id
      RETURNING id, nombre, precio_adicional, disponible, imagen_url, created_at
    ''', substitutionValues: {
      'id': id,
      'disponible': disponible,
    });

    if (update.isEmpty) {
      return Response.json(statusCode: 404, body: {'error': 'Fruta no encontrada'});
    }

    final row = update.first;
    return Response.json(body: {
      'id': row[0],
      'nombre': row[1],
      'precio_adicional': double.tryParse(row[2].toString()) ?? 0.0,
      'disponible': row[3],
      'imagen_url': row[4],
      'created_at': (row[5] as DateTime).toIso8601String(),
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': e.toString()});
  } finally {
    await conn.close();
  }
}
