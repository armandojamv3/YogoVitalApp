import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:yogo_vital_app/data/local/local_database.dart';

class CartItem {
  final String id;
  final String title;
  final int price;
  final String image;

  /// Nombre del tamaño, para mostrar ('Personal', '1 Litro'...).
  final String size;

  /// Id del tamaño en `tamanos_yogur`.
  ///
  /// [size] es solo texto para pintar; este es el que viaja hasta la RPC
  /// `crear_pedido`, que con él lee el precio real del catálogo. Vacío en
  /// los ítems que no llevan tamaño.
  final String tamanoId;

  /// Nivel de dulzura elegido: 'Bajo', 'Normal' o 'Alto'.
  ///
  /// Lo elige el cliente en el detalle del producto. Antes solo existía en
  /// el personalizador, así que un yogur típico pedido desde el catálogo
  /// llegaba siempre con el valor por defecto.
  final String dulzura;

  int qty;
  bool checked;
  final String tipo; // 'personalizado' o 'tradicional'

  CartItem({
    required this.id,
    required this.title,
    required this.price,
    required this.image,
    required this.size,
    this.tamanoId = '',
    this.dulzura = 'Normal',
    this.qty = 1,
    this.checked = true,
    this.tipo = 'personalizado',
  });

  Map<String, dynamic> toRow() => {
        'id': id,
        'title': title,
        'price': price,
        'image': image,
        'size': size,
        'tamano_id': tamanoId,
        'dulzura': dulzura,
        'qty': qty,
        'checked': checked ? 1 : 0,
        'tipo': tipo,
      };

  factory CartItem.fromRow(Map<String, dynamic> row) => CartItem(
        id: row['id']?.toString() ?? '',
        title: row['title']?.toString() ?? '',
        price: (row['price'] as num?)?.toInt() ?? 0,
        image: row['image']?.toString() ?? '',
        size: row['size']?.toString() ?? '',
        tamanoId: row['tamano_id']?.toString() ?? '',
        dulzura: row['dulzura']?.toString() ?? 'Normal',
        qty: (row['qty'] as num?)?.toInt() ?? 1,
        // SQLite guarda los booleanos como 0/1.
        checked: ((row['checked'] as num?)?.toInt() ?? 1) == 1,
        tipo: row['tipo']?.toString() ?? 'personalizado',
      );
}

/// Carrito de compra.
///
/// Vive en memoria mientras la app está abierta, pero se respalda en la
/// base local (SQLite) para que sobreviva a cerrar la app o recargar la
/// página en web — antes se perdía en cuanto el proceso moría.
///
/// El respaldo va por `cliente_id`: cada cuenta tiene el suyo, y al cerrar
/// sesión se borra, para que dos personas que compartan el mismo
/// dispositivo no vean el carrito de la otra.
///
/// El carrito NO sube a Supabase: es local al dispositivo. Si el mismo
/// usuario entra desde otro teléfono, empieza con el carrito vacío.
class CartModel extends ChangeNotifier {
  final List<CartItem> _items = [];
  final _localDb = LocalDatabase.instance;

  /// Cliente dueño del carrito actual. En null (sesión cerrada) el carrito
  /// funciona en memoria pero no se guarda en disco.
  String? _clienteId;

  bool _cargando = false;

  List<CartItem> get items => List.unmodifiable(_items);

  /// true mientras se lee el carrito guardado, para que la pantalla pueda
  /// mostrar un indicador en vez de un carrito vacío que aún no lo es.
  bool get cargando => _cargando;

  /// Carga el carrito guardado de [clienteId].
  ///
  /// Se llama al iniciar la app con sesión activa y al iniciar sesión. Si
  /// es el mismo cliente que ya estaba cargado, no hace nada: evita releer
  /// en cada evento de refresco de token de Supabase, que son frecuentes.
  Future<void> cargarPara(String clienteId) async {
    if (clienteId.isEmpty || clienteId == _clienteId) return;

    _clienteId = clienteId;
    _cargando = true;
    notifyListeners();

    final filas = await _localDb.leerCarrito(clienteId);
    _items
      ..clear()
      ..addAll(filas.map(CartItem.fromRow));

    _cargando = false;
    notifyListeners();
  }

  /// Vacía el carrito en memoria y borra el respaldo. Se llama al cerrar
  /// sesión: los datos de compra de una cuenta no deben quedar en el
  /// dispositivo para la siguiente.
  Future<void> limpiarPorCierreDeSesion() async {
    final anterior = _clienteId;
    _items.clear();
    _clienteId = null;
    notifyListeners();
    if (anterior != null) await _localDb.borrarCarrito(anterior);
  }

  void addItem(CartItem item) {
    // Si ya existe el mismo producto y tamaño, se suma la cantidad.
    final idx = _items.indexWhere(
      (it) => it.id == item.id && it.size == item.size,
    );
    if (idx >= 0) {
      _items[idx].qty += item.qty;
    } else {
      _items.add(item);
    }
    _persistir();
    notifyListeners();
  }

  void removeItem(String id, String size) {
    _items.removeWhere((it) => it.id == id && it.size == size);
    _persistir();
    notifyListeners();
  }

  void updateQty(String id, String size, int qty) {
    final idx = _items.indexWhere((it) => it.id == id && it.size == size);
    if (idx >= 0) {
      _items[idx].qty = qty;
      _persistir();
      notifyListeners();
    }
  }

  void toggleChecked(String id, String size) {
    final idx = _items.indexWhere((it) => it.id == id && it.size == size);
    if (idx >= 0) {
      _items[idx].checked = !_items[idx].checked;
      _persistir();
      notifyListeners();
    }
  }

  int get subtotal =>
      _items.fold(0, (s, it) => s + (it.checked ? it.price * it.qty : 0));

  void clear() {
    _items.clear();
    _persistir();
    notifyListeners();
  }

  /// Vuelca el carrito a la base local sin bloquear la UI.
  ///
  /// Deliberadamente no se espera (`unawaited`): guardar es best-effort,
  /// igual que el caché del catálogo. Si SQLite falla —sobre todo en web,
  /// donde el soporte es experimental— el carrito sigue funcionando en
  /// memoria durante esta sesión y solo se pierde el respaldo.
  void _persistir() {
    final clienteId = _clienteId;
    if (clienteId == null) return;
    final filas = _items.map((it) => it.toRow()).toList();
    unawaited(_localDb.guardarCarrito(clienteId, filas));
  }
}
