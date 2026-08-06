import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yogo_vital_app/core/models/pedido.dart';
import 'package:yogo_vital_app/core/models/pedido_historial.dart';
import 'package:yogo_vital_app/data/repositories/historial_repository.dart';
import 'package:yogo_vital_app/presentation/pages/orders/calificacion_screen.dart';
import 'package:yogo_vital_app/presentation/pages/orders/factura_screen.dart';
import 'package:yogo_vital_app/presentation/widgets/estado_pedido_timeline.dart';

class HistorialDetalleScreen extends StatefulWidget {
  final String pedidoId;
  const HistorialDetalleScreen({super.key, required this.pedidoId});

  @override
  State<HistorialDetalleScreen> createState() => _HistorialDetalleScreenState();
}

class _HistorialDetalleScreenState extends State<HistorialDetalleScreen> {
  final _repo = HistorialRepository();
  late Future<PedidoHistorial> _future;

  /// Controla si el timeline de estados está expandido bajo "Estado actual".
  bool _mostrarTimelineEstado = false;

  @override
  void initState() {
    super.initState();
    _future = _repo.getDetalle(widget.pedidoId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: FutureBuilder<PedidoHistorial>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _buildError(snap.error.toString());
            }
            final p = snap.data!;
            return _buildContent(p);
          },
        ),
      ),
    );
  }

  Widget _buildContent(PedidoHistorial p) {
    final estado = p.estado;
    final fmt = NumberFormat('#,###', 'es_CO');
    final fecha = DateFormat('dd MMM yyyy, HH:mm', 'es').format(p.createdAt.toLocal());

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: const BoxDecoration(color: Color(0xFF5B9EF5)),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  'Detalle ${p.idCorto}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.receipt_outlined, color: Colors.white),
                tooltip: 'Ver factura',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FacturaScreen(pedidoId: p.id),
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Estado actual — expandible para ver el timeline completo
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() =>
                            _mostrarTimelineEstado = !_mostrarTimelineEstado),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: estado.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(estado.icon,
                                  color: estado.color, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Estado actual',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 2),
                                  Text(
                                    estado.label,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: estado.color,
                                    ),
                                  ),
                                  Text(
                                    fecha,
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              _mostrarTimelineEstado
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                      // Timeline expandible con animación suave
                      AnimatedCrossFade(
                        firstChild:
                            const SizedBox(width: double.infinity, height: 0),
                        secondChild: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            EstadoPedidoTimeline(estadoActual: estado),
                          ],
                        ),
                        crossFadeState: _mostrarTimelineEstado
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 220),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Ingredientes
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tu yogur',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 10),

                      // Un prediseñado es un producto cerrado: no tiene
                      // tamaño ni sabor propios, y su contenido está en la
                      // lista `ingredientes` en vez de en frutas/extras.
                      if (p.esPredisenhado) ...[
                        _InfoRow(label: 'Prediseñado', value: p.saborNombre),
                        // Vacío solo en prediseñados pedidos antes de la
                        // migración 0045, cuando aún no se elegía tamaño.
                        if (p.tamanoNombre.isNotEmpty)
                          _InfoRow(label: 'Tamaño', value: p.tamanoNombre),
                        if (p.ingredientes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Incluye',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.teal)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: p.ingredientes
                                .map((i) => _Chip(label: i))
                                .toList(),
                          ),
                        ],
                      ] else ...[
                        _InfoRow(label: 'Tamaño', value: p.tamanoNombre),
                        _InfoRow(label: 'Sabor', value: p.saborNombre),
                      ],

                      if (p.frutas.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('Frutas',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, color: Colors.teal)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: p.frutas
                              .map((f) => _Chip(label: f.nombre))
                              .toList(),
                        ),
                      ],
                      if (p.extras.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('Extras',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, color: Colors.deepOrange)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: p.extras
                              .map((e) => _Chip(label: e.nombre, color: Colors.deepOrange))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Total
                _SectionCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        '\$ ${fmt.format(p.total)} COP',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0E8498),
                        ),
                      ),
                    ],
                  ),
                ),

                // Botón calificar — solo para pedidos Entregados
                if (estado == EstadoPedido.entregado) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9800),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.star_rounded),
                      label: const Text(
                        'Calificar pedido',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CalificacionScreen(pedidoId: p.id),
                        ),
                      ),
                    ),
                  ),
                ],

                // Ver factura
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Ver factura completa'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FacturaScreen(pedidoId: p.id),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _future = _repo.getDetalle(widget.pedidoId)),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, this.color = Colors.teal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
