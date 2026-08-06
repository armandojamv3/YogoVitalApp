import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/core/models/cart_model.dart';
import 'package:yogo_vital_app/core/models/sabor.dart';
import 'package:yogo_vital_app/presentation/pages/yogurt/categories/personalizado_page.dart';
import 'package:yogo_vital_app/presentation/widgets/custom_bottom_nav_bar.dart';
import 'package:yogo_vital_app/presentation/widgets/favorite_button.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final _db = Supabase.instance.client;

  List<Map<String, dynamic>> _reviews = [];
  bool _loadingReviews = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReviews());
  }

  Future<void> _loadReviews() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final saborId = args?['saborId'] as String?;
    if (saborId == null) {
      setState(() => _loadingReviews = false);
      return;
    }
    try {
      final pedidosData = await _db
          .from('pedidos')
          .select('id')
          .eq('sabor_id', saborId);

      final pedidoIds =
          (pedidosData as List).map((e) => e['id'] as String).toList();

      if (pedidoIds.isEmpty) {
        setState(() {
          _reviews = [];
          _loadingReviews = false;
        });
        return;
      }

      final calData = await _db
          .from('calificaciones')
          .select('estrellas, comentario, created_at')
          .inFilter('pedido_id', pedidoIds)
          .order('created_at', ascending: false)
          .limit(5);

      setState(() {
        _reviews = (calData as List).cast<Map<String, dynamic>>();
        _loadingReviews = false;
      });
    } catch (_) {
      setState(() => _loadingReviews = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final title = args?['title']?.toString() ?? 'Producto';
    final description = args?['description']?.toString() ?? '';
    final image = args?['image']?.toString() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF2A654),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(color: Color(0xFF5B9EF5)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child:
                        const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Text(
                    'Aprender Más',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  FavoriteButton(
                    saborId: args?['saborId']?.toString() ?? '',
                    size: 20,
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Imagen del sabor
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: image.startsWith('http')
                              ? Image.network(
                                  image,
                                  fit: BoxFit.cover,
                                  height: 200,
                                  width: double.infinity,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return _imagePlaceholder();
                                  },
                                  errorBuilder: (_, __, ___) =>
                                      _imagePlaceholder(),
                                )
                              : _imagePlaceholder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Nombre y descripción
                      Container(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6B3A0D),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              description,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF4A2B12),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Hecho desde cero con ingredientes frescos',
                              style: TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Nuestros Yogures los hacemos con leche fresca '
                              'directamente del campo.',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Reseñas desde Supabase
                      _buildReviewsSection(),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            _buildActionBar(args),
            const CustomBottomNavBar(currentIndex: 0),
          ],
        ),
      ),
    );
  }

  // ── Barra de acciones ────────────────────────────────────────────────────
  Widget _buildActionBar(Map<String, dynamic>? args) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _agregarAlCarrito(args),
                icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                label: const Text('Agregar',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5B9EF5),
                  side: const BorderSide(
                      color: Color(0xFF5B9EF5), width: 1.6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _pedirAhora(args),
                icon: const Icon(Icons.bolt, size: 20, color: Colors.white),
                label: const Text('Pedir ahora',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B9EF5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _agregarAlCarrito(Map<String, dynamic>? args) {
    final saborId = args?['saborId']?.toString() ?? '';
    final title = args?['title']?.toString() ?? 'Yogur';
    final image = args?['image']?.toString() ?? '';
    final precio = (args?['precio'] as num?)?.toInt() ?? 0;

    final cart = context.read<CartModel>();
    debugPrint('[DetailPage] Agregando al carrito. Items antes: ${cart.items.length}');
    cart.addItem(CartItem(
          id: saborId,
          title: title,
          price: precio,
          image: image,
          size: 'Estándar',
          tipo: 'personalizado',
        ));
    debugPrint('[DetailPage] Items después de agregar: ${cart.items.length}');

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: const Text('¡Agregado al carrito!'),
        backgroundColor: const Color(0xFF4CAF50),
        action: SnackBarAction(
          label: 'Ver carrito',
          textColor: Colors.white,
          onPressed: () => Navigator.pushNamed(context, '/cart'),
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 3), controller.close);
  }

  void _pedirAhora(Map<String, dynamic>? args) {
    final sabor = Sabor(
      id: args?['saborId']?.toString() ?? '',
      nombre: args?['title']?.toString() ?? '',
      descripcion: args?['description']?.toString() ?? '',
      precioBase: (args?['precio'] as num?)?.toDouble() ?? 0.0,
      imagenUrl: (args?['image']?.toString() ?? '').isNotEmpty
          ? args!['image'].toString()
          : null,
      activo: true,
      createdAt: DateTime.now(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalizadoPage(initialSabor: sabor),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.orange[100],
      child: const Icon(Icons.icecream, size: 80, color: Colors.orange),
    );
  }

  Widget _buildReviewsSection() {
    if (_loadingReviews) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_reviews.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(20),
        child: const Text(
          'Sin calificaciones aún. ¡Sé el primero en opinar!',
          style: TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Opiniones de clientes',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6B3A0D)),
        ),
        const SizedBox(height: 12),
        ..._reviews.map(_buildReviewCard),
      ],
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final estrellas = (review['estrellas'] as num?)?.toInt() ?? 0;
    final comentario = review['comentario'] as String?;
    final fecha = (review['created_at'] as String? ?? '').split('T').first;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 14),
                  SizedBox(width: 4),
                  Text('Cliente verificado',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < estrellas ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          if (comentario != null && comentario.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Text(comentario,
                style:
                    TextStyle(fontSize: 13, color: Colors.grey[800])),
          ],
          if (fecha.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(fecha,
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ],
      ),
    );
  }
}
