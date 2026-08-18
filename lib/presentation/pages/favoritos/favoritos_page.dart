import 'package:flutter/material.dart';
import 'package:yogo_vital_app/core/models/sabor.dart';
import 'package:yogo_vital_app/data/repositories/favoritos_repository.dart';
import 'package:yogo_vital_app/presentation/widgets/favorite_button.dart';
import 'package:yogo_vital_app/presentation/widgets/imagen_producto.dart';
import 'package:yogo_vital_app/core/services/precios_service.dart';

/// Sabores que el cliente marcó con el corazón.
class FavoritosPage extends StatefulWidget {
  const FavoritosPage({super.key});

  @override
  State<FavoritosPage> createState() => _FavoritosPageState();
}

class _FavoritosPageState extends State<FavoritosPage> {
  final _repo = FavoritosRepository();
  late Future<List<Sabor>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.getFavoritosConDetalle();
    // Sin esto las tarjetas de favoritos se quedarían sin precio si el
    // usuario entra aquí antes de pasar por Inicio o Yogures.
    PreciosService.precargar().then((_) {
      if (mounted) setState(() {});
    });
  }


  /// Precio con el que se anuncia un sabor en una tarjeta.
  ///
  /// En la tarjeta todavía no hay tamaño elegido, así que se muestra el más
  /// barato y se avisa con "Desde". Antes salía `precio_base`, que desde la
  /// migración 0051 no se cobra.
  String _precioDesde(Sabor s) {
    final desde = PreciosService.desde(s.recargo);
    return desde == null ? '' : 'Desde \$${desde.toStringAsFixed(0)}';
  }

  Future<void> _recargar() async {
    setState(() => _future = _repo.getFavoritosConDetalle());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F4),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF5B9EF5),
              child: Row(
                children: [
                  if (Navigator.canPop(context))
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    )
                  else
                    const SizedBox(width: 48),
                  const Expanded(
                    child: Text(
                      'Tus Favoritos',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _recargar,
                child: FutureBuilder<List<Sabor>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'No se pudieron cargar tus favoritos.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      );
                    }
                    final favoritos = snapshot.data ?? const [];
                    if (favoritos.isEmpty) {
                      return ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.favorite_border,
                                    size: 80, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  'Aún no tienes favoritos.\n'
                                  'Toca el corazón en un sabor para guardarlo aquí.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: favoritos.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final s = favoritos[i];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: ImagenProducto(
                                  url: s.imagenUrl,
                                  ancho: 60,
                                  alto: 60,
                                  tamanoIcono: 28,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(s.nombre,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                    const SizedBox(height: 4),
                                    Text(
                                      _precioDesde(s),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Color(0xFF2E7D32),
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              FavoriteButton(
                                saborId: s.id,
                                size: 20,
                                inactiveColor: Colors.grey,
                                background: Colors.transparent,
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
