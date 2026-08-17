import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yogo_vital_app/core/models/cart_model.dart';
import 'package:yogo_vital_app/presentation/pages/cart/cart_checkout_page.dart';
import 'package:yogo_vital_app/presentation/widgets/custom_bottom_nav_bar.dart';
import 'package:yogo_vital_app/presentation/widgets/imagen_producto.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartModel>();
    final items = cart.items;
    final subtotal = cart.subtotal;
    debugPrint('[CartPage] build: items=${items.length} subtotal=$subtotal');

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B9EF5),
        foregroundColor: Colors.white,
        elevation: 4,
        // Sin `leading` explícito: AppBar ya muestra la flecha de volver
        // automáticamente solo cuando Navigator.canPop(context) es true
        // (es decir, cuando se llegó aquí empujando esta pantalla desde
        // otra, no cuando se abrió desde la barra inferior).
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 36,
              errorBuilder: (_, __, ___) => const SizedBox(width: 36),
            ),
            const SizedBox(width: 8),
            const Text(
              'Mi Carrito',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: items.isEmpty
          ? _buildEmptyState(context)
          : Column(
              children: [
                Expanded(child: _buildItemsList(context, cart, items)),
                _buildSubtotalBar(context, cart, items, subtotal),
              ],
            ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 2),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            const Text(
              'Tu carrito está vacío',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega yogures para comenzar tu pedido',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B9EF5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              icon: const Icon(Icons.local_drink_outlined),
              label: const Text(
                'Ver yogures',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onPressed: () =>
                  Navigator.of(context).pushNamed('/yogurt'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList(
    BuildContext context,
    CartModel cart,
    List<CartItem> items,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.all(12),
        child: ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 16, thickness: 0.5),
          itemBuilder: (context, index) {
            final it = items[index];
            // Deslizar para eliminar. CartModel.removeItem existía desde
            // siempre, pero ninguna pantalla la llamaba: no había forma de
            // sacar un producto del carrito.
            return Dismissible(
              // La clave incluye el tamaño porque el mismo producto puede
              // estar dos veces con tamaños distintos, y son líneas
              // separadas.
              key: ValueKey('${it.id}_${it.size}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF5350),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_outline,
                    color: Colors.white, size: 26),
              ),
              onDismissed: (_) => _quitarDelCarrito(context, cart, it),
              child: _CartItemRow(
                item: it,
                cart: cart,
                onEliminar: () => _quitarDelCarrito(context, cart, it),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Quita un producto del carrito y ofrece deshacerlo.
  ///
  /// El "Deshacer" importa: deslizar es fácil de hacer sin querer, y sin
  /// esa salida el usuario tendría que volver al catálogo a buscar el
  /// producto otra vez.
  void _quitarDelCarrito(
      BuildContext context, CartModel cart, CartItem item) {
    cart.removeItem(item.id, item.size);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final controlador = messenger.showSnackBar(
      SnackBar(
        content: Text('${item.title} eliminado del carrito'),
        duration: _duracionAviso,
        action: SnackBarAction(
          label: 'Deshacer',
          textColor: Colors.white,
          // Se vuelve a añadir el mismo objeto, así que conserva cantidad,
          // tamaño y dulzura.
          onPressed: () => cart.addItem(item),
        ),
      ),
    );

    // Cerrarlo a mano pasado el tiempo.
    //
    // Normalmente Flutter lo hace solo con `duration`, pero cuando el aviso
    // lleva un botón y el teléfono tiene activada la navegación accesible
    // (TalkBack y similares), el framework desactiva el temporizador a
    // propósito, para que a nadie se le escape el "Deshacer" antes de poder
    // pulsarlo. En ese caso el aviso se queda fijo hasta deslizarlo.
    var visible = true;
    unawaited(controlador.closed.then((_) => visible = false));
    Timer(_duracionAviso, () {
      if (visible && mounted) controlador.close();
    });
  }

  static const _duracionAviso = Duration(seconds: 4);

  Widget _buildSubtotalBar(
    BuildContext context,
    CartModel cart,
    List<CartItem> items,
    int subtotal,
  ) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('SUB TOTAL', style: TextStyle(fontSize: 12)),
                Text(
                  'COP $subtotal',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 130,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B9EF5),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _confirmOrder(context, cart, subtotal),
              child: const Text('Comprar'),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmOrder(BuildContext context, CartModel cart, int subtotal) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartCheckoutPage()),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final CartItem item;
  final CartModel cart;

  /// Eliminar el producto. Se ofrece también como botón y no solo con el
  /// gesto de deslizar, porque hay bastante gente que nunca lo descubre.
  final VoidCallback onEliminar;

  const _CartItemRow({
    required this.item,
    required this.cart,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final it = item;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => cart.toggleChecked(it.id, it.size),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: it.checked ? const Color(0xFF4CAF50) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: it.checked
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : null,
          ),
        ),

        const SizedBox(width: 12),

        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: it.image.startsWith('http')
                  ? ImagenProducto(
                      url: it.image,
                      ancho: 54,
                      alto: 54,
                      ajuste: BoxFit.contain,
                      tamanoIcono: 36,
                    )
                  : Image.asset(
                      it.image,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.icecream,
                        size: 36,
                        color: Colors.orange,
                      ),
                    ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // flex 5 contra 3: repartidos por igual, a la columna del medio le
        // tocaban ~99 px y la fila de cantidad necesita ~102. De ahí el
        // desbordamiento de 5 px. El precio puede ceder, los botones no.
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                it.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // Separaciones de 6 en vez de 8: los dos botones y la caja de
              // la cantidad tienen ancho fijo, así que en pantallas
              // estrechas esta fila se salía de su columna.
              Row(
                children: [
                  _QtyButton(
                    icon: Icons.remove,
                    onTap: () => cart.updateQty(
                      it.id,
                      it.size,
                      it.qty > 1 ? it.qty - 1 : 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2F4),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${it.qty}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _QtyButton(
                    icon: Icons.add,
                    onTap: () => cart.updateQty(it.id, it.size, it.qty + 1),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Flexible: la columna del precio tomaba su ancho natural y le
        // quitaba sitio al nombre del producto, que quedaba recortado.
        Flexible(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'COP ${it.price}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                '${it.price} x ${it.qty}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              InkWell(
                onTap: onEliminar,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Icon(Icons.delete_outline,
                      size: 20, color: Color(0xFFEF5350)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Center(child: Icon(icon, size: 18)),
      ),
    );
  }
}
