import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import '../../lib/db.dart';
import '../../lib/auth_helper.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _getPedidos(context);
    case HttpMethod.post:
      return _createPedido(context);
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

Future<Response> _getPedidos(RequestContext context) async {
  final payload = AuthHelper.verifyToken(context);
  if (payload == null) {
    return Response.json(statusCode: 401, body: {'error': 'No autorizado'});
  }
  final clienteId = AuthHelper.getUserId(payload);
  final admin = AuthHelper.isAdmin(payload);

  final conn = await createConnection();
  try {
    // If admin, return all. Otherwise return only current user's orders.
    final query = admin
        ? 'SELECT id, cliente_id, direccion, total, estado, created_at, updated_at FROM public.pedidos ORDER BY created_at DESC'
        : 'SELECT id, cliente_id, direccion, total, estado, created_at, updated_at FROM public.pedidos WHERE cliente_id = @cliente_id ORDER BY created_at DESC';

    final rows = await conn.query(query, substitutionValues: {'cliente_id': clienteId});
    final list = rows.map((r) => {
      'id': r[0],
      'cliente_id': r[1]?.toString(),
      'direccion': r[2],
      'total': double.tryParse(r[3].toString()) ?? 0.0,
      'estado': r[4],
      'created_at': (r[5] as DateTime).toIso8601String(),
      'updated_at': (r[6] as DateTime).toIso8601String(),
    }).toList();

    return Response.json(body: list);
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': e.toString()});
  } finally {
    await conn.close();
  }
}

Future<Response> _createPedido(RequestContext context) async {
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

  final total = double.tryParse(body['total']?.toString() ?? '');
  final direccion = body['direccion']?.toString().trim();

  if (total == null || total < 0) {
    return Response.json(statusCode: 422, body: {'error': 'El total es requerido y debe ser mayor o igual a 0'});
  }

  final conn = await createConnection();
  try {
    final insert = await conn.query('''
      INSERT INTO public.pedidos (cliente_id, direccion, total, estado)
      VALUES (@cliente_id, @direccion, @total, 'Recibido')
      RETURNING id, cliente_id, direccion, total, estado, created_at, updated_at
    ''', substitutionValues: {
      'cliente_id': clienteId,
      'direccion': direccion,
      'total': total,
    });

    final row = insert.first;
    return Response.json(
      statusCode: 201,
      body: {
        'id': row[0],
        'cliente_id': row[1]?.toString(),
        'direccion': row[2],
        'total': double.tryParse(row[3].toString()) ?? 0.0,
        'estado': row[4],
        'created_at': (row[5] as DateTime).toIso8601String(),
        'updated_at': (row[6] as DateTime).toIso8601String(),
      },
    );
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': e.toString()});
  } finally {
    await conn.close();
  }
}
