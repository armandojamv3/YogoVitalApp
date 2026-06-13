-- Migration 0018: Elimina recursión infinita en TODAS las tablas que
-- referencian 'usuarios' en sus políticas RLS.
--
-- Causa raíz: las políticas verifican el rol admin haciendo
--   EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() ...)
-- pero 'usuarios' también tiene RLS habilitado con una política que
-- se referencia a sí misma → loop infinito (error 42P17).
--
-- Solución: reemplazar todas las políticas con versiones simples
-- que solo usan auth.uid() sin cruzar a otras tablas.
--
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query → Run

-- ────────────────────────────────────────────────────────────────────────
-- Helper: función para eliminar TODAS las políticas de una tabla
-- ────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION _drop_all_policies(tbl TEXT)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE pol TEXT;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = tbl
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', pol, tbl);
  END LOOP;
END $$;

-- ── 1. usuarios ──────────────────────────────────────────────────────────
SELECT _drop_all_policies('usuarios');

CREATE POLICY "usuarios_select_own" ON public.usuarios
  FOR SELECT USING (id = auth.uid());

CREATE POLICY "usuarios_update_own" ON public.usuarios
  FOR UPDATE USING (id = auth.uid()) WITH CHECK (id = auth.uid());

-- ── 2. pedidos ───────────────────────────────────────────────────────────
SELECT _drop_all_policies('pedidos');

CREATE POLICY "pedidos_select" ON public.pedidos
  FOR SELECT USING (cliente_id = auth.uid());

CREATE POLICY "pedidos_insert_own" ON public.pedidos
  FOR INSERT WITH CHECK (cliente_id = auth.uid());

CREATE POLICY "pedidos_update_own" ON public.pedidos
  FOR UPDATE USING (cliente_id = auth.uid());

-- ── 3. direcciones ───────────────────────────────────────────────────────
SELECT _drop_all_policies('direcciones');

CREATE POLICY "direcciones_own" ON public.direcciones
  FOR ALL USING (cliente_id = auth.uid()) WITH CHECK (cliente_id = auth.uid());

-- ── 4. pedido_frutas ─────────────────────────────────────────────────────
SELECT _drop_all_policies('pedido_frutas');

CREATE POLICY "pedido_frutas_access" ON public.pedido_frutas
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM pedidos p
      WHERE p.id = pedido_id AND p.cliente_id = auth.uid()
    )
  );

-- ── 5. pedido_extras ─────────────────────────────────────────────────────
SELECT _drop_all_policies('pedido_extras');

CREATE POLICY "pedido_extras_access" ON public.pedido_extras
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM pedidos p
      WHERE p.id = pedido_id AND p.cliente_id = auth.uid()
    )
  );

-- ── 6. calificaciones ────────────────────────────────────────────────────
SELECT _drop_all_policies('calificaciones');

CREATE POLICY "calificaciones_select_all" ON public.calificaciones
  FOR SELECT USING (true);

CREATE POLICY "calificaciones_insert_owner" ON public.calificaciones
  FOR INSERT WITH CHECK (
    cliente_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM pedidos
      WHERE pedidos.id = pedido_id
        AND pedidos.cliente_id = auth.uid()
        AND pedidos.estado = 'Entregado'
    )
  );

-- ── 7. historial_estados ─────────────────────────────────────────────────
SELECT _drop_all_policies('historial_estados');

CREATE POLICY "historial_select" ON public.historial_estados
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM pedidos p WHERE p.id = pedido_id AND p.cliente_id = auth.uid())
  );

CREATE POLICY "historial_insert" ON public.historial_estados
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM pedidos p WHERE p.id = pedido_id AND p.cliente_id = auth.uid())
  );

-- ── 8. frutas ────────────────────────────────────────────────────────────
SELECT _drop_all_policies('frutas');

CREATE POLICY "frutas_select" ON public.frutas
  FOR SELECT USING (disponible = true);

-- ── 9. extras ────────────────────────────────────────────────────────────
SELECT _drop_all_policies('extras');

CREATE POLICY "extras_select" ON public.extras
  FOR SELECT USING (disponible = true);

-- ── 10. tamanos ──────────────────────────────────────────────────────────
SELECT _drop_all_policies('tamanos');

CREATE POLICY "tamanos_select" ON public.tamanos
  FOR SELECT USING (true);

-- ── Limpieza ──────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS _drop_all_policies(TEXT);
DROP FUNCTION IF EXISTS public.is_admin();

-- ── Verificación final ────────────────────────────────────────────────────
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
