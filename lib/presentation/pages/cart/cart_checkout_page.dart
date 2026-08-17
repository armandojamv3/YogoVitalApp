import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yogo_vital_app/core/models/cart_model.dart';
import 'package:yogo_vital_app/core/models/direccion_model.dart';
import 'package:yogo_vital_app/data/repositories/pedido_supabase_repository.dart';
import 'package:yogo_vital_app/presentation/pages/orders/direcciones_page.dart';

class CartCheckoutPage extends StatefulWidget {
  /// Compra directa: si viene con valor, el checkout usa SOLO estos ítems e
  /// ignora el carrito por completo — no los agrega, no los marca y no lo
  /// vacía al terminar. Sirve para el "Pedir ahora" de un prediseñado, donde
  /// el precio ya está cerrado y pasar por el carrito es un rodeo.
  ///
  /// En null (el caso normal) se comporta como siempre: toma los ítems
  /// marcados del carrito y lo vacía al confirmar.
  final List<CartItem>? itemsDirectos;

  const CartCheckoutPage({super.key, this.itemsDirectos});

  bool get esCompraDirecta => itemsDirectos != null;

  @override
  State<CartCheckoutPage> createState() => _CartCheckoutPageState();
}

class _CartCheckoutPageState extends State<CartCheckoutPage> {
  final _repo = PedidoSupabaseRepository();
  final _cop = NumberFormat.currency(
      locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  /// Ítems que se van a pedir: los de compra directa, o los marcados del
  /// carrito.
  List<CartItem> _itemsAPedir(CartModel cart) =>
      widget.itemsDirectos ?? cart.items.where((it) => it.checked).toList();

  DireccionModel? _selected;
  bool _loadingDirs = true;
  bool _confirming = false;
  String? _metodoPago;

  // Los ids DEBEN coincidir exactamente con el CHECK constraint
  // 'pedidos_metodo_pago_valido': 'Efectivo', 'Nequi', 'Daviplata', 'Tarjeta'.
  static const _metodos = [
    _MetodoPago('Efectivo',  'Efectivo',   'Al momento de la entrega', Icons.payments_outlined),
    _MetodoPago('Nequi',     'Nequi',      'Transferencia digital',    Icons.phone_android),
    _MetodoPago('Daviplata', 'Daviplata',  'Transferencia digital',    Icons.smartphone),
    _MetodoPago('Tarjeta',   'Tarjeta',    'Crédito o débito',         Icons.credit_card),
  ];

  @override
  void initState() {
    super.initState();
    _loadDirs();
  }

  Future<void> _loadDirs() async {
    try {
      final dirs = await _repo.getDirecciones();
      if (!mounted) return;
      setState(() {
        _selected =
            dirs.where((d) => d.esPrincipal).firstOrNull ?? dirs.firstOrNull;
        _loadingDirs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDirs = false);
    }
  }

  Future<void> _confirmar(CartModel cart) async {
    if (_selected == null || _metodoPago == null) return;

    final itemsAPedir = _itemsAPedir(cart);
    if (itemsAPedir.isEmpty) return;

    setState(() => _confirming = true);
    try {
      for (final item in itemsAPedir) {
        // Los prediseñados entran al carrito con el id prefijado
        // ('pred_<uuid>', ver YogurtPage). Antes ese id se mandaba tal cual
        // como sabor_id y Postgres lo rechazaba por no ser un UUID válido,
        // así que ningún prediseñado del carrito llegaba a convertirse en
        // pedido. Ahora se separan los dos casos.
        final esPredisenhado = item.id.startsWith('pred_');
        await _repo.createPedidoDesdeCarrito(
          predisenhadoId:
              esPredisenhado ? item.id.substring('pred_'.length) : null,
          saborId: esPredisenhado || item.id.isEmpty ? null : item.id,
          tamanoId: item.tamanoId,
          dulzura: item.dulzura,
          direccionId: _selected!.id,
          metodoPago: _metodoPago!,
          cantidad: item.qty,
        );
      }

      if (!mounted) return;
      // En compra directa el carrito no se toca: esos ítems nunca entraron.
      if (!widget.esCompraDirecta) cart.clear();

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF4CAF50), size: 64),
              const SizedBox(height: 12),
              const Text('¡Pedido realizado!',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/history',
                    (r) => r.settings.name == '/home',
                  );
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B9EF5)),
                child: const Text('Ver historial',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al confirmar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartModel>();
    final items = _itemsAPedir(cart);
    final total = items.fold<int>(0, (s, it) => s + it.price * it.qty);
    final canConfirm = _selected != null &&
        _metodoPago != null &&
        items.isNotEmpty &&
        !_confirming;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F4),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF5B9EF5),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Confirmar pedido',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildResumen(items, total),
                    const SizedBox(height: 16),
                    _buildDireccionSection(),
                    const SizedBox(height: 16),
                    _buildMetodoPagoSection(),
                    const SizedBox(height: 24),

                    // Confirmar. Altura fija de 48: es la medida estándar
                    // de un botón táctil. Antes se definía con padding
                    // vertical de 16, que sumado al texto daba unos 56 y
                    // hacía los dos botones desproporcionados.
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed:
                            canConfirm ? () => _confirmar(cart) : null,
                        icon: _confirming
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle_outline,
                                color: Colors.white),
                        label: Text(
                          _confirming
                              ? 'Procesando...'
                              : 'Confirmar pedido',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          disabledBackgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Volver: acción secundaria, algo más baja que la
                    // principal para que no compitan visualmente.
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFF5B9EF5)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        // En compra directa no se viene del carrito, sino
                        // del detalle del producto.
                        child: Text(
                            widget.esCompraDirecta
                                ? 'Volver'
                                : 'Volver al carrito',
                            style: const TextStyle(
                                color: Color(0xFF5B9EF5), fontSize: 14)),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sección resumen ───────────────────────────────────────────────────────
  Widget _buildResumen(List<CartItem> items, int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🛒 Resumen del pedido',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(height: 20),
          ...items.map(
            (it) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(it.title,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ),
                  Text('x${it.qty}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500])),
                  const SizedBox(width: 12),
                  Text(
                    _cop.format(it.price * it.qty),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              Flexible(
                child: Text(
                  _cop.format(total),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Sección dirección ─────────────────────────────────────────────────────
  Widget _buildDireccionSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // El título en negrita más el botón "Cambiar" con su icono no
          // caben juntos en pantallas estrechas, y ninguno cedía espacio.
          // El título se lleva el ancho sobrante y el botón se queda con
          // el suyo.
          Row(
            children: [
              const Expanded(
                child: Text('📍 Dirección de entrega',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              TextButton.icon(
                onPressed: _openSelector,
                icon: const Icon(Icons.edit_location_alt, size: 16),
                label: const Text('Cambiar'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loadingDirs)
            const LinearProgressIndicator()
          else if (_selected == null)
            GestureDetector(
              onTap: _openSelector,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No tienes direcciones. Toca para agregar una.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_selected!.etiqueta,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text('📞 ${_selected!.telefono}',
                    style: TextStyle(
                        color: Colors.grey[600], fontSize: 13)),
              ],
            ),
        ],
      ),
    );
  }

  // ── Sección método de pago ────────────────────────────────────────────────
  Widget _buildMetodoPagoSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💳 Método de pago',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          ..._metodos.map(_buildMetodoCard),
        ],
      ),
    );
  }

  Widget _buildMetodoCard(_MetodoPago m) {
    final selected = _metodoPago == m.id;
    return GestureDetector(
      onTap: () => setState(() => _metodoPago = m.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE3F2FD) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFF5B9EF5)
                : Colors.grey[200]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(m.icon,
                color: selected
                    ? const Color(0xFF5B9EF5)
                    : Colors.grey[600],
                size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.label,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: selected
                              ? const Color(0xFF1565C0)
                              : Colors.black87)),
                  Text(m.subtitle,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: Color(0xFF5B9EF5), size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _openSelector() async {
    final result = await Navigator.push<DireccionModel>(
      context,
      MaterialPageRoute(
          builder: (_) => const DireccionesPage(isSelector: true)),
    );
    if (result != null && mounted) {
      setState(() => _selected = result);
    } else if (mounted) {
      await _loadDirs();
    }
  }

  BoxDecoration _card() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      );
}

class _MetodoPago {
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  const _MetodoPago(this.id, this.label, this.subtitle, this.icon);
}
