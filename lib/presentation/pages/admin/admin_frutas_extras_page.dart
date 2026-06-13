import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yogo_vital_app/core/models/extra.dart';
import 'package:yogo_vital_app/core/models/fruta.dart';
import 'package:yogo_vital_app/core/models/fruta_extra_admin_provider.dart';
import 'package:yogo_vital_app/core/services/user_role_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta de colores
// ─────────────────────────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF5B9EF5);
const _kFruta = Color(0xFFE91E8C);     // Rosa para frutas
const _kExtra = Color(0xFF0E8498);     // Verde azulado para extras
const _kBg = Color(0xFFF5F7FA);
const _kCard = Colors.white;
const _kDanger = Color(0xFFEF5350);
const _kSuccess = Color(0xFF4CAF50);

// ─────────────────────────────────────────────────────────────────────────────
// PUNTO DE ENTRADA
// HU_GestionarFrutasExtras_35
// ─────────────────────────────────────────────────────────────────────────────

/// Punto de entrada: verifica rol admin y usa Supabase Realtime.
class AdminFrutasExtrasPage extends StatefulWidget {
  const AdminFrutasExtrasPage({super.key});

  @override
  State<AdminFrutasExtrasPage> createState() => _AdminFrutasExtrasPageState();
}

class _AdminFrutasExtrasPageState extends State<AdminFrutasExtrasPage> {
  bool _checking = true;

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
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return ChangeNotifierProvider(
      create: (_) => FrutaExtraAdminProvider(),
      child: const _FrutasExtrasView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VISTA PRINCIPAL CON TABBAR
// ─────────────────────────────────────────────────────────────────────────────

class _FrutasExtrasView extends StatefulWidget {
  const _FrutasExtrasView();

  @override
  State<_FrutasExtrasView> createState() => _FrutasExtrasViewState();
}

class _FrutasExtrasViewState extends State<_FrutasExtrasView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildTabBar(),
            Expanded(
              child: Consumer<FrutaExtraAdminProvider>(
                builder: (ctx, prov, _) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (prov.formSuccess != null) {
                      _showSnack(context, prov.formSuccess!, isError: false);
                      prov.resetFormState();
                    } else if (prov.formState == CatalogoFormState.error &&
                        prov.formError != null) {
                      _showSnack(context, prov.formError!, isError: true);
                      prov.resetFormState();
                    }
                  });
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _FrutasTab(prov: prov),
                      _ExtrasTab(prov: prov),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(context),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
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
              'Gestión de Catálogo',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

  // ── TabBar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        indicatorColor: _kPrimary,
        indicatorWeight: 3,
        labelColor: _kPrimary,
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        tabs: const [
          Tab(
            icon: Icon(Icons.local_florist_rounded, size: 22),
            text: 'Frutas',
          ),
          Tab(
            icon: Icon(Icons.star_rounded, size: 22),
            text: 'Extras',
          ),
        ],
      ),
    );
  }

  // ── FAB ───────────────────────────────────────────────────────────────────

  Widget _buildFAB(BuildContext context) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (ctx, _) {
        final esFrutas = _tabController.index == 0;
        return FloatingActionButton.extended(
          onPressed: () => _abrirFormulario(context, esFrutas: esFrutas),
          backgroundColor: esFrutas ? _kFruta : _kExtra,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: Text(
            esFrutas ? 'Nueva fruta' : 'Nuevo extra',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      },
    );
  }

  void _abrirFormulario(BuildContext context, {required bool esFrutas,
      Fruta? fruta, Extra? extra}) {
    final prov = context.read<FrutaExtraAdminProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: _CatalogoFormSheet(
          esFrutas: esFrutas,
          fruta: fruta,
          extra: extra,
        ),
      ),
    );
  }

  void _showSnack(BuildContext ctx, String msg, {required bool isError}) {
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        backgroundColor: isError ? _kDanger : _kSuccess,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PESTAÑA FRUTAS
// ─────────────────────────────────────────────────────────────────────────────

class _FrutasTab extends StatelessWidget {
  final FrutaExtraAdminProvider prov;
  const _FrutasTab({required this.prov});

  @override
  Widget build(BuildContext context) {
    if (prov.loadingFrutas) {
      return const Center(
        child: CircularProgressIndicator(color: _kFruta, strokeWidth: 3),
      );
    }

    if (prov.frutaListError != null) {
      return _ErrorView(
        message: prov.frutaListError!,
        onRetry: prov.cargarFrutas,
        color: _kFruta,
      );
    }

    if (prov.frutas.isEmpty) {
      return _EmptyView(
        icon: Icons.local_florist_rounded,
        label: 'No hay frutas registradas',
        hint: 'Toca + para agregar la primera fruta',
        color: _kFruta,
      );
    }

    return RefreshIndicator(
      color: _kFruta,
      onRefresh: prov.cargarFrutas,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: prov.frutas.length,
        itemBuilder: (ctx, i) => _CatalogoCard(
          id: prov.frutas[i].id,
          nombre: prov.frutas[i].nombre,
          precioAdicional: prov.frutas[i].precioAdicional,
          disponible: prov.frutas[i].disponible,
          accentColor: _kFruta,
          icon: Icons.local_florist_rounded,
          onEdit: () => _abrirEdicion(ctx, prov.frutas[i]),
          onToggle: (v) => prov.toggleFrutaDisponibilidad(
              prov.frutas[i].id, disponible: v),
          onDelete: () => _confirmarEliminacion(ctx, prov.frutas[i].id,
              prov.frutas[i].nombre, esFruta: true),
        ),
      ),
    );
  }

  void _abrirEdicion(BuildContext context, Fruta fruta) {
    final prov = context.read<FrutaExtraAdminProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: _CatalogoFormSheet(esFrutas: true, fruta: fruta),
      ),
    );
  }

  Future<void> _confirmarEliminacion(
      BuildContext context, String id, String nombre,
      {required bool esFruta}) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('¿Eliminar fruta?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Vas a desactivar "$nombre" del catálogo.\n'
          'Los pedidos existentes no se verán afectados.',
          style: const TextStyle(color: Color(0xFF5A5A5A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kDanger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado == true && context.mounted) {
      await context.read<FrutaExtraAdminProvider>().eliminarFruta(id);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PESTAÑA EXTRAS
// ─────────────────────────────────────────────────────────────────────────────

class _ExtrasTab extends StatelessWidget {
  final FrutaExtraAdminProvider prov;
  const _ExtrasTab({required this.prov});

  @override
  Widget build(BuildContext context) {
    if (prov.loadingExtras) {
      return const Center(
        child: CircularProgressIndicator(color: _kExtra, strokeWidth: 3),
      );
    }

    if (prov.extraListError != null) {
      return _ErrorView(
        message: prov.extraListError!,
        onRetry: prov.cargarExtras,
        color: _kExtra,
      );
    }

    if (prov.extras.isEmpty) {
      return _EmptyView(
        icon: Icons.star_rounded,
        label: 'No hay extras registrados',
        hint: 'Toca + para agregar el primer extra',
        color: _kExtra,
      );
    }

    return RefreshIndicator(
      color: _kExtra,
      onRefresh: prov.cargarExtras,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: prov.extras.length,
        itemBuilder: (ctx, i) => _CatalogoCard(
          id: prov.extras[i].id,
          nombre: prov.extras[i].nombre,
          precioAdicional: prov.extras[i].precioAdicional,
          disponible: prov.extras[i].disponible,
          accentColor: _kExtra,
          icon: Icons.star_rounded,
          onEdit: () => _abrirEdicion(ctx, prov.extras[i]),
          onToggle: (v) => prov.toggleExtraDisponibilidad(
              prov.extras[i].id, disponible: v),
          onDelete: () => _confirmarEliminacion(
              ctx, prov.extras[i].id, prov.extras[i].nombre),
        ),
      ),
    );
  }

  void _abrirEdicion(BuildContext context, Extra extra) {
    final prov = context.read<FrutaExtraAdminProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: _CatalogoFormSheet(esFrutas: false, extra: extra),
      ),
    );
  }

  Future<void> _confirmarEliminacion(
      BuildContext context, String id, String nombre) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('¿Eliminar extra?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Vas a desactivar "$nombre" del catálogo.\n'
          'Los pedidos existentes no se verán afectados.',
          style: const TextStyle(color: Color(0xFF5A5A5A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kDanger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado == true && context.mounted) {
      await context.read<FrutaExtraAdminProvider>().eliminarExtra(id);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TARJETA DE CATÁLOGO (reutilizable para Frutas y Extras)
// ─────────────────────────────────────────────────────────────────────────────

class _CatalogoCard extends StatelessWidget {
  final String id;
  final String nombre;
  final double precioAdicional;
  final bool disponible;
  final Color accentColor;
  final IconData icon;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _CatalogoCard({
    required this.id,
    required this.nombre,
    required this.precioAdicional,
    required this.disponible,
    required this.accentColor,
    required this.icon,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'es_CO');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Ícono decorativo
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: disponible
                      ? [
                          accentColor.withValues(alpha: 0.15),
                          accentColor.withValues(alpha: 0.28)
                        ]
                      : [Colors.grey.shade200, Colors.grey.shade300],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: disponible ? accentColor : Colors.grey, size: 26),
            ),
            const SizedBox(width: 14),

            // Info central
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    precioAdicional == 0
                        ? 'Sin costo adicional'
                        : '+COP ${fmt.format(precioAdicional)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: precioAdicional == 0
                          ? Colors.grey
                          : accentColor,
                    ),
                  ),
                ],
              ),
            ),

            // Toggle disponibilidad
            Switch(
              value: disponible,
              onChanged: onToggle,
              activeThumbColor: Colors.white,
              activeTrackColor: _kSuccess,
              inactiveThumbColor: Colors.grey.shade400,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),

            // Botón editar
            IconButton(
              icon: Icon(Icons.edit_rounded, color: accentColor, size: 20),
              tooltip: 'Editar',
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),

            // Botón eliminar
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: _kDanger, size: 20),
              tooltip: 'Eliminar',
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORMULARIO MODAL (BottomSheet) — Agregar / Editar Fruta o Extra
// ─────────────────────────────────────────────────────────────────────────────

