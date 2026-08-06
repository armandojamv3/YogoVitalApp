import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yogo_vital_app/core/models/promocion.dart';
import 'package:yogo_vital_app/core/services/user_role_service.dart';
import 'package:yogo_vital_app/data/repositories/promociones_repository.dart';

const _kPrimary = Color(0xFF5B9EF5);
const _kAccent = Color(0xFFFF9800);
const _kBg = Color(0xFFF5F7FA);
const _kDanger = Color(0xFFEF5350);
const _kSuccess = Color(0xFF4CAF50);

/// Panel admin: crear/editar/activar/eliminar promociones (Sprint —
/// funcionalidad de "Promociones" del menú de Cuenta).
class AdminPromocionesPage extends StatefulWidget {
  const AdminPromocionesPage({super.key});

  @override
  State<AdminPromocionesPage> createState() => _AdminPromocionesPageState();
}

class _AdminPromocionesPageState extends State<AdminPromocionesPage> {
  final _repo = PromocionesRepository();
  bool _checking = true;
  bool _loading = true;
  String? _error;
  List<Promocion> _promos = [];

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
          backgroundColor: _kDanger,
        ),
      );
      Navigator.of(context).pushReplacementNamed('/home');
      return;
    }
    setState(() => _checking = false);
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final promos = await _repo.getTodas();
      if (!mounted) return;
      setState(() {
        _promos = promos;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: isError ? _kDanger : _kSuccess,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _abrirFormulario({Promocion? promo}) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _PromocionFormPage(promoAEditar: promo),
      ),
    );
    if (ok == true) _cargar();
  }

  Future<void> _toggleActiva(Promocion p) async {
    try {
      await _repo.toggleActiva(p.id, !p.activa);
      _cargar();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
  }

  Future<void> _eliminar(Promocion p) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('¿Eliminar promoción?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('¿Eliminar "${p.titulo}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kDanger),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    try {
      await _repo.eliminar(p.id);
      _cargar();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        backgroundColor: _kAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva promoción',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A8FE7), _kPrimary],
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
              'Gestión de Promociones',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('ADMIN',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 56, color: _kDanger),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_error!, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (_promos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_offer_outlined, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No hay promociones registradas',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Toca el botón + para crear la primera',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _promos.length,
        itemBuilder: (ctx, i) => _PromocionCard(
          promo: _promos[i],
          onEdit: () => _abrirFormulario(promo: _promos[i]),
          onDelete: () => _eliminar(_promos[i]),
          onToggle: () => _toggleActiva(_promos[i]),
        ),
      ),
    );
  }
}

class _PromocionCard extends StatelessWidget {
  final Promocion promo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _PromocionCard({
    required this.promo,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(promo.titulo,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (promo.vigente ? _kSuccess : Colors.grey)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  promo.vigente ? 'Vigente' : (promo.activa ? 'Programada/expirada' : 'Inactiva'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: promo.vigente ? _kSuccess : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(promo.descripcion, style: const TextStyle(color: Color(0xFF6B6B7B))),
          const SizedBox(height: 8),
          Text(
            promo.fechaFin != null
                ? '${fmt.format(promo.fechaInicio.toLocal())} — ${fmt.format(promo.fechaFin!.toLocal())}'
                : 'Desde ${fmt.format(promo.fechaInicio.toLocal())} (sin fecha fin)',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: onToggle,
                icon: Icon(
                    promo.activa ? Icons.visibility_off : Icons.visibility,
                    size: 18),
                label: Text(promo.activa ? 'Desactivar' : 'Activar'),
              ),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, color: _kPrimary),
                tooltip: 'Editar',
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, color: _kDanger),
                tooltip: 'Eliminar',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Formulario crear/editar
// ─────────────────────────────────────────────────────────────────────────
class _PromocionFormPage extends StatefulWidget {
  final Promocion? promoAEditar;
  const _PromocionFormPage({this.promoAEditar});

  @override
  State<_PromocionFormPage> createState() => _PromocionFormPageState();
}

class _PromocionFormPageState extends State<_PromocionFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = PromocionesRepository();
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _descCtrl;
  DateTime _fechaInicio = DateTime.now();
  DateTime? _fechaFin;
  bool _saving = false;
  String? _error;

  bool get _esEdicion => widget.promoAEditar != null;

  @override
  void initState() {
    super.initState();
    final p = widget.promoAEditar;
    _tituloCtrl = TextEditingController(text: p?.titulo ?? '');
    _descCtrl = TextEditingController(text: p?.descripcion ?? '');
    if (p != null) {
      _fechaInicio = p.fechaInicio;
      _fechaFin = p.fechaFin;
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFecha({required bool esInicio}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (esInicio ? _fechaInicio : (_fechaFin ?? _fechaInicio)),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (esInicio) {
        _fechaInicio = picked;
      } else {
        _fechaFin = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_esEdicion) {
        await _repo.actualizar(
          id: widget.promoAEditar!.id,
          titulo: _tituloCtrl.text,
          descripcion: _descCtrl.text,
          fechaInicio: _fechaInicio,
          fechaFin: _fechaFin,
        );
      } else {
        await _repo.crear(
          titulo: _tituloCtrl.text,
          descripcion: _descCtrl.text,
          fechaInicio: _fechaInicio,
          fechaFin: _fechaFin,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4A8FE7), _kPrimary],
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
                  Expanded(
                    child: Text(
                      _esEdicion ? 'Editar promoción' : 'Nueva promoción',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Título *',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _tituloCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Ej: 20% de descuento en yogur de mango',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'El título es obligatorio'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      const Text('Descripción *',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Detalles de la promoción…',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'La descripción es obligatoria'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      const Text('Vigencia',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickFecha(esInicio: true),
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(
                                  'Desde ${fmt.format(_fechaInicio.toLocal())}'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickFecha(esInicio: false),
                              icon: const Icon(Icons.event_busy, size: 16),
                              label: Text(_fechaFin != null
                                  ? 'Hasta ${fmt.format(_fechaFin!.toLocal())}'
                                  : 'Sin fecha fin'),
                            ),
                          ),
                        ],
                      ),
                      if (_fechaFin != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => setState(() => _fechaFin = null),
                            child: const Text('Quitar fecha fin'),
                          ),
                        ),
                      const SizedBox(height: 20),
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _kDanger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(_error!,
                              style: const TextStyle(color: _kDanger)),
                        ),
                      ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(_esEdicion ? 'Guardar cambios' : 'Crear promoción'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
