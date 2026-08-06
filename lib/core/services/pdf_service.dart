import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:yogo_vital_app/core/models/factura_model.dart';

/// Servicio para generar el PDF de factura (HU_DetalleFactura_31).
class PdfService {
  static final _fmtCop = NumberFormat('#,###', 'es_CO');
  static final _fmtFecha =
      DateFormat("dd 'de' MMMM yyyy, HH:mm", 'es');

  static const _primary = PdfColor.fromInt(0xFF5B9EF5);
  static const _teal = PdfColor.fromInt(0xFF0E8498);
  static const _dark = PdfColor.fromInt(0xFF1A1A2E);
  static const _grey = PdfColor.fromInt(0xFF6B6B7B);
  static const _lightGrey = PdfColor.fromInt(0xFFF5F7FA);
  static const _success = PdfColor.fromInt(0xFF4CAF50);

  Future<Uint8List> generarFacturaPdf(FacturaModel f) async {
    final doc = pw.Document(
      title: 'Factura Yogo Vital ${f.idCorto}',
      creator: 'Yogo Vital App',
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(f),
            pw.SizedBox(height: 20),
            _divider(),
            pw.SizedBox(height: 16),
            _sectionTitle('Detalle del pedido'),
            pw.SizedBox(height: 10),
            _itemsTable(f),
            pw.SizedBox(height: 16),
            _totalsSection(f),
            pw.Spacer(),
            _divider(),
            pw.SizedBox(height: 8),
            _footer(),
          ],
        ),
      ),
    );

    return doc.save();
  }

  // ── Header ────────────────────────────────────────────────────────────────

  pw.Widget _header(FacturaModel f) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Yogo Vital',
                style: pw.TextStyle(
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                  color: _primary,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Yogures personalizados',
                style: pw.TextStyle(fontSize: 11, color: _grey),
              ),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'FACTURA',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: _dark,
                letterSpacing: 2,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              f.idCorto,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: _teal,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              _fmtFecha.format(f.createdAt.toLocal()),
              style: pw.TextStyle(fontSize: 10, color: _grey),
            ),
            pw.SizedBox(height: 6),
            _estadoBadge(f.estado),
          ],
        ),
      ],
    );
  }

  pw.Widget _estadoBadge(String estado) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: pw.BoxDecoration(
        color: _success,
        borderRadius: pw.BorderRadius.circular(20),
      ),
      child: pw.Text(
        estado,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  // ── Items table ───────────────────────────────────────────────────────────

  pw.Widget _itemsTable(FacturaModel f) {
    final rows = <pw.TableRow>[
      // Header row
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _primary),
        children: [
          _tableCell('Ítem', bold: true, textColor: PdfColors.white),
          _tableCell('Precio', bold: true, textColor: PdfColors.white,
              align: pw.TextAlign.right),
        ],
      ),
      // Producto: un prediseñado va como una sola línea con su precio de
      // catálogo (no tiene tamaño que cobrar aparte); el resto desglosa el
      // tamaño y luego los ingredientes añadidos.
      if (f.esPredisenhado)
        _itemRow(
          [
            f.saborNombre,
            if (f.tamanoNombre.isNotEmpty) f.tamanoNombre,
            if (f.cantidad > 1) 'x${f.cantidad}',
          ].join(' · '),
          f.subtotal,
          isEven: false,
        )
      else
        _itemRow('Tamaño: ${f.tamanoNombre}', f.tamanoPrice, isEven: false),
      // Ingredientes del prediseñado, sin precio propio
      if (f.esPredisenhado)
        ...f.ingredientes.asMap().entries.map(
              (e) => _itemRow('   • ${e.value}', 0, isEven: e.key.isEven),
            ),
      // Frutas
      ...f.frutas.asMap().entries.map(
            (e) => _itemRow(
              '+ Fruta: ${e.value.nombre}',
              e.value.precio,
              isEven: e.key.isEven,
            ),
          ),
      // Extras
      ...f.extras.asMap().entries.map(
            (e) => _itemRow(
              '+ Extra: ${e.value.nombre}',
              e.value.precio,
              isEven: e.key.isEven,
            ),
          ),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
      },
      children: rows,
    );
  }

  pw.TableRow _itemRow(String label, double price, {required bool isEven}) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: isEven ? _lightGrey : PdfColors.white,
      ),
      children: [
        _tableCell(label),
        _tableCell(
          price > 0 ? '\$ ${_fmtCop.format(price)}' : 'Incluido',
          align: pw.TextAlign.right,
          textColor: price > 0 ? _dark : _grey,
        ),
      ],
    );
  }

  pw.Widget _tableCell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? textColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor ?? _dark,
        ),
      ),
    );
  }

  // ── Totals ────────────────────────────────────────────────────────────────

  pw.Widget _totalsSection(FacturaModel f) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 220,
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: _lightGrey,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border(
            left: pw.BorderSide(color: _teal, width: 3),
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _totalRow('Subtotal', f.subtotal),
            pw.SizedBox(height: 4),
            _totalRow('Costo de envío', f.costoEnvio),
            pw.SizedBox(height: 8),
            _divider(),
            pw.SizedBox(height: 8),
            _totalRow('TOTAL', f.total, bold: true, color: _teal, largeFont: true),
          ],
        ),
      ),
    );
  }

  pw.Widget _totalRow(
    String label,
    double amount, {
    bool bold = false,
    PdfColor? color,
    bool largeFont = false,
  }) {
    final style = pw.TextStyle(
      fontSize: largeFont ? 13 : 11,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color ?? _dark,
    );
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text('\$ ${_fmtCop.format(amount)} COP', style: style),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  pw.Widget _footer() {
    return pw.Center(
      child: pw.Text(
        'Yogo Vital — Gracias por tu compra • yogovital.app',
        style: pw.TextStyle(fontSize: 9, color: _grey),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  pw.Widget _divider() => pw.Divider(color: PdfColors.grey300, thickness: 0.5);

  pw.Widget _sectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 13,
        fontWeight: pw.FontWeight.bold,
        color: _dark,
      ),
    );
  }
}
