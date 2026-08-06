import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yogo_vital_app/core/models/cart_model.dart';
import 'package:yogo_vital_app/presentation/pages/cart/cart_checkout_page.dart';
import 'package:yogo_vital_app/presentation/widgets/custom_bottom_nav_bar.dart';

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
            return _CartItemRow(item: it, cart: cart);
          },
        ),
      ),
    );
  }

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

  const _CartItemRow({required this.item, required this.cart});

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
                  ? Image.network(
                      it.image,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Icon(
                          Icons.icecream,
                          size: 36,
                          color: Colors.orange,
                        );
                      },
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.icecream,
                        size: 36,
                        color: Colors.orange,
                      ),
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

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                it.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
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
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
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
                  const SizedBox(width: 8),
                  _QtyButton(
                    icon: Icons.add,
                    onTap: () => cart.updateQty(it.id, it.size, it.qty + 1),
                  ),
                ],
              ),
            ],
          ),
        ),

        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'COP ${it.price}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${it.price} x ${it.qty}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
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
        width: 28,
        height: 28,
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
