import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import '../../lib/db.dart';
import '../../lib/auth_helper.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _getPedido(context, id);
    case HttpMethod.patch:
    case HttpMethod.put:
      return _updatePedido(context, id);
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

Future<Response> _getPedido(RequestContext context, String id) async {
  final payload = AuthHelper.verifyToken(context);
  if (payload == null) {
    return Response.json(statusCode: 401, body: {'error': 'No autorizado'});
  }
  final clienteId = AuthHelper.getUserId(payload);
  final admin = AuthHelper.isAdmin(payload);

  final conn = await createConnection();
  try {
    final rows = await conn.query(
      'SELECT id, cliente_id, direccion, total, estado, created_at, updated_at FROM public.pedidos WHERE id = @id',
      substitutionValues: {'id': id},
    );
    if (rows.isEmpty) {
      return Response.json(statusCode: 404, body: {'error': 'Pedido no encontrado'});
    }
    final r = rows.first;
    
    // Verify ownership unless admin
    final orderClienteId = r[1];
    if (!admin && orderClienteId.toString() != clienteId.toString()) {
      return Response.json(statusCode: 403, body: {'error': 'Acceso prohibido'});
    }

    return Response.json(body: {
      'id': r[0],
      'cliente_id': r[1]?.toString(),
      'direccion': r[2],
      'total': double.tryParse(r[3].toString()) ?? 0.0,
      'estado': r[4],
      'created_at': (r[5] as DateTime).toIso8601String(),
      'updated_at': (r[6] as DateTime).toIso8601String(),
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': e.toString()});
  } finally {
    await conn.close();
  }
}

Future<Response> _updatePedido(RequestContext context, String id) async {
  final payload = AuthHelper.verifyToken(context);
  if (payload == null) {
    return Response.json(statusCode: 401, body: {'error': 'No autorizado'});
  }
  final admin = AuthHelper.isAdmin(payload);
  if (!admin) {
    return Response.json(statusCode: 403, body: {'error': 'Permiso denegado'});
  }

  Map<String, dynamic> body;
  try {
    body = await context.request.json() as Map<String, dynamic>;
  } catch (_) {
    return Response.json(statusCode: 400, body: {'error': 'JSON inválido'});
  }

  final estado = body['estado']?.toString().trim();
  if (estado == null || estado.isEmpty) {
    return Response.json(statusCode: 400, body: {'error': 'El estado es requerido'});
  }

  final conn = await createConnection();
  try {
    final update = await conn.query('''
      UPDATE public.pedidos
      SET estado = @estado, updated_at = NOW()
      WHERE id = @id
      RETURNING id, cliente_id, direccion, total, estado, created_at, updated_at
    ''', substitutionValues: {
      'id': id,
      'estado': estado,
    });

    if (update.isEmpty) {
      return Response.json(statusCode: 404, body: {'error': 'Pedido no encontrado'});
    }

    final row = update.first;
    return Response.json(body: {
      'id': row[0],
      'cliente_id': row[1]?.toString(),
      'direccion': row[2],
      'total': double.tryParse(row[3].toString()) ?? 0.0,
      'estado': row[4],
      'created_at': (row[5] as DateTime).toIso8601String(),
      'updated_at': (row[6] as DateTime).toIso8601String(),
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': e.toString()});
  } finally {
    await conn.close();
  }
}
