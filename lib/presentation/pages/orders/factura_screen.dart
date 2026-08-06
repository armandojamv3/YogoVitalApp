import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams, XFile;
import 'package:yogo_vital_app/core/models/factura_model.dart';
import 'package:yogo_vital_app/core/services/pdf_service.dart';
import 'package:yogo_vital_app/data/repositories/factura_repository.dart';

class FacturaScreen extends StatefulWidget {
  final String pedidoId;
  const FacturaScreen({super.key, required this.pedidoId});

  @override
  State<FacturaScreen> createState() => _FacturaScreenState();
}

class _FacturaScreenState extends State<FacturaScreen> {
  final _repo = FacturaRepository();
  final _pdfService = PdfService();

  late Future<FacturaModel> _future;
  bool _generandoPdf = false;

  static const _teal = Color(0xFF0E8498);
  static const _blue = Color(0xFF5B9EF5);

  @override
  void initState() {
    super.initState();
    _future = _repo.getFactura(widget.pedidoId);
  }

  Future<void> _abrirPdf(FacturaModel factura) async {
    setState(() => _generandoPdf = true);
    try {
      final bytes = await _pdfService.generarFacturaPdf(factura);
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Factura_${factura.idCorto}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _generandoPdf = false);
    }
  }

  Future<void> _compartirPdf(FacturaModel factura) async {
    setState(() => _generandoPdf = true);
    try {
      final Uint8List bytes = await _pdfService.generarFacturaPdf(factura);
      final file = XFile.fromData(
        bytes,
        mimeType: 'application/pdf',
        name: 'Factura_${factura.idCorto}.pdf',
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          text: 'Factura Yogo Vital ${factura.idCorto}',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al compartir: $e')),
      );
    } finally {
      if (mounted) setState(() => _generandoPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: FutureBuilder<FacturaModel>(
          future: _future,
          builder: (context, snap) {
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

  Widget _buildContent(FacturaModel f) {
    final fmtCop = NumberFormat('#,###', 'es_CO');
    final fmtFecha = DateFormat("dd 'de' MMMM yyyy · HH:mm", 'es');

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: const BoxDecoration(color: _teal),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const Expanded(
                child: Text(
                  'Factura',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
              ),
              if (_generandoPdf)
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
              children: [
                // Header de factura
                _FacturaCard(
                  child: Column(
                    children: [
                      const Text(
                        'Yogo Vital',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _blue,
                        ),
                      ),
                      const Text(
                        'Yogures personalizados',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Pedido',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                              Text(
                                f.idCorto,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: _teal,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Fecha',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                              Text(
                                fmtFecha.format(f.createdAt.toLocal()),
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Productos
                _FacturaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Productos',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 12),
                      // Un prediseñado es una sola línea con su precio de
                      // catálogo; no tiene tamaño que cobrar aparte ni
                      // frutas/extras que desglosar. Antes salía
                      // "Tamaño: " con $0.
                      if (f.esPredisenhado) ...[
                        _LineItem(
                            label: [
                              f.saborNombre,
                              if (f.tamanoNombre.isNotEmpty) f.tamanoNombre,
                              if (f.cantidad > 1) 'x${f.cantidad}',
                            ].join(' · '),
                            precio: f.subtotal,
                            fmtCop: fmtCop),
                        ...f.ingredientes.map((i) => _LineItem(
                            label: '   • $i',
                            precio: 0,
                            fmtCop: fmtCop)),
                      ] else
                        _LineItem(
                            label: 'Tamaño: ${f.tamanoNombre}',
                            precio: f.tamanoPrice,
                            fmtCop: fmtCop),
                      ...f.frutas.map((fr) => _LineItem(
                          label: '+ Fruta: ${fr.nombre}',
                          precio: fr.precio,
                          fmtCop: fmtCop)),
                      ...f.extras.map((ex) => _LineItem(
                          label: '+ Extra: ${ex.nombre}',
                          precio: ex.precio,
                          fmtCop: fmtCop)),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Totales
                _FacturaCard(
                  child: Column(
                    children: [
                      _TotalRow(
                          label: 'Subtotal',
                          valor: f.subtotal,
                          fmtCop: fmtCop),
                      const SizedBox(height: 6),
                      _TotalRow(
                          label: 'Costo de envío',
                          valor: f.costoEnvio,
                          fmtCop: fmtCop),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(),
                      ),
                      _TotalRow(
                        label: 'TOTAL',
                        valor: f.total,
                        fmtCop: fmtCop,
                        bold: true,
                        color: _teal,
                        fontSize: 18,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Botones PDF
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.print_rounded),
                        label: const Text('Ver / Imprimir'),
                        onPressed:
                            _generandoPdf ? null : () => _abrirPdf(f),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.share_rounded),
                        label: const Text('Compartir PDF'),
                        onPressed:
                            _generandoPdf ? null : () => _compartirPdf(f),
                      ),
                    ),
                  ],
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
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () =>
                  setState(() => _future = _repo.getFactura(widget.pedidoId)),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FacturaCard extends StatelessWidget {
  final Widget child;
  const _FacturaCard({required this.child});

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

class _LineItem extends StatelessWidget {
  final String label;
  final double precio;
  final NumberFormat fmtCop;

  const _LineItem({
    required this.label,
    required this.precio,
    required this.fmtCop,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Text(
            precio > 0 ? '\$ ${fmtCop.format(precio)}' : 'Incluido',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: precio > 0 ? Colors.black87 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double valor;
  final NumberFormat fmtCop;
  final bool bold;
  final Color? color;
  final double fontSize;

  const _TotalRow({
    required this.label,
    required this.valor,
    required this.fmtCop,
    this.bold = false,
    this.color,
    this.fontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: color ?? Colors.black87,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text('\$ ${fmtCop.format(valor)} COP', style: style),
      ],
    );
  }
}
