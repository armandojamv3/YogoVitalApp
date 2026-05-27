import 'package:flutter/material.dart';
// Usamos Provider para leer servicios y modelos de estado desde el árbol
import 'package:provider/provider.dart';
// Repo que maneja autenticación (almacenamiento del JWT, logout)
import 'package:yogo_vital_app/data/repositories/auth_repository.dart';
// Modelo de carrito para limpiar el estado al cerrar sesión
import 'package:yogo_vital_app/core/models/cart_model.dart';
import 'package:yogo_vital_app/presentation/widgets/custom_bottom_nav_bar.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F4),
      body: SafeArea(
        child: Column(
          children: [
            // Header azul con título centrado (texto Volver a la izquierda)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: const BoxDecoration(color: Color(0xFF5B9EF5)),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Text(
                      '< Volver',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Perfil',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Georgia',
                        ),
                      ),
                    ),
                  ),
                  // edit icon in rounded box
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Avatar y nombre
            Column(
              children: [
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black12, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.person, size: 72, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Carlos Meneses',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Georgia',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Colombia, Cali',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Tarjeta con billetera / ordenes (estilizada)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0E8498),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 18,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              '\$0.0',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFamily: 'Georgia',
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Billetera',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(width: 1, height: 72, color: Colors.white24),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 18,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: const [
                            Text(
                              '1',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Ordenes',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Opciones
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 8),
                  _buildOptionRow(Icons.favorite_border, 'Tus Favoritos'),
                  const SizedBox(height: 12),
                  _buildOptionRow(Icons.payments_outlined, 'Pagos'),
                  const SizedBox(height: 12),
                  _buildOptionRow(Icons.local_offer_outlined, 'Promociones'),
                  const SizedBox(height: 12),
                  _buildOptionRow(Icons.settings_outlined, 'Configuracion'),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Cerrar sesión
                  GestureDetector(
                    onTap: () async {
                      // Pasos al cerrar sesión:
                      // 1) Llamar a `AuthRepository.logout()` para borrar el token local
                      // 2) Limpiar estados locales como el carrito (`CartModel.clear()`)
                      // 3) Navegar a la pantalla de login y eliminar el historial
                      // Todo esto protege datos personales y evita volver atrás con el botón "atrás".
                      try {
                        final repo = context.read<AuthRepository>();
                        // Borra token y datos de sesión en almacenamiento seguro
                        await repo.logout();

                        // Intentamos limpiar el carrito u otros modelos; si fallan, lo ignoramos
                        try {
                          final cart = context.read<CartModel>();
                          cart.clear();
                        } catch (_) {}

                        if (!context.mounted) return;
                        // Navega a login y elimina toda la pila de rutas anteriores
                        Navigator.pushNamedAndRemoveUntil(
                            context, '/login', (route) => false);
                      } catch (e) {
                        // Mostrar un mensaje amigable si algo sale mal
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error cerrando sesión: $e'),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.logout, size: 22),
                          SizedBox(width: 12),
                          Text(
                            'Cierra Sesion',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 60),
                ],
              ),
            ),

            // Bottom nav
            const CustomBottomNavBar(currentIndex: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionRow(IconData icon, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black87),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
