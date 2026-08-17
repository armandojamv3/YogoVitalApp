import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yogo_vital_app/core/models/predisenhado_model.dart';
import 'package:yogo_vital_app/core/models/sabor.dart';
import 'package:yogo_vital_app/data/repositories/catalogo_repository.dart';
import 'package:yogo_vital_app/presentation/pages/yogurt/categories/personalizado_page.dart';
import 'package:yogo_vital_app/presentation/pages/yogurt/predisenhado_detail_page.dart';
import 'package:yogo_vital_app/presentation/widgets/custom_bottom_nav_bar.dart';
import 'package:yogo_vital_app/presentation/widgets/imagen_producto.dart';
import 'package:yogo_vital_app/presentation/widgets/sabor_search_delegate.dart';

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
      // El mensaje que ve el usuario es genérico a propósito, pero el error
      // real tiene que quedar en algún lado: sin esto no hay forma de saber
      // si fue la red, RLS, la sesión o un cambio de esquema.
      debugPrint('[YogurtPage] getCatalogSabores falló: $e');
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
    } catch (e) {
      debugPrint('[YogurtPage] getPredisenhados falló: $e');
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
                  // Solo se muestra si se llegó empujando esta pantalla
                  // desde otra (no cuando se abre desde la barra inferior,
                  // que limpia la pila y convierte esta página en raíz).
                  if (Navigator.canPop(context))
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Center(
                      child: Image.asset('assets/images/logo.png', height: 36),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: () => showSearch(
                        context: context, delegate: SaborSearchDelegate()),
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
                  if (s.calificacionPromedio != null)
                    Row(children: [
                      const Icon(Icons.star, size: 12, color: Colors.amber),
                      Text(
                          ' ${s.calificacionPromedio!.toStringAsFixed(1)}',
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
  /// Abre el detalle del prediseñado. Al volver, recarga las reseñas de la
  /// pestaña por si el usuario calificó algo desde ahí.
  void _abrirDetallePred(PredisenhadoModel p) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PredisenhadoDetailPage(predisenhado: p),
      ),
    );
  }

  Widget _buildPredCard(PredisenhadoModel p) {
    return GestureDetector(
      onTap: () => _abrirDetallePred(p),
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
              child: _netImg(p.imagenUrl),
            ),
          ),

          // Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(p.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    if (p.mostrarComoNuevo)
                      _buildMiniBadge('Nuevo', const Color(0xFF2196F3))
                    else if (p.esPopular)
                      _buildMiniBadge('Popular', const Color(0xFFFF9800)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(_cop.format(p.precioTotal),
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
                    // Antes abría un diálogo que agregaba al carrito con
                    // la cantidad. Ya no sirve: desde la migración 0045 el
                    // tamaño es obligatorio y ese diálogo no lo pedía, así
                    // que el pedido moría en el checkout. Se manda al
                    // detalle, que es donde se elige tamaño y cantidad.
                    onPressed: () => _abrirDetallePred(p),
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
      ),
    );
  }

  Widget _buildMiniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
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

  /// Imagen con caché en disco. Antes usaba Image.network, que vuelve a
  /// descargar la foto en cada reconstrucción del widget.
  Widget _netImg(String? url, {double? height}) {
    return ImagenProducto(
      url: url,
      alto: height,
      ancho: double.infinity,
    );
  }
}
