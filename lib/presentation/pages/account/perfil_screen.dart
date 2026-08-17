import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/core/models/user_model.dart';
import 'package:yogo_vital_app/data/repositories/perfil_repository.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _repo = PerfilRepository();
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _contrasenaActualCtrl = TextEditingController();
  final _nuevaContrasenaCtrl = TextEditingController();
  final _confirmarContrasenaCtrl = TextEditingController();

  UserModel? _perfil;
  bool _loading = true;
  bool _saving = false;
  bool _changingPassword = false;
  String? _error;

  static const _blue = Color(0xFF5B9EF5);
  static const _teal = Color(0xFF0E8498);

  @override
  void initState() {
    super.initState();
    _loadPerfil();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _contrasenaActualCtrl.dispose();
    _nuevaContrasenaCtrl.dispose();
    _confirmarContrasenaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPerfil() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final perfil = await _repo.getPerfil();
      _nombreCtrl.text = perfil.nombre;
      _telefonoCtrl.text = perfil.telefono ?? '';
      setState(() {
        _perfil = perfil;
        _loading = false;
      });
    } on PerfilException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _repo.updatePerfil(
        nombre: _nombreCtrl.text,
        telefono: _telefonoCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(child: Text('Perfil actualizado correctamente')),
            ],
          ),
          backgroundColor: Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
      );
      Navigator.pop(context, true);
    } on PerfilException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cambiarContrasena() async {
    final nueva = _nuevaContrasenaCtrl.text;
    final confirmar = _confirmarContrasenaCtrl.text;

    if (nueva.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La nueva contraseña debe tener al menos 6 caracteres'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (nueva != confirmar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las contraseñas no coinciden'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _changingPassword = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: nueva),
      );
      if (!mounted) return;
      _contrasenaActualCtrl.clear();
      _nuevaContrasenaCtrl.clear();
      _confirmarContrasenaCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(child: Text('Contraseña actualizada correctamente')),
            ],
          ),
          backgroundColor: Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cambiar la contraseña: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: const BoxDecoration(color: _blue),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Editar Perfil',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              TextButton(
                  onPressed: _loadPerfil, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Avatar
            const SizedBox(height: 8),
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: _blue.withValues(alpha: 0.3), width: 2),
              ),
              child: const Icon(Icons.person, size: 50, color: _blue),
            ),
            const SizedBox(height: 24),

            // Correo (solo lectura)
            _buildReadonlyField(
              label: 'Correo electrónico',
              value: _perfil?.correo ?? '',
              icon: Icons.email_outlined,
            ),
            const SizedBox(height: 16),

            // Nombre (editable)
            _buildLabel('Nombre *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nombreCtrl,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration('Tu nombre completo', Icons.person_outline),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'El nombre es obligatorio';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Teléfono (editable)
            _buildLabel('Teléfono *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _telefonoCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              decoration: _inputDecoration('Ej: 3001234567', Icons.phone_outlined),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'El teléfono es obligatorio';
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Botón guardar
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text(
                        'Guardar cambios',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),

            // ── Sección Seguridad ──────────────────────────────
            const SizedBox(height: 32),
            const Divider(thickness: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.lock_outline, size: 18, color: _blue),
                const SizedBox(width: 8),
                const Text(
                  'Seguridad',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333344),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Contraseña actual
            _buildLabel('Contraseña actual'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _contrasenaActualCtrl,
              obscureText: true,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration('Contraseña actual', Icons.lock_outline),
            ),
            const SizedBox(height: 16),

            // Nueva contraseña
            _buildLabel('Nueva contraseña'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nuevaContrasenaCtrl,
              obscureText: true,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration('Mínimo 6 caracteres', Icons.lock_reset),
            ),
            const SizedBox(height: 16),

            // Confirmar nueva contraseña
            _buildLabel('Confirmar nueva contraseña'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _confirmarContrasenaCtrl,
              obscureText: true,
              textInputAction: TextInputAction.done,
              decoration: _inputDecoration('Repite la nueva contraseña', Icons.lock_reset),
            ),
            const SizedBox(height: 24),

            // Botón cambiar contraseña
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: _changingPassword ? null : _cambiarContrasena,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _blue,
                  side: const BorderSide(color: _blue, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _changingPassword
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: _blue),
                      )
                    : const Text(
                        'Cambiar contraseña',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildReadonlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey[500]),
              const SizedBox(width: 10),
              // Expanded + ellipsis: un correo largo se salía de la caja y
              // Flutter marcaba el desbordamiento. Con Spacer el texto tenía
              // tamaño fijo y no cedía nada.
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600], fontSize: 15),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.lock_outline, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF333344),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      prefixIcon: Icon(icon, color: _blue, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _blue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }
}
