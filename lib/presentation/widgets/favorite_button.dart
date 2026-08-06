import 'package:flutter/material.dart';
import 'package:yogo_vital_app/data/repositories/favoritos_repository.dart';

/// Corazón para marcar/desmarcar un sabor como favorito. Consulta el
/// estado inicial una vez y actualiza de forma optimista al tocar.
class FavoriteButton extends StatefulWidget {
  final String saborId;
  final double size;
  final Color activeColor;
  final Color inactiveColor;
  final Color background;

  const FavoriteButton({
    super.key,
    required this.saborId,
    this.size = 22,
    this.activeColor = Colors.red,
    this.inactiveColor = Colors.white,
    this.background = const Color(0x40000000), // negro 25% — para overlay sobre imágenes
  });

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  final _repo = FavoritosRepository();
  bool? _isFavorito;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.saborId.isNotEmpty) _cargar();
  }

  Future<void> _cargar() async {
    final valor = await _repo.isFavorito(widget.saborId);
    if (mounted) setState(() => _isFavorito = valor);
  }

  Future<void> _toggle() async {
    if (_busy || widget.saborId.isEmpty) return;
    final anterior = _isFavorito ?? false;
    setState(() {
      _busy = true;
      _isFavorito = !anterior; // optimista
    });
    try {
      final nuevo = await _repo.toggle(widget.saborId);
      if (mounted) setState(() => _isFavorito = nuevo);
    } catch (_) {
      if (mounted) setState(() => _isFavorito = anterior); // revertir
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activo = _isFavorito ?? false;
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: widget.background,
          shape: BoxShape.circle,
        ),
        child: Icon(
          activo ? Icons.favorite : Icons.favorite_border,
          color: activo ? widget.activeColor : widget.inactiveColor,
          size: widget.size,
        ),
      ),
    );
  }
}
