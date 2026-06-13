import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import '../../../lib/db.dart';
import '../../../lib/auth_helper.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.patch) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final payload = AuthHelper.verifyToken(context);
  if (payload == null) {
    return Response.json(statusCode: 401, body: {'error': 'No autorizado'});
  }
  final clienteId = AuthHelper.getUserId(payload);
  final admin = AuthHelper.isAdmin(payload);

  final conn = await createConnection();
  try {
    // Check order existence and status
    final rows = await conn.query(
      'SELECT id, cliente_id, estado FROM public.pedidos WHERE id = @id',
      substitutionValues: {'id': id},
    );
    if (rows.isEmpty) {
      return Response.json(statusCode: 404, body: {'error': 'Pedido no encontrado'});
    }
    
    final r = rows.first;
    final orderClienteId = r[1];
    final estadoActual = r[2] as String;

    // Verify ownership unless admin
    if (!admin && orderClienteId.toString() != clienteId.toString()) {
      return Response.json(statusCode: 403, body: {'error': 'Acceso prohibido'});
    }

    // Only allow cancelling if 'Recibido'
    if (estadoActual.toLowerCase() != 'recibido') {
      return Response.json(
        statusCode: 409,
        body: {'error': 'Este pedido ya está en proceso y no puede ser cancelado.'},
      );
    }

    final update = await conn.query('''
      UPDATE public.pedidos
      SET estado = 'Cancelado', updated_at = NOW()
      WHERE id = @id
      RETURNING id, cliente_id, direccion, total, estado, created_at, updated_at
    ''', substitutionValues: {'id': id});

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
