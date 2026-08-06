import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Caché local (SQLite): catálogo offline + carrito persistente.
///
/// Dos usos, distintos entre sí:
///
/// 1. **Catálogo** (tamaños, sabores, frutas, extras). La fuente de verdad
///    sigue siendo Supabase; aquí solo se guarda una copia de la última
///    respuesta exitosa para que la app pueda mostrar el catálogo sin
///    internet (ver PersonalizacionRepository).
///
/// 2. **Carrito** (tabla `carrito`, desde la versión 2). Aquí sí es la
///    única copia que existe: el carrito nunca sube a Supabase. Antes vivía
///    solo en memoria dentro de CartModel, así que se perdía al cerrar la
///    app o al recargar la página en web.
///
/// El carrito se guarda por `cliente_id` para que dos cuentas en el mismo
/// dispositivo no se mezclen, y se borra al cerrar sesión.
///
/// Multiplataforma:
/// - Android / iOS / desktop: sqflite nativo (archivo .db en disco).
/// - Web: sqflite_common_ffi_web (sqlite3 compilado a WASM, persistido en
///   IndexedDB del navegador). Requiere correr una vez:
///     dart run sqflite_common_ffi_web:setup
///   para generar sqlite3.wasm y sqflite_sw.js dentro de la carpeta web/.
///   Soporte web marcado como experimental por el propio paquete.
class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  static const _dbName = 'yogo_vital_cache.db';

  /// v1: catálogo. v2: + tabla `carrito`. v3: + carrito.tamano_id.
  static const int _version = 3;

  /// Nombre de la tabla del carrito, para no repetir el literal.
  static const String tablaCarrito = 'carrito';

  Database? _db;
  bool _factorySet = false;

  Future<Database> get database async {
    // Límite de tiempo: el soporte web es experimental y puede quedarse
    // colgado (p. ej. si falta correr `dart run sqflite_common_ffi_web:
    // setup`). Nunca debe trabar el resto de la app esperando esto.
    _db ??= await _open().timeout(const Duration(seconds: 4));
    return _db!;
  }

  void _ensureFactory() {
    if (_factorySet) return;
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    }
    _factorySet = true;
  }

  Future<Database> _open() async {
    _ensureFactory();
    final path = kIsWeb ? _dbName : join(await getDatabasesPath(), _dbName);
    debugPrint('[LocalDatabase] Abriendo en: $path (web=$kIsWeb)');
    return openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        debugPrint('[LocalDatabase] Creando tablas por primera vez');
        await db.execute('''
          CREATE TABLE tamanos (
            id     TEXT PRIMARY KEY,
            nombre TEXT,
            precio REAL
          )
        ''');
        await db.execute('''
          CREATE TABLE sabores (
            id                     TEXT PRIMARY KEY,
            nombre                 TEXT,
            descripcion            TEXT,
            precio_base            REAL,
            imagen_url             TEXT,
            calificacion_promedio  REAL,
            activo                 INTEGER,
            created_at             TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE frutas (
            id               TEXT PRIMARY KEY,
            nombre           TEXT,
            precio_adicional REAL,
            disponible       INTEGER,
            imagen_url       TEXT,
            created_at       TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE extras (
            id               TEXT PRIMARY KEY,
            nombre           TEXT,
            precio_adicional REAL,
            disponible       INTEGER,
            imagen_url       TEXT,
            created_at       TEXT
          )
        ''');
        await _crearTablaCarrito(db);
      },
      onUpgrade: (db, anterior, nueva) async {
        debugPrint('[LocalDatabase] Migrando de v$anterior a v$nueva');
        if (anterior < 2) {
          await _crearTablaCarrito(db);
        }
        if (anterior < 3) {
          // Los prediseñados pasaron a llevar tamaño (migración 0045 del
          // servidor). El id del tamaño tiene que viajar en el carrito.
          await _agregarColumnaSiFalta(
              db, tablaCarrito, 'tamano_id', "TEXT NOT NULL DEFAULT ''");
        }
      },
    );
  }

  /// Tabla del carrito. La clave primaria es (cliente_id, id, size) porque
  /// esa es la misma regla con la que CartModel considera que dos ítems son
  /// "el mismo" y suma cantidades en vez de duplicar la línea.
  Future<void> _crearTablaCarrito(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tablaCarrito (
        cliente_id TEXT    NOT NULL,
        id         TEXT    NOT NULL,
        title      TEXT    NOT NULL,
        price      INTEGER NOT NULL,
        image      TEXT,
        size       TEXT    NOT NULL,
        tamano_id  TEXT    NOT NULL DEFAULT '',
        qty        INTEGER NOT NULL,
        checked    INTEGER NOT NULL,
        tipo       TEXT,
        PRIMARY KEY (cliente_id, id, size)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_carrito_cliente '
      'ON $tablaCarrito(cliente_id)',
    );
  }

  /// SQLite no tiene `ADD COLUMN IF NOT EXISTS`. Se consulta el esquema y
  /// se añade solo si falta, para que el onUpgrade sea repetible.
  Future<void> _agregarColumnaSiFalta(
      Database db, String tabla, String columna, String definicion) async {
    final info = await db.rawQuery('PRAGMA table_info($tabla)');
    final existe = info.any((c) => c['name'] == columna);
    if (existe) return;
    await db.execute('ALTER TABLE $tabla ADD COLUMN $columna $definicion');
    debugPrint('[LocalDatabase] Columna "$columna" añadida a "$tabla"');
  }

  // ── Carrito ───────────────────────────────────────────────────────────────

  /// Reemplaza el carrito guardado de [clienteId] por [filas].
  ///
  /// Solo toca las filas de ese cliente: si otra cuenta usó el mismo
  /// dispositivo, su carrito se queda intacto.
  Future<void> guardarCarrito(
      String clienteId, List<Map<String, dynamic>> filas) async {
    if (clienteId.isEmpty) return;
    try {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete(tablaCarrito,
            where: 'cliente_id = ?', whereArgs: [clienteId]);
        final batch = txn.batch();
        for (final fila in filas) {
          batch.insert(
            tablaCarrito,
            _toSqliteRow({...fila, 'cliente_id': clienteId}),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });
      debugPrint('[LocalDatabase] Carrito guardado: ${filas.length} ítems');
    } catch (e) {
      // Best-effort, igual que el caché de catálogo: si guardar falla, el
      // carrito en memoria sigue funcionando para esta sesión.
      debugPrint('[LocalDatabase] No se pudo guardar el carrito: $e');
    }
  }

  /// Carrito guardado de [clienteId]. Lista vacía si no hay nada.
  Future<List<Map<String, dynamic>>> leerCarrito(String clienteId) async {
    if (clienteId.isEmpty) return [];
    try {
      final db = await database;
      final filas = await db.query(
        tablaCarrito,
        where: 'cliente_id = ?',
        whereArgs: [clienteId],
      );
      debugPrint('[LocalDatabase] Carrito leído: ${filas.length} ítems');
      return filas.map(_fromSqliteRow).toList();
    } catch (e) {
      debugPrint('[LocalDatabase] No se pudo leer el carrito: $e');
      return [];
    }
  }

  /// Borra el carrito de [clienteId]. Se llama al cerrar sesión.
  Future<void> borrarCarrito(String clienteId) async {
    if (clienteId.isEmpty) return;
    try {
      final db = await database;
      await db.delete(tablaCarrito,
          where: 'cliente_id = ?', whereArgs: [clienteId]);
      debugPrint('[LocalDatabase] Carrito borrado');
    } catch (e) {
      debugPrint('[LocalDatabase] No se pudo borrar el carrito: $e');
    }
  }

  /// Reemplaza todo el contenido de [table] por [rows] (estrategia simple:
  /// la nube manda, el local solo refleja la última respuesta exitosa).
  Future<void> replaceAll(
      String table, List<Map<String, dynamic>> rows) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete(table);
        final batch = txn.batch();
        for (final row in rows) {
          batch.insert(
            table,
            _toSqliteRow(row),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });
      debugPrint('[LocalDatabase] Guardadas ${rows.length} filas en "$table"');
    } catch (e) {
      // Best-effort: si guardar el caché falla (p. ej. web experimental
      // sin setup), no debe romper el flujo normal con Supabase.
      debugPrint('[LocalDatabase] No se pudo guardar caché de "$table": $e');
    }
  }

  /// Filas guardadas de [table], en el mismo formato de columnas que
  /// devuelve Supabase (para poder usar directamente los *.fromJson de
  /// los modelos).
  Future<List<Map<String, dynamic>>> getAll(String table) async {
    try {
      final db = await database;
      final rows = await db.query(table);
      debugPrint(
          '[LocalDatabase] Leídas ${rows.length} filas de "$table" (caché)');
      return rows.map(_fromSqliteRow).toList();
    } catch (e) {
      // Best-effort: si la caché no responde, se trata como "sin caché"
      // (el llamador entonces deja ver el error de red original).
      debugPrint('[LocalDatabase] No se pudo leer caché de "$table": $e');
      return [];
    }
  }

  // SQLite no tiene tipo booleano nativo: se guarda como 0/1.
  Map<String, dynamic> _toSqliteRow(Map<String, dynamic> row) {
    return row.map((key, value) {
      if (value is bool) return MapEntry(key, value ? 1 : 0);
      return MapEntry(key, value);
    });
  }

  // Al leer, se devuelven los 0/1 tal cual (los repositorios los
  // convierten de vuelta a bool según el campo que corresponda).
  Map<String, dynamic> _fromSqliteRow(Map<String, dynamic> row) =>
      Map<String, dynamic>.from(row);
}
