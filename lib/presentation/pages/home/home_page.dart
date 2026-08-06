import 'dart:async';
import 'package:flutter/material.dart';
import 'package:yogo_vital_app/core/models/promedio_calificacion.dart';
import 'package:yogo_vital_app/core/models/sabor.dart';
import 'package:yogo_vital_app/data/repositories/calificacion_supabase_repository.dart';
import 'package:yogo_vital_app/data/repositories/catalogo_repository.dart';
import 'package:yogo_vital_app/presentation/widgets/custom_bottom_nav_bar.dart';
import 'package:yogo_vital_app/presentation/widgets/favorite_button.dart';
import 'package:yogo_vital_app/presentation/widgets/notification_bell.dart';
import 'package:yogo_vital_app/presentation/widgets/sabor_search_delegate.dart';
import 'package:yogo_vital_app/presentation/widgets/star_rating_display.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // --- Carousel ---
  final _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  static const _bannerImages = [
    'assets/images/Coco.png',
    'assets/images/Chontaduro.png',
    'assets/images/ImgChontaduro.png',
  ];

  // --- Supabase data ---
  final _repo = CatalogoRepository();
  final _calificacionRepo = CalificacionSupabaseRepository();
  List<Sabor> _nuevos = [];
  List<Sabor> _masPedidos = [];
  Map<String, PromedioCalificacion> _promedios = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCarousel();
    _loadData();
  }

  void _startCarousel() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_currentPage + 1) % _bannerImages.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeIn,
      );
    });
  }

  // HU_07: cargar sabores + promedios live de calificaciones (Sprint 7)
  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _repo.getSaboresHome(limit: 10),
        _calificacionRepo.getPromediosPorSabores(),
      ]);
      if (!mounted) return;
      final sabores = results[0] as List<Sabor>;
      final promedios =
          results[1] as Map<String, PromedioCalificacion>;
      setState(() {
        _nuevos = sabores;
        _promedios = promedios;
        _masPedidos = List<Sabor>.from(sabores)
          ..sort((a, b) =>
              b.calificacionPromedio.compareTo(a.calificacionPromedio));
        if (_masPedidos.length > 3) _masPedidos = _masPedidos.sublist(0, 3);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los productos';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F4),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Container(
                color: const Color(0xFFF2A654),
                child: RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Carrusel
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 18, 16, 8),
                          child: _buildCarousel(),
                        ),

                        // Indicadores del carrusel
                        _buildPageIndicator(),

                        const SizedBox(height: 18),

                        // Sección "Sabores Nuevos"
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          child: const Text(
                            'Sabores Nuevos',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6B3A0D),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildHorizontalList(_nuevos),

                        const SizedBox(height: 24),

                        // Sección "Más Pedidos"
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          child: const Text(
                            'Más Pedidos',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6B3A0D),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildVerticalList(_masPedidos),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const CustomBottomNavBar(currentIndex: 0),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF5B9EF5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset('assets/images/logo.png', height: 40),
          Row(
            children: [
              const NotificationBell(),
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white, size: 28),
                onPressed: () =>
                    showSearch(context: context, delegate: SaborSearchDelegate()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Carrusel ─────────────────────────────────────────────────────────────
  Widget _buildCarousel() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: PageView.builder(
          controller: _pageController,
          itemCount: _bannerImages.length,
          onPageChanged: (p) => setState(() => _currentPage = p),
          itemBuilder: (context, index) => Image.asset(
            _bannerImages[index],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFFFFF4E6),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/logo.png', height: 60),
                    const SizedBox(height: 8),
                    Text(
                      'Yogo Vital',
                      style: TextStyle(
                        color: const Color(0xFF5B9EF5),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _bannerImages.length,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          width: _currentPage == i ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentPage == i
                ? const Color(0xFF6B3A0D)
                : Colors.brown.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  // ── Listas de sabores ────────────────────────────────────────────────────

  // HU_07: cards horizontales desplazables
  Widget _buildHorizontalList(List<Sabor> items) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(_error!,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      );
    }

    // Skeleton mientras carga
    final count = _loading ? 4 : (items.isEmpty ? 1 : items.length);

    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20, right: 8),
        itemCount: count,
        itemBuilder: (context, index) {
          if (_loading) return _buildSaborSkeleton();
          if (items.isEmpty) return _buildEmptyCard('Sin sabores disponibles');
          return _buildSaborCard(items[index]);
        },
      ),
    );
  }

  // HU_07: lista vertical "Más Pedidos"
  Widget _buildVerticalList(List<Sabor> items) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: List.generate(2, (_) => _buildMasPedidosSkeleton()),
        ),
      );
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: items
            .map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildMasPedidosCard(s),
                ))
            .toList(),
      ),
    );
  }

  // ── Card sabor horizontal (Nuevos Sabores) ──────────────────────────────
  Widget _buildSaborCard(Sabor s) {
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
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: _buildNetworkImage(s.imagenUrl,
                      width: 160, height: 110),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: FavoriteButton(saborId: s.id, size: 18),
                ),
              ],
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${s.precioBase.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  StarRatingDisplay(
                    promedio: _promedios[s.id]?.promedio ??
                        s.calificacionPromedio,
                    total: _promedios[s.id]?.total,
                    starSize: 13,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Aprender más >',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF5B9EF5),
                      fontWeight: FontWeight.w600,
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

  // ── Card "Más Pedidos" (vertical) ────────────────────────────────────────
  Widget _buildMasPedidosCard(Sabor s) {
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _buildNetworkImage(s.imagenUrl,
                      width: 85, height: 85),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: FavoriteButton(saborId: s.id, size: 16),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.nombre,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                    s.descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('\$${s.precioBase.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w600)),
                      StarRatingDisplay(
                        promedio: _promedios[s.id]?.promedio ??
                            s.calificacionPromedio,
                        total: _promedios[s.id]?.total,
                        starSize: 13,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Aprender más >',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5B9EF5),
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Skeletons de carga ────────────────────────────────────────────────────
  Widget _buildSaborSkeleton() {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            height: 110,
            decoration: const BoxDecoration(
              color: Color(0xFFE0E0E0),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 12, width: 100,
                    color: const Color(0xFFE0E0E0)),
                const SizedBox(height: 6),
                Container(height: 10, width: 60,
                    color: const Color(0xFFE0E0E0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasPedidosSkeleton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 85,
            decoration: const BoxDecoration(
              color: Color(0xFFE0E0E0),
              borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(14)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 12, width: 120,
                    color: const Color(0xFFE0E0E0)),
                const SizedBox(height: 8),
                Container(height: 10, width: 80,
                    color: const Color(0xFFE0E0E0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String msg) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(msg,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70)),
    );
  }

  // ── Imagen con red o placeholder ─────────────────────────────────────────
  Widget _buildNetworkImage(String? url,
      {required double width, required double height}) {
    if (url == null || url.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: Colors.orange[100],
        child: Icon(Icons.icecream,
            size: height * 0.5, color: Colors.orange),
      );
    }
    return Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: width,
          height: height,
          color: const Color(0xFFE0E0E0),
          child:
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (_, __, ___) => Container(
        width: width,
        height: height,
        color: Colors.orange[100],
        child: Icon(Icons.icecream,
            size: height * 0.5, color: Colors.orange),
      ),
    );
  }
}
