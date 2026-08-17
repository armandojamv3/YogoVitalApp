import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:yogo_vital_app/core/models/pedido.dart';
import 'package:yogo_vital_app/core/models/pedido_admin.dart';
import 'package:yogo_vital_app/data/repositories/pedidos_admin_repository.dart';

const _kBlue = Color(0xFF5B9EF5);
const _kTeal = Color(0xFF0E8498);
const _kDanger = Color(0xFFEF5350);
const _kSuccess = Color(0xFF4CAF50);

class PedidoAdminDetalleScreen extends StatefulWidget {
  final String pedidoId;
  const PedidoAdminDetalleScreen({super.key, required this.pedidoId});

  @override
  State<PedidoAdminDetalleScreen> createState() =>
      _PedidoAdminDetalleScreenState();
}

class _PedidoAdminDetalleScreenState extends State<PedidoAdminDetalleScreen> {
  final _repo = PedidosAdminRepository();
  late Future<PedidoAdminDetalle> _future;
  bool _cambiando = false;

  @override
  void initState() {
    super.initState();
    _future = _repo.getDetalle(widget.pedidoId);
  }

  Future<void> _confirmarCambio(
      PedidoAdminDetalle pedido, String nuevoEstado) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Confirmar cambio de estado',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          '¿Cambiar estado de "${pedido.estadoRaw}" a "$nuevoEstado"?',
          style: const TextStyle(color: Color(0xFF5A5A5A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _estadoColor(nuevoEstado),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(nuevoEstado),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cambiando = true);
    try {
      await _repo.cambiarEstado(
        pedidoId: pedido.id,
        clienteId: pedido.clienteId,
        estadoActual: pedido.estadoRaw,
        estadoNuevo: nuevoEstado,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Estado actualizado a "$nuevoEstado"')),
            ],
          ),
          backgroundColor: _kSuccess,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
      // Recargar el detalle
      setState(() {
        _future = _repo.getDetalle(widget.pedidoId);
      });
    } on PedidoAdminException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: _kDanger),
      );
    } catch (e) {
      // Red de seguridad: cualquier error no anticipado (por ejemplo, un
      // PostgrestException que no vino envuelto) también debe verse en
      // pantalla en vez de fallar en silencio.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cambiar el estado: $e'),
          backgroundColor: _kDanger,
        ),
      );
    } finally {
      if (mounted) setState(() => _cambiando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: FutureBuilder<PedidoAdminDetalle>(
          future: _future,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _buildError(snap.error.toString());
            }
            return _buildContent(snap.data!);
          },
        ),
      ),
    );
  }

  Widget _buildContent(PedidoAdminDetalle p) {
    final estado = p.estado;
    final fmtCop = NumberFormat('#,###', 'es_CO');
    final fmtFecha = DateFormat('dd/MM/yyyy HH:mm');
    final siguientes = PedidosAdminRepository.estadosSiguientes(p.estadoRaw);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A8FE7), _kBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  'Pedido ${p.idCorto}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ),
              if (_cambiando)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
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
                // Estado actual
                _SectionCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: estado.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(estado.icon, color: estado.color, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Estado actual',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                          Text(
                            estado.label,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: estado.color),
                          ),
                          Text(
                            fmtFecha.format(p.updatedAt.toLocal()),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Cliente
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Cliente',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      _InfoRow(
                          label: 'Nombre',
                          value: p.clienteNombre),
                      if (p.clienteTelefono != null &&
                          p.clienteTelefono!.isNotEmpty)
                        _PhoneInfoRow(
                            label: 'Teléfono',
                            phone: p.clienteTelefono!),
                      if (p.direccion != null)
                        _InfoRow(
                            label: 'Dirección',
                            value: p.direccion!),
                      if (p.direccionTelefono != null &&
                          p.direccionTelefono!.isNotEmpty &&
                          p.direccionTelefono != p.clienteTelefono)
                        _PhoneInfoRow(
                            label: 'Tel. entrega',
                            phone: p.direccionTelefono!),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Ingredientes
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Yogur',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      // Un prediseñado no tiene tamaño ni sabor: es una
                      // receta cerrada. El admin necesita ver de qué está
                      // hecha para poder prepararla.
                      if (p.esPredisenhado) ...[
                        _InfoRow(label: 'Prediseñado', value: p.saborNombre),
                        // Vacío solo en prediseñados anteriores a la 0045.
                        if (p.tamanoNombre.isNotEmpty)
                          _InfoRow(label: 'Tamaño', value: p.tamanoNombre),
                        if (p.ingredientes.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          const Text('Incluye',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _kTeal,
                                  fontSize: 13)),
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
                        _InfoRow(label: 'Dulzura', value: p.dulzura),
                      ],
                      if (p.frutas.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        const Text('Frutas',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _kTeal,
                                fontSize: 13)),
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
                        const SizedBox(height: 6),
                        const Text('Extras',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.deepOrange,
                                fontSize: 13)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: p.extras
                              .map((e) => _Chip(
                                  label: e.nombre,
                                  color: Colors.deepOrange))
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
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Flexible(
                        child: Text(
                          '\$ ${fmtCop.format(p.total)} COP',
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: _kTeal),
                        ),
                      ),
                    ],
                  ),
                ),

                // Historial
                if (p.historial.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Historial de estados',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 10),
                        ...p.historial.map((h) => _HistorialTile(h: h)),
                      ],
                    ),
                  ),
                ],

                // Botones de cambio de estado
                if (siguientes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ...siguientes.map(
                    (siguiente) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: siguiente == 'Cancelado'
                                ? _kDanger
                                : _estadoColor(siguiente),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: Icon(
                            siguiente == 'Cancelado'
                                ? Icons.cancel_rounded
                                : Icons.arrow_forward_rounded,
                            size: 20,
                          ),
                          label: Text(
                            siguiente == 'Cancelado'
                                ? 'Cancelar pedido'
                                : 'Marcar como "$siguiente"',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          onPressed: _cambiando
                              ? null
                              : () => _confirmarCambio(p, siguiente),
                        ),
                      ),
                    ),
                  ),
                ],

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
            const Icon(Icons.error_outline, size: 48, color: _kDanger),
            const SizedBox(height: 12),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _kDanger)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(
                  () => _future = _repo.getDetalle(widget.pedidoId)),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'En preparación':
        return const Color(0xFFFF9800);
      case 'En camino':
        return const Color(0xFF9C27B0);
      case 'Entregado':
        return _kSuccess;
      case 'Cancelado':
        return _kDanger;
      default:
        return _kBlue;
    }
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
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
            width: 80,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey[600], fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// Fila de teléfono tocable: copia el número al portapapeles para que el
/// admin pueda pegarlo en el marcador del celular y llamar al cliente
/// durante la entrega. No usamos `url_launcher` (no está en pubspec.yaml)
/// para evitar agregar una dependencia nueva solo para esto.
class _PhoneInfoRow extends StatelessWidget {
  final String label;
  final String phone;
  const _PhoneInfoRow({required this.label, required this.phone});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: phone));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Número copiado: $phone'),
            backgroundColor: _kSuccess,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ),
            Expanded(
              child: Text(phone,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: _kBlue)),
            ),
            const Icon(Icons.copy_rounded, size: 15, color: _kBlue),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, this.color = _kTeal});
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

class _HistorialTile extends StatelessWidget {
  final HistorialEstado h;
  const _HistorialTile({required this.h});
  @override
  Widget build(BuildContext context) {
    final estado = EstadoPedidoExtension.fromString(h.estadoNuevo);
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(estado.icon, color: estado.color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  h.estadoAnterior != null
                      ? '${h.estadoAnterior} → ${h.estadoNuevo}'
                      : h.estadoNuevo,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: estado.color),
                ),
                Text(
                  fmt.format(h.fechaCambio.toLocal()),
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
