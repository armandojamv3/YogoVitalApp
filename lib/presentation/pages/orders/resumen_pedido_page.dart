import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yogo_vital_app/core/models/cart_model.dart';
import 'package:yogo_vital_app/core/models/direccion_model.dart';
import 'package:yogo_vital_app/core/models/pedido_local_model.dart';
import 'package:yogo_vital_app/core/providers/pedido_provider.dart';
import 'package:yogo_vital_app/data/repositories/pedido_supabase_repository.dart';
import 'package:yogo_vital_app/presentation/pages/orders/direcciones_page.dart';

/// HU_19 + HU_20: Pantalla de resumen antes de confirmar el pedido.
class ResumenPedidoPage extends StatefulWidget {
  const ResumenPedidoPage({super.key});

  @override
  State<ResumenPedidoPage> createState() => _ResumenPedidoPageState();
}

class _ResumenPedidoPageState extends State<ResumenPedidoPage> {
  final _repo = PedidoSupabaseRepository();
  final _cop = NumberFormat.currency(
      locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  final List<DireccionModel> _dirs = [];
  DireccionModel? _selected;
  bool _loadingDirs = true;
  bool _confirming = false;
  String? _metodoPago;

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
        _dirs
          ..clear()
          ..addAll(dirs);
        _selected = dirs.where((d) => d.esPrincipal).firstOrNull ??
            dirs.firstOrNull;
        _loadingDirs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDirs = false);
    }
  }

  /// HU_21 + HU_22: confirmar y crear pedido en Supabase
  Future<void> _confirmar(PedidoLocalModel pedidoLocal) async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una dirección de entrega'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_metodoPago == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un método de pago'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _confirming = true);
    try {
      final pedidoId = await _repo.createPedido(
        pedidoLocal: pedidoLocal,
        direccionId: _selected!.id,
        metodoPago: _metodoPago!,
      );

      if (!mounted) return;

      // Limpiar estado del pedido en construcción
      context.read<PedidoProvider>().reset();
      // Limpiar carrito si tiene ítems del mismo flujo
      context.read<CartModel>().clear();

      // HU_22: diálogo de confirmación
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
              const Text('¡Pedido confirmado!',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Pedido: ${pedidoId.substring(0, 8).toUpperCase()}',
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/estado-pedido',
                  (r) => r.settings.name == '/home',
                  arguments: pedidoId,
                );
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B9EF5)),
              child: const Text('Ver mi pedido',
                  style: TextStyle(color: Colors.white)),
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
    final pedido = context.watch<PedidoProvider>();

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
                  // HU_20: Editar → volver a personalización
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Resumen del pedido',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  // HU_20: botón Editar
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Editar',
                        style: TextStyle(
                            color: Colors.white, fontSize: 14)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Tarjeta del pedido
                    _buildPedidoCard(pedido),
                    const SizedBox(height: 16),

                    // Sección de dirección
                    _buildDireccionSection(),
                    const SizedBox(height: 16),

                    // Sección método de pago
                    _buildMetodoPagoSection(),
                    const SizedBox(height: 24),

                    // Botón confirmar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (pedido.tamano == null ||
                                pedido.sabor == null ||
                                _metodoPago == null ||
                                _selected == null ||
                                _confirming)
                            ? null
                            : () => _confirmar(pedido.state),
                        icon: _confirming
                            ? const SizedBox(
                                height: 18,
                                width: 18,
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
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          disabledBackgroundColor: Colors.grey[300],
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // HU_20: segundo botón de editar
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFF5B9EF5)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Editar personalización',
                            style: TextStyle(
                                color: Color(0xFF5B9EF5),
                                fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // HU_19: tarjeta con todos los detalles del pedido
  Widget _buildPedidoCard(PedidoProvider pedido) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tu yogur personalizado',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(height: 20),

          if (pedido.tamano != null)
            _row('🥣 Tamaño', pedido.tamano!.nombre,
                _cop.format(pedido.tamano!.precioBase)),

          if (pedido.sabor != null)
            _row('🍓 Sabor base', pedido.sabor!.nombre, 'Incluido'),

          if (pedido.frutas.isNotEmpty) ...[
            const SizedBox(height: 4),
            _label('🍇 Frutas'),
            ...pedido.frutas.map(
              (f) => _row(
                  '  • ${f.nombre}', '', '+${_cop.format(f.precioAdicional)}'),
            ),
          ],

          if (pedido.extras.isNotEmpty) ...[
            const SizedBox(height: 4),
            _label('✨ Extras'),
            ...pedido.extras.map(
              (e) => _row(
                  '  • ${e.nombre}', '', '+${_cop.format(e.precioAdicional)}'),
            ),
          ],

          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              Text(
                _cop.format(pedido.total),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String sub, String price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                if (sub.isNotEmpty)
                  Text(sub,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          Text(price,
              style: TextStyle(
                  fontSize: 13,
                  color: price.startsWith('+')
                      ? const Color(0xFF2E7D32)
                      : Colors.black87,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: Text(t,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
      );

  // HU_19: sección dirección con selector
  Widget _buildDireccionSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('📍 Dirección de entrega',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              TextButton.icon(
                onPressed: _openSelector,
                icon: const Icon(Icons.edit_location_alt,
                    size: 16),
                label: const Text('Cambiar'),
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
                Text(
                  _selected!.etiqueta,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
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
  // Los ids DEBEN coincidir exactamente con el CHECK constraint
  // 'pedidos_metodo_pago_valido': 'Efectivo', 'Nequi', 'Daviplata', 'Tarjeta'.
  static const _metodos = [
    _MetodoPago('Efectivo',  'Efectivo',   'Al momento de la entrega', Icons.payments_outlined),
    _MetodoPago('Nequi',     'Nequi',      'Transferencia digital',    Icons.phone_android),
    _MetodoPago('Daviplata', 'Daviplata',  'Transferencia digital',    Icons.smartphone),
    _MetodoPago('Tarjeta',   'Tarjeta',    'Crédito o débito',         Icons.credit_card),
  ];

  Widget _buildMetodoPagoSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
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
          color: selected
              ? const Color(0xFFE3F2FD)
              : Colors.grey[50],
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
                          fontSize: 12,
                          color: Colors.grey[500])),
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
        builder: (_) => const DireccionesPage(isSelector: true),
      ),
    );
    if (result != null && mounted) {
      setState(() => _selected = result);
    } else if (mounted) {
      await _loadDirs();
    }
  }
}

class _MetodoPago {
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;

  const _MetodoPago(this.id, this.label, this.subtitle, this.icon);
}
