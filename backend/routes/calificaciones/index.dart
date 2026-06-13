import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import '../../lib/db.dart';
import '../../lib/auth_helper.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _getCalificacion(context);
    case HttpMethod.post:
      return _createCalificacion(context);
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

Future<Response> _getCalificacion(RequestContext context) async {
  final payload = AuthHelper.verifyToken(context);
  if (payload == null) {
    return Response.json(statusCode: 401, body: {'error': 'No autorizado'});
  }

  final queryParams = context.request.uri.queryParameters;
  final pedidoId = queryParams['pedido_id'];

  if (pedidoId == null || pedidoId.isEmpty) {
    return Response.json(statusCode: 400, body: {'error': 'El parámetro pedido_id es obligatorio'});
  }

  final conn = await createConnection();
  try {
    final rows = await conn.query('''
      SELECT id, pedido_id, cliente_id, estrellas, comentario, created_at
      FROM public.calificaciones
      WHERE pedido_id = @pedido_id
    ''', substitutionValues: {'pedido_id': pedidoId});

    if (rows.isEmpty) {
      return Response.json(body: null); // Devuelve nulo si no hay calificación aún
    }

    final r = rows.first;
    return Response.json(body: {
      'id': r[0],
      'pedido_id': r[1],
      'cliente_id': r[2]?.toString(),
      'estrellas': r[3],
      'comentario': r[4],
      'created_at': (r[5] as DateTime).toIso8601String(),
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': e.toString()});
  } finally {
    await conn.close();
  }
}

Future<Response> _createCalificacion(RequestContext context) async {
  final payload = AuthHelper.verifyToken(context);
  if (payload == null) {
    return Response.json(statusCode: 401, body: {'error': 'No autorizado'});
  }
  final clienteId = AuthHelper.getUserId(payload);

  Map<String, dynamic> body;
  try {
    body = await context.request.json() as Map<String, dynamic>;
  } catch (_) {
    return Response.json(statusCode: 400, body: {'error': 'JSON inválido'});
  }

  final pedidoId = body['pedido_id']?.toString().trim();
  final estrellas = body['estrellas'] as int?;
  final comentario = body['comentario']?.toString().trim();

  if (pedidoId == null || pedidoId.isEmpty || estrellas == null || estrellas < 1 || estrellas > 5) {
    return Response.json(statusCode: 422, body: {'error': 'Datos de calificación inválidos o incompletos'});
  }

  final conn = await createConnection();
  try {
    // Check if pedido exists
    final order = await conn.query('SELECT id, cliente_id, estado FROM public.pedidos WHERE id = @id', substitutionValues: {'id': pedidoId});
    if (order.isEmpty) {
      return Response.json(statusCode: 404, body: {'error': 'Pedido no encontrado'});
    }

    // Verify it is delivered ('Entregado')
    final estado = order.first[2] as String;
    if (estado.toLowerCase() != 'entregado') {
      return Response.json(statusCode: 400, body: {'error': 'Solo se pueden calificar pedidos entregados'});
    }

    // Verify it belongs to the authenticated user
    final orderClienteId = order.first[1];
    if (orderClienteId.toString() != clienteId.toString()) {
      return Response.json(statusCode: 403, body: {'error': 'No tienes permiso para calificar este pedido'});
    }

    // Check if duplicate rating exists
    final duplicate = await conn.query(
      'SELECT id FROM public.calificaciones WHERE pedido_id = @pedido_id',
      substitutionValues: {'pedido_id': pedidoId},
    );
    if (duplicate.isNotEmpty) {
      return Response.json(statusCode: 409, body: {'error': 'Ya calificaste este pedido.'});
    }

    final insert = await conn.query('''
      INSERT INTO public.calificaciones (pedido_id, cliente_id, estrellas, comentario)
      VALUES (@pedido_id, @cliente_id, @estrellas, @comentario)
      RETURNING id, pedido_id, cliente_id, estrellas, comentario, created_at
    ''', substitutionValues: {
      'pedido_id': pedidoId,
      'cliente_id': clienteId,
      'estrellas': estrellas,
      'comentario': comentario,
    });

    final row = insert.first;
    return Response.json(
      statusCode: 201,
      body: {
        'id': row[0],
        'pedido_id': row[1],
        'cliente_id': row[2]?.toString(),
        'estrellas': row[3],
        'comentario': row[4],
        'created_at': (row[5] as DateTime).toIso8601String(),
      },
    );
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': e.toString()});
  } finally {
    await conn.close();
  }
}
