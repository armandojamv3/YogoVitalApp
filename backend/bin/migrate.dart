import 'dart:io';
import 'package:path/path.dart' as p;
import '../lib/db.dart';

Future<void> main(List<String> args) async {
  final migrationsDir = Directory(p.join(Directory.current.path, 'migrations'));
  if (!migrationsDir.existsSync()) {
    print('No migrations directory found at ${migrationsDir.path}');
    return;
  }

  final files = migrationsDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final conn = await createConnection();
  try {
    // Ensure migrations table exists (simple create if needed)
    await conn.query('''
      CREATE TABLE IF NOT EXISTS public.migrations (
        id BIGSERIAL PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
      );
    ''');

    final applied = <String>{};
    final rows = await conn.query('SELECT name FROM public.migrations');
    for (final r in rows) {
      applied.add(r[0] as String);
    }

    for (final file in files) {
      final name = p.basename(file.path);
      if (applied.contains(name)) {
        print('Skipping already applied migration: $name');
        continue;
      }
      print('Applying migration: $name');
      final sql = file.readAsStringSync();
      try {
        await conn.execute(sql);
        await conn.query('INSERT INTO public.migrations (name) VALUES (@name)',
            substitutionValues: {'name': name});
        print('Applied: $name');
      } catch (e, st) {
        print('Failed to apply $name: $e');
        print(st);
        rethrow;
      }
    }
  } finally {
    await conn.close();
  }
  print('Migrations complete');
}
