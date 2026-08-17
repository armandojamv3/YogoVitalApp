import 'package:flutter/material.dart';
import 'package:yogo_vital_app/core/models/calificacion.dart';
import 'package:yogo_vital_app/data/repositories/calificacion_supabase_repository.dart';
import 'package:yogo_vital_app/presentation/widgets/star_rating.dart';

class CalificacionScreen extends StatefulWidget {
  final String pedidoId;
  const CalificacionScreen({super.key, required this.pedidoId});

  @override
  State<CalificacionScreen> createState() => _CalificacionScreenState();
}

class _CalificacionScreenState extends State<CalificacionScreen> {
  final _repo = CalificacionSupabaseRepository();
  final _comentarioCtrl = TextEditingController();

  Calificacion? _existente;
  bool _loading = true;
  bool _saving = false;
  int _estrellasSeleccionadas = 0;

  static const _orange = Color(0xFFFF9800);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    final existente = await _repo.getCalificacionPorPedido(widget.pedidoId);
    if (!mounted) return;
    setState(() {
      _existente = existente;
      if (existente != null) {
        _estrellasSeleccionadas = existente.estrellas;
        _comentarioCtrl.text = existente.comentario ?? '';
      }
      _loading = false;
    });
  }

  Future<void> _enviar() async {
    if (_estrellasSeleccionadas == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos una estrella'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _repo.enviarCalificacion(
        pedidoId: widget.pedidoId,
        estrellas: _estrellasSeleccionadas,
        comentario: _comentarioCtrl.text.trim().isEmpty
            ? null
            : _comentarioCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.star_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(child: Text('¡Calificación enviada! Gracias.')),
            ],
          ),
          backgroundColor: Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
      );
      Navigator.pop(context, true);
    } on CalificacionSupabaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _existente != null
                      ? _buildReadonly()
                      : _buildForm(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: const BoxDecoration(color: _orange),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Calificar pedido',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadonly() {
    final c = _existente!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: _orange),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Ya calificaste este pedido',
                    style: TextStyle(color: _orange, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text('Tu calificación',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          StarRating(
            rating: c.estrellas.toDouble(),
            size: 40,
            interactive: false,
          ),
          const SizedBox(height: 8),
          Text(
            _estrellasLabel(c.estrellas),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _orange,
            ),
          ),
          if (c.comentario != null && c.comentario!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tu comentario',
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 8),
                  Text(c.comentario!,
                      style: const TextStyle(fontSize: 15)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildForm() {
    final chars = _comentarioCtrl.text.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          const Icon(Icons.star_rounded, size: 64, color: _orange),
          const SizedBox(height: 12),
          const Text(
            '¿Cómo fue tu experiencia?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tu opinión nos ayuda a mejorar',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 28),

          // Stars
          StarRating(
            rating: _estrellasSeleccionadas.toDouble(),
            size: 42,
            interactive: true,
            onRatingChanged: (r) => setState(() => _estrellasSeleccionadas = r),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _estrellasSeleccionadas > 0
                ? Text(
                    _estrellasLabel(_estrellasSeleccionadas),
                    key: ValueKey(_estrellasSeleccionadas),
                    style: const TextStyle(
                      color: _orange,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  )
                : const SizedBox(height: 20, key: ValueKey(0)),
          ),
          const SizedBox(height: 24),

          // Comentario
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextFormField(
              controller: _comentarioCtrl,
              maxLines: 4,
              maxLength: 200,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Cuéntanos más sobre tu pedido (opcional)...',
                hintStyle:
                    const TextStyle(color: Colors.grey, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                counterText: '$chars/200',
                counterStyle: TextStyle(
                  color: chars > 180 ? Colors.red : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _enviar,
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text(
                      'Enviar calificación',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _estrellasLabel(int estrellas) {
    switch (estrellas) {
      case 1:
        return 'Muy malo';
      case 2:
        return 'Malo';
      case 3:
        return 'Regular';
      case 4:
        return 'Bueno';
      case 5:
        return '¡Excelente!';
      default:
        return '';
    }
  }
}
