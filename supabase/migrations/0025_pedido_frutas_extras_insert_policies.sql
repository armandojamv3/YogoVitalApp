-- Migración 0025: Permitir INSERT en pedido_frutas y pedido_extras
-- Objetivo:
--   * El cliente puede insertar frutas/extras únicamente en SUS pedidos.

-- 1. Eliminar políticas previas (idempotencia)
DROP POLICY IF EXISTS pedido_frutas_insert ON pedido_frutas;
DROP POLICY IF EXISTS pedido_extras_insert ON pedido_extras;

-- 2. Cliente puede insertar frutas en SUS pedidos
CREATE POLICY pedido_frutas_insert ON pedido_frutas
FOR INSERT
WITH CHECK (EXISTS (
  SELECT 1 FROM pedidos
  WHERE pedidos.id = pedido_frutas.pedido_id
  AND pedidos.cliente_id = auth.uid()
));

-- 3. Cliente puede insertar extras en SUS pedidos
CREATE POLICY pedido_extras_insert ON pedido_extras
FOR INSERT
WITH CHECK (EXISTS (
  SELECT 1 FROM pedidos
  WHERE pedidos.id = pedido_extras.pedido_id
  AND pedidos.cliente_id = auth.uid()
));