class _CatalogoFormSheet extends StatefulWidget {
  final bool esFrutas;
  final Fruta? fruta;
  final Extra? extra;

  const _CatalogoFormSheet({
    required this.esFrutas,
    this.fruta,
    this.extra,
  });

  @override
  State<_CatalogoFormSheet> createState() => _CatalogoFormSheetState();
}

class _CatalogoFormSheetState extends State<_CatalogoFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _precioCtrl;

  bool get _esEdicion => widget.fruta != null || widget.extra != null;
  String get _tituloEntidad => widget.esFrutas ? 'fruta' : 'extra';
  Color get _accentColor => widget.esFrutas ? _kFruta : _kExtra;
  IconData get _entityIcon =>
      widget.esFrutas ? Icons.local_florist_rounded : Icons.star_rounded;

  @override
  void initState() {
    super.initState();
    final nombreInicial =
        widget.fruta?.nombre ?? widget.extra?.nombre ?? '';
    final precioInicial =
        widget.fruta?.precioAdicional ?? widget.extra?.precioAdicional;
    _nombreCtrl = TextEditingController(text: nombreInicial);
    _precioCtrl = TextEditingController(
      text: precioInicial != null ? precioInicial.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final prov = context.read<FrutaExtraAdminProvider>();
    final nombre = _nombreCtrl.text.trim();
    final precio =
        double.parse(_precioCtrl.text.trim().replaceAll(',', '.'));

    bool ok;
    if (widget.esFrutas) {
      if (_esEdicion) {
        ok = await prov.actualizarFruta(
          id: widget.fruta!.id,
          nombre: nombre,
          precioAdicional: precio,
        );
      } else {
        ok = await prov.agregarFruta(
          nombre: nombre,
          precioAdicional: precio,
        );
      }
    } else {
      if (_esEdicion) {
        ok = await prov.actualizarExtra(
          id: widget.extra!.id,
          nombre: nombre,
          precioAdicional: precio,
        );
      } else {
        ok = await prov.agregarExtra(
          nombre: nombre,
          precioAdicional: precio,
        );
      }
    }

    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Título
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_entityIcon, color: _accentColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      _esEdicion
                          ? 'Editar $_tituloEntidad'
                          : 'Nueva $_tituloEntidad',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Campo Nombre
                _buildLabel('Nombre *'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _nombreCtrl,
                  hint: 'Ej: Fresa, Chispas de chocolate…',
                  icon: Icons.label_rounded,
                  action: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'El nombre es obligatorio';
                    }
                    if (v.trim().length < 2) return 'Mínimo 2 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Campo Precio
                _buildLabel('Precio adicional (COP) *'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _precioCtrl,
                  hint: 'Ej: 500 (0 si no tiene costo)',
                  icon: Icons.attach_money_rounded,
                  action: TextInputAction.done,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'El precio es obligatorio';
                    }
                    final parsed =
                        double.tryParse(v.trim().replaceAll(',', '.'));
                    if (parsed == null) return 'Número inválido';
                    if (parsed < 0) return 'El precio no puede ser negativo';
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // Error banner
                Consumer<FrutaExtraAdminProvider>(
                  builder: (_, p, __) {
                    if (p.formState == CatalogoFormState.error &&
                        p.formError != null) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _kDanger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _kDanger.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: _kDanger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(p.formError!,
                                  style: const TextStyle(
                                      color: _kDanger, fontSize: 13)),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // Botón guardar
                Consumer<FrutaExtraAdminProvider>(
                  builder: (_, p, __) => ElevatedButton(
                    onPressed: p.isSaving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          _accentColor.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: p.isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            _esEdicion ? 'Guardar cambios' : 'Agregar',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),

                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar',
                      style: TextStyle(color: Colors.grey, fontSize: 15)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A2E),
        ),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required TextInputAction action,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: action,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _accentColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kDanger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kDanger, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS AUXILIARES
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final Color color;

  const _EmptyView({
    required this.icon,
    required this.label,
    required this.hint,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: color),
          ),
          const SizedBox(height: 20),
          Text(
            label,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(hint, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final Color color;

  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 56, color: _kDanger),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF5A5A5A), fontSize: 15),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
