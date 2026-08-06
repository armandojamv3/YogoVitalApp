import 'package:flutter/material.dart';
import 'package:yogo_vital_app/core/services/user_role_service.dart';

/// Pantalla principal del módulo administrador — Sprint 6 (RNF08).
/// Solo accesible si rol == 'administrador'.
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _checking = true;

  static const _blue = Color(0xFF5B9EF5);
  static const _teal = Color(0xFF0E8498);

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final isAdmin = await UserRoleService.isAdmin();
    if (!mounted) return;
    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Acceso restringido: solo administradores'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pushReplacementNamed('/home');
      return;
    }
    setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Módulos de administración',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ModuleCard(
                    icon: Icons.icecream_rounded,
                    title: 'Gestión de Sabores',
                    subtitle: 'Agregar, editar y eliminar sabores del catálogo',
                    color: _blue,
                    onTap: () => Navigator.pushNamed(context, '/admin/sabores'),
                  ),
                  const SizedBox(height: 14),
                  _ModuleCard(
                    icon: Icons.apple_rounded,
                    title: 'Frutas y Extras',
                    subtitle: 'Administrar ingredientes adicionales',
                    color: _teal,
                    onTap: () =>
                        Navigator.pushNamed(context, '/admin/frutas-extras'),
                  ),
                  const SizedBox(height: 14),
                  _ModuleCard(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Prediseñados',
                    subtitle: 'Crear y editar combos de yogur prediseñados',
                    color: const Color(0xFF7E57C2),
                    onTap: () =>
                        Navigator.pushNamed(context, '/admin/predisenhados'),
                  ),
                  const SizedBox(height: 14),
                  _ModuleCard(
                    icon: Icons.receipt_long_rounded,
                    title: 'Pedidos',
                    subtitle: 'Ver y actualizar estado de pedidos',
                    color: const Color(0xFF9C27B0),
                    onTap: () => Navigator.pushNamed(context, '/admin'),
                  ),
                  const SizedBox(height: 14),
                  _ModuleCard(
                    icon: Icons.local_offer_rounded,
                    title: 'Promociones',
                    subtitle: 'Publicar y gestionar promociones para clientes',
                    color: const Color(0xFFFF9800),
                    onTap: () =>
                        Navigator.pushNamed(context, '/admin/promociones'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A8FE7), _blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Panel Administrador',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'ADMIN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        color: Color(0xFF6B6B7B), fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
