import 'dart:async';

import '../lib/db.dart';

Future<void> main() async {
  print('Probando conexión a la base de datos...');
  try {
    final conn = await createConnection();
    print('Conexión establecida.');

    // Prueba simple
    final one = await conn.query('SELECT 1');
    print('SELECT 1 -> ${one.first.first}');

    // Conteo de usuarios
    try {
      final countRes = await conn.query('SELECT COUNT(*) FROM public.usuario');
      print('Usuarios en public.usuario: ${countRes.first.first}');
    } catch (e) {
      print('No se pudo contar filas en public.usuario: $e');
    }

    // Listar columnas de la tabla users
    try {
      final cols = await conn.query(
        "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='usuario'",
      );
      print('Columnas en public.usuario:');
      for (final row in cols) {
        print(' - ${row[0]} : ${row[1]}');
      }
    } catch (e) {
      print('No se pudo listar columnas: $e');
    }

    await conn.close();
    print('Cerrada la conexión.');
  } catch (e, st) {
    print('Error conectando a la DB: $e');
    print(st);
    rethrow;
  }
}
