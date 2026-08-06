-- Migration 0040: Corrige calcular_total_pedido() — la tabla `tamanos` no existe.
--
-- Bug introducido en la migración 0035: esa función asumía (según
-- SUPABASE_SETUP.sql) que existían dos catálogos de tamaño, `tamanos` y
-- `tamanos_yogur`, y probaba ambos con COALESCE. Pero `tamanos` nunca se
-- creó en la base real — TODO el flujo de personalizado (verificado en
-- personalizacion_repository.dart, pedidos_admin_repository.dart,
-- factura_repository.dart, historial_repository.dart) usa únicamente
-- `tamanos_yogur`. Como COALESCE no protege contra una tabla inexistente
-- (solo contra NULL), cada intento de confirmar un pedido fallaba con:
--   "PostgrestException: relation 'tamanos' does not exist (42P01)"
--
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query → Run

CREATE OR REPLACE FUNCTION public.calcular_total_pedido(
  p_tamano_id UUID,
  p_pedido_id UUID
) RETURNS NUMERIC
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tamano NUMERIC := 0;
  v_frutas NUMERIC := 0;
  v_extras NUMERIC := 0;
BEGIN
  SELECT COALESCE(precio, 0) INTO v_tamano
    FROM tamanos_yogur WHERE id = p_tamano_id;

  IF p_pedido_id IS NOT NULL THEN
    SELECT COALESCE(SUM(f.precio_adicional), 0) INTO v_frutas
      FROM pedido_frutas pf JOIN frutas f ON f.id = pf.fruta_id
      WHERE pf.pedido_id = p_pedido_id;

    SELECT COALESCE(SUM(e.precio_adicional), 0) INTO v_extras
      FROM pedido_extras pe JOIN extras e ON e.id = pe.extra_id
      WHERE pe.pedido_id = p_pedido_id;
  END IF;

  RETURN COALESCE(v_tamano, 0) + v_frutas + v_extras;
END;
$$;
