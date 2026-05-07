import 'package:flutter/material.dart';
import 'package:yogo_vital_app/presentation/widgets/custom_bottom_nav_bar.dart';

/// ProductDetailPage muestra los detalles de un producto: imagen, descripción y reseñas.
class ProductDetailPage extends StatefulWidget {
  final String productName;
  final String productDescription;
  final String productImage;

  const ProductDetailPage({
    super.key,
    required this.productName,
    required this.productDescription,
    required this.productImage,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  // Datos mock de reseñas
  final List<Map<String, dynamic>> _reviews = [
    {
      'username': 'Miguel Perez.',
      'verified': true,
      'rating': 5,
      'date': '25 de Sep de 2025',
      'likes': 260,
      'dislikes': 0,
      'review':
          'Hecho desde cero con ingredientes frescos\n\nNuestros Yogures lo hacemos con leche freca directamente del campo. Estos Yogures se elaboran a la necesidad del usuario',
    },
    {
      'username': 'Ana García.',
      'verified': true,
      'rating': 5,
      'date': '20 de Sep de 2025',
      'likes': 145,
      'dislikes': 2,
      'review':
          'Excelente sabor y textura. Muy recomendado para toda la familia. Los ingredientes son de alta calidad.',
    },
    {
      'username': 'Carlos López.',
      'verified': false,
      'rating': 4,
      'date': '15 de Sep de 2025',
      'likes': 98,
      'dislikes': 5,
      'review':
          'Muy bueno, aunque me gustaría que fuera un poco más dulce. De todas formas es un producto excelente.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProductImage(),
                    const SizedBox(height: 20),
                    _buildProductInfo(),
                    const SizedBox(height: 30),
                    _buildReviewsSection(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Barra inferior reutilizable
            const CustomBottomNavBar(currentIndex: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
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
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'Aprender Más',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white, size: 24),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Busqueda proximamente')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage() {
    return Container(
      height: 250,
      color: const Color(0xFFFFA500),
      child: Center(
        child: Image.asset(
          widget.productImage,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.orange[100],
            child: const Icon(Icons.icecream, size: 100, color: Colors.orange),
          ),
        ),
      ),
    );
  }

  Widget _buildProductInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.productName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.productDescription,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            '¿Probaste este Sabor?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ...List.generate(
                5,
                (i) => const Icon(Icons.star, color: Colors.orange, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '¡Cuéntanos qué piensas!',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reseñas de Clientes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ..._reviews.map((r) => _buildReviewCard(r)),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                review['username'],
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (review['verified'])
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 16,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ...List.generate(
                5,
                (index) => Icon(
                  Icons.star,
                  color: index < review['rating'] ? Colors.orange : Colors.grey,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Compra verificada',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review['date'],
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          Text(
            review['review'],
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.thumb_up, color: Colors.grey[600], size: 16),
              const SizedBox(width: 4),
              Text(
                '${review['likes']}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(width: 16),
              Icon(Icons.thumb_down, color: Colors.grey[600], size: 16),
              const SizedBox(width: 4),
              Text(
                '${review['dislikes']}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // bottom navigation is handled by CustomBottomNavBar
}
