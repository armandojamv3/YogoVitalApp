-- Migración 0022: RLS Anónimo + Admin Access
-- Ejecutada en Supabase Dashboard → SQL Editor el 2026-06-13.
-- Objetivo:
--   * Calificaciones anónimas visibles para todos; el cliente ve la suya;
--     el admin ve todas.
--   * Admin puede ver todos los pedidos.
--   * pedido_extras / pedido_frutas restringidas a pedidos propios (SELECT).

-- 1. Eliminar políticas viejas
DROP POLICY IF EXISTS calificaciones_select_all ON calificaciones;
DROP POLICY IF EXISTS calificaciones_select_own ON calificaciones;

-- 2. Nueva política: Anónimo para todos + propio con nombre + admin con nombre
CREATE POLICY calificaciones_select_anon ON calificaciones
FOR SELECT
USING (
  (es_anonimo = true)
  OR
  (cliente_id = auth.uid())
  OR
  (EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador'))
);

-- 3. Pedidos: Admin puede ver todos
DROP POLICY IF EXISTS pedidos_select_own ON pedidos;

CREATE POLICY pedidos_select_own ON pedidos
FOR SELECT
USING (
  (cliente_id = auth.uid())
  OR
  (EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador'))
);

-- 4. Pedido_extras y pedido_frutas: Restringir a pedidos propios
DROP POLICY IF EXISTS pedido_extras_all ON pedido_extras;
DROP POLICY IF EXISTS pedido_frutas_all ON pedido_frutas;

CREATE POLICY pedido_extras_select ON pedido_extras
FOR SELECT
USING (EXISTS (SELECT 1 FROM pedidos WHERE pedidos.id = pedido_extras.pedido_id AND pedidos.cliente_id = auth.uid()));

CREATE POLICY pedido_frutas_select ON pedido_frutas
FOR SELECT
USING (EXISTS (SELECT 1 FROM pedidos WHERE pedidos.id = pedido_frutas.pedido_id AND pedidos.cliente_id = auth.uid()));
