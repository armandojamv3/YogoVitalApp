-- Migration 0015: Fix infinite recursion in RLS policies.
--
-- Root cause: policies on tablas (sabores, frutas, etc.) call
--   EXISTS (SELECT 1 FROM usuarios WHERE ...)
-- which triggers the RLS policy on 'usuarios', which again queries
-- 'usuarios' → infinite loop (error 42P17).
--
-- Fix: a SECURITY DEFINER function bypasses RLS when it queries
-- 'usuarios', breaking the recursion. All inline admin checks
-- are replaced with is_admin().
--
-- Run this in: Supabase Dashboard → SQL Editor → New query → Run

-- ── 1. Función helper para verificar rol administrador ────────────────────
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.usuarios
    WHERE id = auth.uid() AND rol = 'administrador'
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon;


-- ── 2. Política usuarios (eliminar auto-referencia recursiva) ─────────────
DROP POLICY IF EXISTS "usuarios_select_own"   ON public.usuarios;
DROP POLICY IF EXISTS "usuarios_update_own"   ON public.usuarios;
DROP POLICY IF EXISTS "admin_select_usuarios" ON public.usuarios;

CREATE POLICY "usuarios_select_own" ON public.usuarios FOR SELECT
  USING (id = auth.uid() OR public.is_admin());

CREATE POLICY "usuarios_update_own" ON public.usuarios FOR UPDATE
  USING (id = auth.uid()) WITH CHECK (id = auth.uid());


-- ── 3. Política sabores ───────────────────────────────────────────────────
DROP POLICY IF EXISTS "admin_all_sabores"      ON public.sabores;
DROP POLICY IF EXISTS "cliente_select_sabores" ON public.sabores;

CREATE POLICY "admin_all_sabores" ON public.sabores
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "cliente_select_sabores" ON public.sabores FOR SELECT
  USING (activo = true OR public.is_admin());


-- ── 4. Política tamanos ───────────────────────────────────────────────────
DROP POLICY IF EXISTS "admin_all_tamanos" ON public.tamanos;

CREATE POLICY "admin_all_tamanos" ON public.tamanos
  USING (public.is_admin())
  WITH CHECK (public.is_admin());


-- ── 5. Política frutas ────────────────────────────────────────────────────
DROP POLICY IF EXISTS "admin_all_frutas"      ON public.frutas;
DROP POLICY IF EXISTS "cliente_select_frutas" ON public.frutas;

CREATE POLICY "admin_all_frutas" ON public.frutas
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "cliente_select_frutas" ON public.frutas FOR SELECT
  USING (disponible = true OR public.is_admin());


-- ── 6. Política extras ────────────────────────────────────────────────────
DROP POLICY IF EXISTS "admin_all_extras"      ON public.extras;
DROP POLICY IF EXISTS "cliente_select_extras" ON public.extras;

CREATE POLICY "admin_all_extras" ON public.extras
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "cliente_select_extras" ON public.extras FOR SELECT
  USING (disponible = true OR public.is_admin());


-- ── 7. Política predisenhados ─────────────────────────────────────────────
DROP POLICY IF EXISTS "predisenhados_select_activos" ON public.predisenhados;
DROP POLICY IF EXISTS "admin_all_predisenhados"      ON public.predisenhados;

CREATE POLICY "predisenhados_select_activos" ON public.predisenhados FOR SELECT
  USING (activo = true OR public.is_admin());

CREATE POLICY "admin_all_predisenhados" ON public.predisenhados
  USING (public.is_admin())
  WITH CHECK (public.is_admin());


-- ── 8. Política pedidos ───────────────────────────────────────────────────
DROP POLICY IF EXISTS "pedidos_select"     ON public.pedidos;
DROP POLICY IF EXISTS "pedidos_insert_own" ON public.pedidos;
DROP POLICY IF EXISTS "pedidos_update"     ON public.pedidos;

CREATE POLICY "pedidos_select" ON public.pedidos FOR SELECT
  USING (cliente_id = auth.uid() OR public.is_admin());

CREATE POLICY "pedidos_insert_own" ON public.pedidos FOR INSERT
  WITH CHECK (cliente_id = auth.uid());

CREATE POLICY "pedidos_update" ON public.pedidos FOR UPDATE
  USING (cliente_id = auth.uid() OR public.is_admin());


-- ── 9. Política pedido_frutas ─────────────────────────────────────────────
DROP POLICY IF EXISTS "pedido_frutas_access" ON public.pedido_frutas;

CREATE POLICY "pedido_frutas_access" ON public.pedido_frutas FOR ALL
  USING (
    EXISTS (SELECT 1 FROM pedidos p WHERE p.id = pedido_id AND p.cliente_id = auth.uid())
    OR public.is_admin()
  );


-- ── 10. Política pedido_extras ────────────────────────────────────────────
DROP POLICY IF EXISTS "pedido_extras_access" ON public.pedido_extras;

CREATE POLICY "pedido_extras_access" ON public.pedido_extras FOR ALL
  USING (
    EXISTS (SELECT 1 FROM pedidos p WHERE p.id = pedido_id AND p.cliente_id = auth.uid())
    OR public.is_admin()
  );


-- ── 11. Política calificaciones ───────────────────────────────────────────
DROP POLICY IF EXISTS "calificaciones_insert_owner" ON public.calificaciones;

CREATE POLICY "calificaciones_insert_owner" ON public.calificaciones FOR INSERT
  WITH CHECK (
    cliente_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM pedidos
      WHERE pedidos.id = pedido_id
        AND pedidos.cliente_id = auth.uid()
        AND pedidos.estado = 'Entregado'
    )
  );


-- ── 12. Política historial_estados ────────────────────────────────────────
DROP POLICY IF EXISTS "historial_select" ON public.historial_estados;
DROP POLICY IF EXISTS "historial_insert" ON public.historial_estados;

CREATE POLICY "historial_select" ON public.historial_estados FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM pedidos p WHERE p.id = pedido_id AND p.cliente_id = auth.uid())
    OR public.is_admin()
  );

CREATE POLICY "historial_insert" ON public.historial_estados FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM pedidos p WHERE p.id = pedido_id AND p.cliente_id = auth.uid())
    OR public.is_admin()
  );
