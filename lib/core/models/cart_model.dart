import 'package:flutter/foundation.dart';

class CartItem {
  final String id;
  final String title;
  final int price;
  final String image;
  final String size;
  int qty;
  bool checked;
  final String tipo; // 'personalizado' o 'tradicional'

  CartItem({
    required this.id,
    required this.title,
    required this.price,
    required this.image,
    required this.size,
    this.qty = 1,
    this.checked = true,
    this.tipo = 'personalizado',
  });
}

class CartModel extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  void addItem(CartItem item) {
    // If same product + size exists, increment qty
    final idx = _items.indexWhere(
      (it) => it.id == item.id && it.size == item.size,
    );
    if (idx >= 0) {
      _items[idx].qty += item.qty;
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void removeItem(String id, String size) {
    _items.removeWhere((it) => it.id == id && it.size == size);
    notifyListeners();
  }

  void updateQty(String id, String size, int qty) {
    final idx = _items.indexWhere((it) => it.id == id && it.size == size);
    if (idx >= 0) {
      _items[idx].qty = qty;
      notifyListeners();
    }
  }

  void toggleChecked(String id, String size) {
    final idx = _items.indexWhere((it) => it.id == id && it.size == size);
    if (idx >= 0) {
      _items[idx].checked = !_items[idx].checked;
      notifyListeners();
    }
  }

  int get subtotal =>
      _items.fold(0, (s, it) => s + (it.checked ? it.price * it.qty : 0));

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
