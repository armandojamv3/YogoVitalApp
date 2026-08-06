-- Migration 0041: Blindar el cambio de estado de pedidos ante fallos del
-- trigger de recálculo de total.
--
-- SÍNTOMA REPORTADO: el admin no podía cambiar el estado de un pedido —
-- tocaba el botón y "no pasaba nada" (ni error, ni cambio).
--
-- CAUSA RAÍZ: trg_fijar_total_pedido() (migración 0035) es BEFORE UPDATE y
-- se dispara en TODO update sobre `pedidos`, incluyendo un simple cambio de
-- estado, y siempre llama a calcular_total_pedido() con tal de que el
-- pedido tenga tamano_id — sin importar si el total tiene algo que ver con
-- el cambio. Si esa función fallaba (por ejemplo si la migración 0040 no se
-- había corrido todavía y calcular_total_pedido() seguía consultando la
-- tabla `tamanos`, que no existe), el UPDATE completo del pedido fallaba —
-- y como PedidosAdminRepository.cambiarEstado() no capturaba ese error
-- (ver fix aparte en el código Dart), el admin no veía ningún mensaje.
--
-- Esta migración corrige dos cosas:
-- 1) El trigger ya NO recalcula el total en cada UPDATE: solo lo hace en
--    INSERT, o cuando tamano_id realmente cambió. Un cambio de estado (o
--    cualquier otro campo) ya no dispara ningún cálculo de precio.
-- 2) calcular_total_pedido() reafirma (por si la 0040 no llegó a correrse)
--    que solo usa tamanos_yogur, y ahora el trigger queda blindado con un
--    bloque EXCEPTION: si algo llegara a fallar al calcular el total, ya no
--    revienta el UPDATE completo del pedido — solo deja el total como
--    estaba y registra un WARNING.
--
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query → Run
-- Es idempotente: se puede correr varias veces sin daño.

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

CREATE OR REPLACE FUNCTION public.trg_fijar_total_pedido()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Solo recalcular cuando de verdad puede haber cambiado el total:
  -- al crear el pedido, o si tamano_id cambió. Un cambio de estado (o
  -- cualquier otro campo, como updated_at) ya NO dispara ningún cálculo.
  IF TG_OP = 'INSERT' THEN
    IF NEW.tamano_id IS NOT NULL THEN
      BEGIN
        NEW.total := public.calcular_total_pedido(NEW.tamano_id, NEW.id);
      EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'calcular_total_pedido falló al crear pedido %: %', NEW.id, SQLERRM;
      END;
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.tamano_id IS NOT NULL AND NEW.tamano_id IS DISTINCT FROM OLD.tamano_id THEN
      BEGIN
        NEW.total := public.calcular_total_pedido(NEW.tamano_id, NEW.id);
      EXCEPTION WHEN OTHERS THEN
        -- No dejar que un fallo aquí bloquee el UPDATE completo del pedido
        -- (por ejemplo, un cambio de estado hecho por el admin). Se
        -- conserva el total que ya tenía la fila.
        RAISE WARNING 'calcular_total_pedido falló al actualizar pedido %: %', NEW.id, SQLERRM;
      END;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_fijar_total_pedido ON public.pedidos;
CREATE TRIGGER trg_fijar_total_pedido
  BEFORE INSERT OR UPDATE ON public.pedidos
  FOR EACH ROW EXECUTE FUNCTION public.trg_fijar_total_pedido();

-- ── Verificación ─────────────────────────────────────────────────────────
SELECT proname, prosrc ILIKE '%tamanos_yogur%' AS usa_tamanos_yogur,
       prosrc ILIKE '%FROM tamanos %' AS usa_tabla_tamanos_inexistente
FROM pg_proc WHERE proname = 'calcular_total_pedido';
