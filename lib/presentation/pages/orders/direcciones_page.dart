import 'package:flutter/material.dart';
import 'package:yogo_vital_app/core/models/direccion_model.dart';
import 'package:yogo_vital_app/data/repositories/pedido_supabase_repository.dart';

/// HU_24 + HU_25: Pantalla para gestionar y seleccionar direcciones.
///
/// Modo selector ([isSelector] = true): cuando se abre desde ResumenPedidoPage,
/// muestra botón "Usar esta" en cada dirección y retorna la elegida via pop().
///
/// Modo gestión ([isSelector] = false): accesible desde la cuenta del usuario.
class DireccionesPage extends StatefulWidget {
  final bool isSelector;
  const DireccionesPage({super.key, this.isSelector = false});

  @override
  State<DireccionesPage> createState() => _DireccionesPageState();
}

class _DireccionesPageState extends State<DireccionesPage> {
  final _repo = PedidoSupabaseRepository();

  List<DireccionModel> _dirs = [];
  bool _loading = true;
  String? _error;

  // form state
  bool _showForm = false;
  final _dirCtrl = TextEditingController();
  final _barrioCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _dirCtrl.dispose();
    _barrioCtrl.dispose();
    _telCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final dirs = await _repo.getDirecciones();
      if (!mounted) return;
      setState(() { _dirs = dirs; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Error al cargar direcciones'; _loading = false; });
    }
  }

  /// HU_24: guardar nueva dirección
  Future<void> _saveNew() async {
    final dir = _dirCtrl.text.trim();
    final barrio = _barrioCtrl.text.trim();
    final tel = _telCtrl.text.trim();

    if (dir.isEmpty || barrio.isEmpty || tel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final nueva = await _repo.addDireccion(
          direccion: dir, barrio: barrio, telefono: tel);
      if (!mounted) return;
      setState(() {
        _dirs.insert(0, nueva);
        _showForm = false;
        _dirCtrl.clear();
        _barrioCtrl.clear();
        _telCtrl.clear();
        _saving = false;
      });
      if (widget.isSelector) Navigator.pop(context, nueva);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al guardar dirección')),
      );
    }
  }

  /// HU_25: marcar como principal
  Future<void> _setPrincipal(DireccionModel d) async {
    try {
      await _repo.setPrincipal(d.id);
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Error al actualizar')));
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF5B9EF5),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Mis Direcciones',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _showForm ? Icons.close : Icons.add,
                      color: Colors.white,
                    ),
                    onPressed: () =>
                        setState(() => _showForm = !_showForm),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Formulario nueva dirección
                          if (_showForm) _buildForm(),

                          if (_error != null)
                            _buildError()
                          else if (_dirs.isEmpty && !_showForm)
                            _buildEmpty()
                          else
                            ..._dirs.map(_buildDirCard),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFF5B9EF5).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nueva dirección',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          _field(_dirCtrl, 'Dirección (calle/carrera/número)', Icons.location_on),
          const SizedBox(height: 10),
          _field(_barrioCtrl, 'Barrio', Icons.map_outlined),
          const SizedBox(height: 10),
          _field(_telCtrl, 'Teléfono de contacto', Icons.phone,
              type: TextInputType.phone),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _saveNew,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B9EF5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Guardar',
                      style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _buildDirCard(DireccionModel d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: d.esPrincipal
            ? Border.all(color: const Color(0xFF4CAF50), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on,
                  size: 18, color: Color(0xFF5B9EF5)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(d.etiqueta,
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
              ),
              if (d.esPrincipal)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Principal',
                      style: TextStyle(
                          color: Colors.white, fontSize: 10)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text('📞 ${d.telefono}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!d.esPrincipal)
                TextButton(
                  onPressed: () => _setPrincipal(d),
                  child: const Text('Marcar principal',
                      style: TextStyle(fontSize: 12)),
                ),
              if (widget.isSelector)
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, d),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B9EF5),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Usar esta',
                      style: TextStyle(
                          color: Colors.white, fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 32),
            const Icon(Icons.location_off, size: 52, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('No tienes direcciones guardadas',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => setState(() => _showForm = true),
              icon: const Icon(Icons.add),
              label: const Text('Agregar dirección'),
            ),
          ],
        ),
      );

  Widget _buildError() => Center(
        child: Column(
          children: [
            Text(_error!, style: const TextStyle(color: Colors.grey)),
            TextButton(
                onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
}
