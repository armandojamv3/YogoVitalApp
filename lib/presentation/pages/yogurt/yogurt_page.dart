import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yogo_vital_app/core/models/cart_model.dart';
import 'package:yogo_vital_app/core/models/predisenhado_model.dart';
import 'package:yogo_vital_app/core/models/sabor.dart';
import 'package:yogo_vital_app/data/repositories/catalogo_repository.dart';
import 'package:yogo_vital_app/presentation/pages/yogurt/categories/personalizado_page.dart';
import 'package:yogo_vital_app/presentation/widgets/custom_bottom_nav_bar.dart';

class YogurtPage extends StatefulWidget {
  const YogurtPage({super.key});

  @override
  State<YogurtPage> createState() => _YogurtPageState();
}

class _YogurtPageState extends State<YogurtPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _repo = CatalogoRepository();
  final _cop = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  // Típicos
  List<Sabor> _sabores = [];
  bool _loadingTypicals = true;
  String? _errorTypicals;

  // Prediseñados
  List<PredisenhadoModel> _predisenhados = [];
  bool _loadingPred = true;
  String? _errorPred;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTypicals();
    _loadPred();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // HU_08: sabores activos para tab Típicos
  Future<void> _loadTypicals() async {
    try {
      final data = await _repo.getCatalogSabores();
      if (!mounted) return;
      setState(() {
        _sabores = data;
        _loadingTypicals = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorTypicals = 'Error al cargar sabores. Desliza para reintentar.';
        _loadingTypicals = false;
      });
    }
  }

  // HU_09: prediseñados activos
  Future<void> _loadPred() async {
    try {
      final data = await _repo.getPredisenhados();
      if (!mounted) return;
      setState(() {
        _predisenhados = data;
        _loadingPred = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorPred = 'Error al cargar prediseñados.';
        _loadingPred = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F4),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF5B9EF5),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Center(
                      child: Image.asset('assets/images/logo.png', height: 36),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Búsqueda próximamente')),
                    ),
                  ),
                ],
              ),
            ),

            // TabBar
            Container(
              color: const Color(0xFF5B9EF5),
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: 'Típicos'),
                  Tab(text: 'Prediseñados'),
                  Tab(text: 'Personalizado'),
                ],
              ),
            ),

            // Tabs content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // HU_08 — Tab Típicos
                  RefreshIndicator(
                    onRefresh: _loadTypicals,
                    child: _buildTypicalsTab(),
                  ),
                  // HU_09 — Tab Prediseñados
                  RefreshIndicator(
                    onRefresh: _loadPred,
                    child: _buildPredesignedTab(),
                  ),
                  // Tab Personalizados
                  _buildCustomTab(),
                ],
              ),
            ),

            const CustomBottomNavBar(currentIndex: 1),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: Típicos ──────────────────────────────────────────────────────
  Widget _buildTypicalsTab() {
    if (_loadingTypicals) return _buildSkeletonGrid();

    if (_errorTypicals != null) {
      return _buildErrorState(_errorTypicals!, _loadTypicals);
    }

    if (_sabores.isEmpty) {
      return _buildEmptyState('No hay sabores disponibles por ahora.');
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: _sabores.length,
      itemBuilder: (context, i) => _buildSaborGridCard(_sabores[i]),
    );
  }

  Widget _buildSaborGridCard(Sabor s) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/detail', arguments: {
        'saborId': s.id,
        'title': s.nombre,
        'description': s.descripcion,
        'image': s.imagenUrl ?? '',
        'precio': s.precioBase,
        'rating': s.calificacionPromedio,
      }),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Imagen
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                child: _netImg(s.imagenUrl),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(_cop.format(s.precioBase),
                      style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                  Row(children: [
                    const Icon(Icons.star, size: 12, color: Colors.amber),
                    Text(' ${s.calificacionPromedio.toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 11)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 2: Prediseñados ─────────────────────────────────────────────────
  Widget _buildPredesignedTab() {
    if (_loadingPred) return _buildSkeletonGrid();

    if (_errorPred != null) {
      return _buildErrorState(_errorPred!, _loadPred);
    }

    if (_predisenhados.isEmpty) {
      return _buildEmptyState('No hay prediseñados disponibles por ahora.');
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: _predisenhados.length,
      itemBuilder: (context, i) => _buildPredCard(_predisenhados[i]),
    );
  }

  // HU_09: card de prediseñado con badge + ingredientes + botón Seleccionar
  Widget _buildPredCard(PredisenhadoModel p) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Imagen
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: _netImg(p.imagenUrl),
            ),
          ),

          // Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 2),
                Text(_cop.format(p.precio),
                    style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
                if (p.descripcion.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    p.descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 28,
                  child: ElevatedButton(
                    onPressed: () => _showPredDialog(p),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Seleccionar',
                        style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // HU_09: diálogo para confirmar cantidad + agregar al carrito
  Future<void> _showPredDialog(PredisenhadoModel p) async {
    final cart = context.read<CartModel>();
    int qty = 1;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          contentPadding: const EdgeInsets.all(14),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _netImg(p.imagenUrl, height: 130),
                ),
                const SizedBox(height: 10),
                Text(p.nombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                if (p.descripcion.isNotEmpty)
                  Text(p.descripcion,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Text(_cop.format(p.precio),
                    style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => setS(() { if (qty > 1) qty--; }),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$qty',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(
                      onPressed: () => setS(() => qty++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cerrar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50)),
              child: const Text('Agregar',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      cart.addItem(CartItem(
        id: 'pred_${p.id}',
        title: p.nombre,
        price: p.precio.round(),
        image: p.imagenUrl ?? '',
        size: 'Prediseñado',
        qty: qty,
      ));
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      final controller = messenger.showSnackBar(
        SnackBar(
          content: Text('${p.nombre} agregado al carrito'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
      Future.delayed(const Duration(seconds: 3), controller.close);
    }
  }

  // ── Tab 3: Personalizados ───────────────────────────────────────────────
  Widget _buildCustomTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.emoji_food_beverage,
                      size: 72, color: Color(0xFF5B9EF5)),
                  const SizedBox(height: 16),
                  const Text(
                    '¡Crea tu yogurt!',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Elige tamaño, sabor base, frutas, extras y nivel de azúcar a tu gusto.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PersonalizadoPage()),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B9EF5),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Personalizar ahora',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers UI ───────────────────────────────────────────────────────────

  // HU_08: skeleton grid de carga
  Widget _buildSkeletonGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  // HU_08: estado vacío amigable
  Widget _buildEmptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.icecream_outlined,
                size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String msg, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _netImg(String? url, {double? height}) {
    if (url == null || url.isEmpty) {
      return Container(
        height: height,
        color: Colors.orange[100],
        child: const Center(
          child: Icon(Icons.icecream, color: Colors.orange, size: 40),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        height: height,
        color: const Color(0xFFE0E0E0),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        height: height,
        color: Colors.orange[100],
        child: const Center(
          child: Icon(Icons.icecream, color: Colors.orange, size: 40),
        ),
      ),
    );
  }
}
