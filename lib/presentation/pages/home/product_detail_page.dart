import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/core/models/cart_model.dart';
import 'package:yogo_vital_app/core/models/tamano_model.dart';
import 'package:yogo_vital_app/core/providers/pedido_provider.dart' show kNivelesDulzura;
import 'package:yogo_vital_app/data/repositories/personalizacion_repository.dart';
import 'package:yogo_vital_app/presentation/pages/cart/cart_checkout_page.dart';
import 'package:yogo_vital_app/presentation/widgets/custom_bottom_nav_bar.dart';
import 'package:yogo_vital_app/presentation/widgets/favorite_button.dart';
import 'package:yogo_vital_app/presentation/widgets/imagen_producto.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final _db = Supabase.instance.client;
  final _catalogo = PersonalizacionRepository();
  final _cop =
      NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  List<Map<String, dynamic>> _reviews = [];
  bool _loadingReviews = true;

  /// Tamaños del catálogo. Un yogur típico ya viene con su sabor definido:
  /// lo único que elige el cliente es el tamaño y la dulzura.
  List<TamanoModel> _tamanos = [];
  TamanoModel? _tamano;
  bool _cargandoTamanos = true;

  String _dulzura = 'Normal';

  /// El precio lo manda el tamaño, igual que en el personalizado. El
  /// `precio_base` del sabor queda como referencia del catálogo, pero no es
  /// lo que se cobra.
  /// Recargo del sabor, leído de los argumentos de la ruta.
  ///
  /// Viaja en el mapa igual que el título o la imagen, en vez de volver a
  /// consultar el sabor: la pantalla anterior ya lo tenía cargado.
  double _recargo = 0;

  double get _precio => (_tamano?.precioBase ?? 0) + _recargo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReviews());
    _cargarTamanos();
  }

  Future<void> _cargarTamanos() async {
    try {
      final tamanos = await _catalogo.getTamanos();
      if (!mounted) return;
      setState(() {
        _tamanos = tamanos;
        // Se preselecciona el primero (el más económico): así el cliente
        // que no quiera cambiar nada puede comprar directo, sin bloqueos.
        _tamano = tamanos.isNotEmpty ? tamanos.first : null;
        _cargandoTamanos = false;
      });
    } catch (e) {
      debugPrint('[ProductDetail] No se pudieron cargar los tamaños: $e');
      if (!mounted) return;
      setState(() => _cargandoTamanos = false);
    }
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
    _recargo = (args?['recargo'] as num?)?.toDouble() ?? 0;
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
                          child: ImagenProducto(
                            url: image,
                            alto: 200,
                            ancho: double.infinity,
                            tamanoIcono: 80,
                          ),
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

                      const SizedBox(height: 8),

                      // Tamaño y dulzura: lo único configurable en un yogur
                      // típico. Las frutas y los extras pertenecen al
                      // personalizador — si aquí dice Piña, es de piña.
                      _buildTamanos(),
                      const SizedBox(height: 12),
                      _buildDulzura(),

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

  // ── Tamaño ───────────────────────────────────────────────────────────────
  Widget _buildTamanos() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tamaño',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF6B3A0D))),
          const SizedBox(height: 10),
          if (_cargandoTamanos)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_tamanos.isEmpty)
            const Text('No se pudieron cargar los tamaños.',
                style: TextStyle(fontSize: 13, color: Colors.grey))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tamanos.map(_buildChipTamano).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildChipTamano(TamanoModel t) {
    final elegido = _tamano?.id == t.id;
    return GestureDetector(
      onTap: () => setState(() => _tamano = t),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: elegido ? const Color(0xFF5B9EF5) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: elegido ? const Color(0xFF5B9EF5) : Colors.grey[300]!,
            width: elegido ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.nombre,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: elegido ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              // El precio FINAL con ese tamaño, recargo del sabor incluido,
              // no el del tamaño suelto.
              //
              // Mostrar el del tamaño a secas dejaba al cliente con dos
              // números que no cuadraban: la tarjeta decía $5.000 y el
              // botón de abajo $6.500, sin nada que explicara la
              // diferencia. Es el mismo criterio que ya usan los
              // prediseñados.
              _cop.format(t.precioBase + _recargo),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: elegido ? Colors.white70 : const Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dulzura ──────────────────────────────────────────────────────────────
  Widget _buildDulzura() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dulzura',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF6B3A0D))),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kNivelesDulzura.map((nivel) {
              final elegido = _dulzura == nivel;
              return GestureDetector(
                onTap: () => setState(() => _dulzura = nivel),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: elegido ? const Color(0xFF4CAF50) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: elegido
                          ? const Color(0xFF4CAF50)
                          : Colors.grey[300]!,
                      width: elegido ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    nivel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: elegido ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
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
      // Antes eran dos botones con el mismo peso y sus dos etiquetas. En
      // pantallas estrechas "Pedir ahora" no cabía, se partía en dos líneas
      // y se recortaba contra los 48 px de alto.
      //
      // Ahora "Agregar" queda como acción secundaria, solo con su icono, y
      // "Pedir ahora" se lleva el ancho restante. Es el mismo patrón que la
      // pantalla de detalle de prediseñado, así que las dos se comportan
      // igual.
      child: Row(
        children: [
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () => _agregarAlCarrito(args),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5B9EF5),
                side: const BorderSide(color: Color(0xFF5B9EF5), width: 1.6),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Icon(Icons.add_shopping_cart, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => _pedirAhora(args),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B9EF5),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bolt, size: 20, color: Colors.white),
                    const SizedBox(width: 6),
                    const Flexible(
                      child: Text(
                        'Pedir ahora',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // El precio del tamaño elegido, para que se vea lo que
                    // se va a pagar antes de entrar al checkout.
                    if (_tamano != null) ...[
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          _cop.format(_precio),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ítem de carrito para este yogur típico, con el tamaño y la dulzura
  /// que eligió el cliente.
  CartItem _comoCartItem(Map<String, dynamic>? args) => CartItem(
        id: args?['saborId']?.toString() ?? '',
        title: args?['title']?.toString() ?? 'Yogur',
        // El precio manda el tamaño, no el precio_base del sabor. Es solo
        // para mostrar: el importe real lo calcula la RPC crear_pedido.
        price: _precio.round(),
        image: args?['image']?.toString() ?? '',
        size: _tamano?.nombre ?? '',
        tamanoId: _tamano?.id ?? '',
        dulzura: _dulzura,
        tipo: 'personalizado',
      );

  void _agregarAlCarrito(Map<String, dynamic>? args) {
    final cart = context.read<CartModel>();
    cart.addItem(_comoCartItem(args));

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

  /// Compra directa del típico: va al checkout con este ítem.
  ///
  /// Antes llevaba al personalizador completo, con su selector de sabor,
  /// sus frutas y sus extras. No tenía sentido: un yogur típico ya viene
  /// hecho — si dice Piña, es de piña. Lo único que el cliente decide es el
  /// tamaño y la dulzura, y eso ya se elige en esta misma pantalla.
  void _pedirAhora(Map<String, dynamic>? args) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartCheckoutPage(itemsDirectos: [_comoCartItem(args)]),
      ),
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
