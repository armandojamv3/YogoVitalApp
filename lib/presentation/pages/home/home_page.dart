import 'package:flutter/material.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  // Lista de imágenes del carrusel (puedes agregar más)
  final List<String> _bannerImages = [
    'assets/images/Coco.png', // Crea estas imágenes o usa placeholders
    'assets/images/Chontaduro.png',
    'assets/images/imgChontaduro.jng',
  ];

  @override
  void initState() {
    super.initState();
    // Auto-scroll cada 3 segundos
    _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (_currentPage < _bannerImages.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeIn,
        );
      }
    });
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER CON LOGO Y BÚSQUEDA
            _buildHeader(),

            // CONTENIDO CON SCROLL
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CARRUSEL DE BANNERS
                    _buildCarousel(),

                    const SizedBox(height: 20),

                    // SECCIÓN "SABORES NUEVOS"
                    _buildNewFlavorsSection(),
                  ],
                ),
              ),
            ),

            // BARRA DE NAVEGACIÓN INFERIOR (reutilizable)
            // Usamos CustomBottomNavBar con índice 0 (Home)
            const CustomBottomNavBar(currentIndex: 0),
          ],
        ),
      ),
    );
  }

  // HEADER CON LOGO Y BÚSQUEDA
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF5B9EF5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Image.asset('assets/images/logo.png', height: 40),
          // Ícono de búsqueda
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white, size: 28),
            onPressed: () {
              print('Buscar');
            },
          ),
        ],
      ),
    );
  }

  // CARRUSEL DE IMÁGENES
  Widget _buildCarousel() {
    return SizedBox(
      height: 200,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (int page) {
          setState(() {
            _currentPage = page;
          });
        },
        itemCount: _bannerImages.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.grey[300],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.asset(
                _bannerImages[index],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Placeholder si no existe la imagen
                  return Container(
                    color: const Color(0xFFFFF4E6),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/images/logo.png', height: 60),
                          const SizedBox(height: 10),
                          Text(
                            'Banner ${index + 1}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5B9EF5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // SECCIÓN "SABORES NUEVOS"
  Widget _buildNewFlavorsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sabores Nuevos',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),

          // LISTA DE PRODUCTOS
          _buildProductCard(
            'Yogurt de Chontaduro\nsabor a miel.',
            'Disfruta de esta combinación única de sabores tropicales.',
            'assets/images/yogurt_chontaduro.jpg',
          ),

          const SizedBox(height: 20),

          _buildProductCard(
            'Yogurt de Borojo y\nChontaduro sabor a miel.',
            'Una mezcla exótica y deliciosa para tu paladar.',
            'assets/images/yogurt_borojo.jpg',
          ),

          const SizedBox(height: 20),

          _buildProductCard(
            'Yogurt de Coco\ny Maracuyá.',
            'Refrescante y tropical, perfecto para cualquier momento.',
            'assets/images/yogurt_coco.jpg',
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // TARJETA DE PRODUCTO
  Widget _buildProductCard(String title, String description, String imagePath) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen del producto
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              imagePath,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // Placeholder si no existe la imagen
                return Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.icecream,
                    size: 50,
                    color: Colors.orange,
                  ),
                );
              },
            ),
          ),

          const SizedBox(width: 15),

          // Información del producto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    print('Ver más: $title');
                  },
                  child: const Text(
                    'Aprende Más >',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF5B9EF5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Note: bottom navigation moved to a reusable CustomBottomNavBar widget.
}
