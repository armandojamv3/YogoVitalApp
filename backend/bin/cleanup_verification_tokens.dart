import '../lib/db.dart';

/// Simple cleanup script to remove expired or old used verification tokens.
/// Run with: `dart run bin/cleanup_verification_tokens.dart`
Future<void> main(List<String> args) async {
  print('Connecting to database...');
  final conn = await createConnection();
  try {
    // Delete tokens expired more than 30 days ago
    await conn.query('''
      DELETE FROM public.email_verification_tokens
      WHERE expires_at < (NOW() - INTERVAL '30 days')
      OR (used = true AND used_at < (NOW() - INTERVAL '30 days'))
    ''');
    print('Cleanup complete.');
  } catch (e) {
    print('Cleanup failed: $e');
  } finally {
    await conn.close();
  }
}
