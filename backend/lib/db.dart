import 'dart:io';

import 'package:postgres/postgres.dart';

/// Helper to create a Postgres connection from DATABASE_URL
Future<PostgreSQLConnection> createConnection() async {
  // Prefer environment variable, fall back to a local `.env` file if present.
  String? databaseUrl = Platform.environment['DATABASE_URL'];
  if (databaseUrl == null) {
    final envFile = File('.env');
    if (envFile.existsSync()) {
      final lines = envFile.readAsLinesSync();
      for (final raw in lines) {
        final line = raw.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        final idx = line.indexOf('=');
        if (idx <= 0) continue;
        final key = line.substring(0, idx).trim();
        var value = line.substring(idx + 1).trim();
        if ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'"))) {
          value = value.substring(1, value.length - 1);
        }
        if (key == 'DATABASE_URL') {
          databaseUrl = value;
          break;
        }
      }
    }
  }

  if (databaseUrl == null) {
    throw Exception('DATABASE_URL not set in environment or .env file');
  }

  final uri = Uri.parse(databaseUrl);
  final host = uri.host;
  final port = uri.port;
  final databaseName = uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : '';
  final username = uri.userInfo.split(':').first;
  final password =
      uri.userInfo.contains(':') ? uri.userInfo.split(':')[1] : null;

  final conn = PostgreSQLConnection(host, port, databaseName,
      username: username, password: password);
  await conn.open();
  return conn;
}
