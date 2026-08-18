-- Migration 0051: el sabor vuelve a influir en el precio.
--
-- ── EL PROBLEMA ─────────────────────────────────────────────────────────
-- En un yogur típico el total salía SOLO del tamaño:
--
--     SELECT COALESCE(precio, 0) INTO v_base
--       FROM tamanos_yogur WHERE id = p_tamano_id;
--
-- El `precio_base` del sabor no se usaba para nada. Consecuencia: un
-- Chontaduro Personal y una Piña Personal costaban lo mismo, $5.000, por
-- mucho que el chontaduro sea una fruta más cara.
--
-- Y encima la app SÍ mostraba ese `precio_base` en las tarjetas del
-- catálogo (Piña $8.000, Chontaduro $9.000). El cliente veía un precio en
-- la lista y le cobraban otro al entrar. Dos reglas de precio conviviendo,
-- una de ellas muerta.
--
-- ── LA REGLA NUEVA ──────────────────────────────────────────────────────
--     típico = precio del tamaño + recargo del sabor
--
-- Es la misma forma que ya usaban los prediseñados desde la 0045
-- (receta + tamaño), así que el sistema pasa a tener un solo modelo mental
-- en vez de dos.
--
-- Los tamaños NO se tocan: Personal $5.000, ½ Litro $8.000, 1 Litro
-- $14.000, 2 Litros $25.000 siguen siendo lo que cuesta el yogur. Lo que
-- se añade es cuánto suma cada sabor.
--
-- Ejemplo — Chontaduro (recargo 1.500) en 1 Litro (14.000), 2 unidades:
--     (14000 + 1500) * 2 = 31000
--
-- ── POR QUÉ UNA COLUMNA NUEVA Y NO REUTILIZAR precio_base ───────────────
-- Porque `precio_base` vale hoy 8.000 o 9.000. Si se reinterpretara como
-- recargo, una Piña Personal pasaría a costar 13.000 de un día para otro.
-- Con una columna nueva a 0 ningún precio cambia hasta que tú decidas los
-- recargos desde el panel de administración.
--
-- ── BASE DE ESTA VERSIÓN ────────────────────────────────────────────────
-- La función se recrea a partir de la versión de la 0046 (la que está en
-- producción), no de la 0045. Importa: la 0046 añadió el aviso a los
-- administradores y las variables v_producto y v_cliente. Partir de la
-- 0045 habría borrado esas notificaciones sin que se notara hasta que
-- alguien hiciera un pedido.
--
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query → Run
-- Es idempotente.

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  1. LA COLUMNA                                                       ║
-- ╚══════════════════════════════════════════════════════════════════════╝
ALTER TABLE public.sabores
  ADD COLUMN IF NOT EXISTS recargo NUMERIC(10,2) NOT NULL DEFAULT 0;

ALTER TABLE public.sabores
  DROP CONSTRAINT IF EXISTS sabores_recargo_no_negativo;

ALTER TABLE public.sabores
  ADD CONSTRAINT sabores_recargo_no_negativo CHECK (recargo >= 0);

COMMENT ON COLUMN public.sabores.recargo IS
  'Lo que suma este sabor al precio del tamaño. 0 = sabor estándar, sin '
  'sobrecosto. El total de un típico es tamanos_yogur.precio + recargo.';

-- `precio_base` queda sin uso en el precio. No se borra: hay pedidos
-- antiguos calculados con ella y borrar una columna es irreversible. Se
-- marca para que nadie la vuelva a tomar por el precio de venta.
COMMENT ON COLUMN public.sabores.precio_base IS
  'OBSOLETA desde la migración 0051. Ya no interviene en el precio de un '
  'pedido con tamaño: el total es tamanos_yogur.precio + sabores.recargo. '
  'Se conserva por compatibilidad con pedidos y datos antiguos.';

-- Era NOT NULL, y el panel de administración deja de pedirla.
ALTER TABLE public.sabores
  ALTER COLUMN precio_base DROP NOT NULL;

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  2. EL CÁLCULO DEL TOTAL                                             ║
-- ╚══════════════════════════════════════════════════════════════════════╝
-- Idéntica a la versión de la 0046 salvo tres líneas: la variable
-- v_recargo, su lectura junto al nombre del sabor, y su suma al total.
CREATE OR REPLACE FUNCTION public.crear_pedido(
  p_direccion_id    UUID,
  p_metodo_pago     TEXT,
  p_tamano_id       UUID   DEFAULT NULL,
  p_sabor_id        UUID   DEFAULT NULL,
  p_predisenhado_id UUID   DEFAULT NULL,
  p_dulzura         TEXT   DEFAULT 'Normal',
  p_frutas          UUID[] DEFAULT ARRAY[]::UUID[],
  p_extras          UUID[] DEFAULT ARRAY[]::UUID[],
  p_cantidad        INT    DEFAULT 1
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid        UUID := auth.uid();
  v_pedido_id  UUID;
  v_tipo       TEXT;
  v_base       NUMERIC := 0;
  v_tamano     NUMERIC := 0;
  v_recargo    NUMERIC := 0;   -- NUEVO en la 0051: sobrecosto del sabor
  v_frutas     NUMERIC := 0;
  v_extras     NUMERIC := 0;
  v_total      NUMERIC := 0;
  v_n_frutas   INT;
  v_n_extras   INT;
  v_producto   TEXT;    -- nombre para el mensaje del aviso
  v_cliente    TEXT;
BEGIN
  -- ── Validaciones ──────────────────────────────────────────────────────
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  IF p_cantidad IS NULL OR p_cantidad < 1 THEN
    RAISE EXCEPTION 'La cantidad debe ser al menos 1';
  END IF;

  IF p_metodo_pago IS NULL
     OR p_metodo_pago NOT IN ('Efectivo', 'Nequi', 'Daviplata', 'Tarjeta') THEN
    RAISE EXCEPTION 'Método de pago inválido: %', COALESCE(p_metodo_pago, '(vacío)');
  END IF;

  IF p_dulzura IS NULL OR p_dulzura NOT IN ('Bajo', 'Normal', 'Alto') THEN
    RAISE EXCEPTION 'Nivel de dulzura inválido: %', COALESCE(p_dulzura, '(vacío)');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM direcciones
    WHERE id = p_direccion_id AND cliente_id = v_uid
  ) THEN
    RAISE EXCEPTION 'La dirección no existe o no pertenece al usuario';
  END IF;

  IF p_predisenhado_id IS NULL AND p_tamano_id IS NULL AND p_sabor_id IS NULL THEN
    RAISE EXCEPTION 'El pedido necesita un prediseñado, un tamaño o un sabor';
  END IF;

  -- ── Tipo de pedido + total, siempre desde el catálogo ─────────────────
  IF p_predisenhado_id IS NOT NULL THEN
    v_tipo := 'predisenhado';

    IF p_tamano_id IS NULL THEN
      RAISE EXCEPTION 'Debes elegir un tamaño para el prediseñado';
    END IF;

    SELECT precio_total, nombre INTO v_base, v_producto
      FROM predisenhados
     WHERE id = p_predisenhado_id AND activo;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'El prediseñado no existe o no está disponible';
    END IF;

    SELECT COALESCE(precio, 0) INTO v_tamano
      FROM tamanos_yogur WHERE id = p_tamano_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'El tamaño seleccionado no existe';
    END IF;

    p_frutas   := ARRAY[]::UUID[];
    p_extras   := ARRAY[]::UUID[];
    p_sabor_id := NULL;
  ELSE
    v_tipo := CASE
                WHEN p_sabor_id IS NULL THEN 'tradicional'
                ELSE 'personalizado'
              END;

    IF p_tamano_id IS NOT NULL THEN
      SELECT COALESCE(precio, 0) INTO v_base
        FROM tamanos_yogur WHERE id = p_tamano_id;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'El tamaño seleccionado no existe';
      END IF;
    ELSE
      -- Camino heredado: pedidos sin tamaño, de antes de que fuera
      -- obligatorio. Aquí `precio_base` es la única referencia que hay.
      SELECT COALESCE(precio_base, 0) INTO v_base
        FROM sabores WHERE id = p_sabor_id AND activo;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'El sabor no existe o no está disponible';
      END IF;
    END IF;

    IF p_sabor_id IS NOT NULL THEN
      -- NUEVO en la 0051: se lee el recargo junto al nombre, en la misma
      -- consulta que ya existía. Un viaje menos a la tabla.
      SELECT nombre, COALESCE(recargo, 0) INTO v_producto, v_recargo
        FROM sabores WHERE id = p_sabor_id AND activo;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'El sabor no existe o no está disponible';
      END IF;

      -- Sin tamaño el precio ya salió de `precio_base` por el camino
      -- heredado de arriba. Sumarle el recargo encima sería cobrar el
      -- sobrecosto del sabor dos veces.
      IF p_tamano_id IS NULL THEN
        v_recargo := 0;
      END IF;
    END IF;

    IF array_length(p_frutas, 1) IS NOT NULL THEN
      SELECT COALESCE(SUM(precio_adicional), 0), COUNT(*)
        INTO v_frutas, v_n_frutas
        FROM frutas
       WHERE id = ANY(p_frutas) AND disponible;

      IF v_n_frutas <> (SELECT COUNT(DISTINCT f) FROM unnest(p_frutas) AS f) THEN
        RAISE EXCEPTION 'Alguna de las frutas seleccionadas ya no está disponible';
      END IF;
    END IF;

    IF array_length(p_extras, 1) IS NOT NULL THEN
      SELECT COALESCE(SUM(precio_adicional), 0), COUNT(*)
        INTO v_extras, v_n_extras
        FROM extras
       WHERE id = ANY(p_extras) AND disponible;

      IF v_n_extras <> (SELECT COUNT(DISTINCT e) FROM unnest(p_extras) AS e) THEN
        RAISE EXCEPTION 'Alguno de los extras seleccionados ya no está disponible';
      END IF;
    END IF;
  END IF;

  -- v_tamano solo es distinto de 0 en el caso prediseñado. En el resto el
  -- precio del tamaño ya viene dentro de v_base, así que no se suma dos
  -- veces. v_recargo solo es distinto de 0 cuando hay sabor Y tamaño.
  v_total := (COALESCE(v_base, 0) + v_tamano + v_recargo
              + v_frutas + v_extras) * p_cantidad;

  -- ── Inserción atómica ─────────────────────────────────────────────────
  INSERT INTO pedidos (
    cliente_id, direccion_id, tipo, tamano_id, sabor_id, predisenhado_id,
    dulzura, cantidad, estado, total, metodo_pago
  ) VALUES (
    v_uid, p_direccion_id, v_tipo, p_tamano_id, p_sabor_id, p_predisenhado_id,
    p_dulzura, p_cantidad, 'Recibido', v_total, p_metodo_pago
  )
  RETURNING id INTO v_pedido_id;

  IF array_length(p_frutas, 1) IS NOT NULL THEN
    INSERT INTO pedido_frutas (pedido_id, fruta_id)
    SELECT v_pedido_id, f FROM unnest(p_frutas) AS f
    ON CONFLICT (pedido_id, fruta_id) DO NOTHING;
  END IF;

  IF array_length(p_extras, 1) IS NOT NULL THEN
    INSERT INTO pedido_extras (pedido_id, extra_id)
    SELECT v_pedido_id, e FROM unnest(p_extras) AS e
    ON CONFLICT (pedido_id, extra_id) DO NOTHING;
  END IF;

  INSERT INTO historial_estados (pedido_id, estado_anterior, estado_nuevo)
  VALUES (v_pedido_id, NULL, 'Recibido');

  -- ── Aviso a los administradores (viene de la 0046) ────────────────────
  -- Una fila por cada admin. Si mañana hay tres administradores, los tres
  -- se enteran.
  SELECT nombre INTO v_cliente FROM usuarios WHERE id = v_uid;

  INSERT INTO notificaciones (usuario_id, pedido_id, titulo, mensaje, tipo, leida)
  SELECT u.id,
         v_pedido_id,
         'Nuevo pedido',
         COALESCE(v_cliente, 'Un cliente') || ' pidió ' ||
           COALESCE(v_producto, 'un yogur') ||
           CASE WHEN p_cantidad > 1
                THEN ' (x' || p_cantidad || ')'
                ELSE '' END ||
           ' por $' || to_char(v_total, 'FM999G999G999'),
         'pedido_nuevo',
         FALSE
  FROM usuarios u
  WHERE u.rol = 'administrador';

  RETURN v_pedido_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.crear_pedido(
  UUID, TEXT, UUID, UUID, UUID, TEXT, UUID[], UUID[], INT
) TO authenticated;

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  3. COMPROBACIÓN                                                     ║
-- ╚══════════════════════════════════════════════════════════════════════╝
-- Todos los recargos arrancan en 0, así que ningún precio cambia hasta que
-- los pongas desde el panel de administración.
--
--   SELECT nombre, recargo, precio_base AS obsoleta
--     FROM public.sabores
--    WHERE activo
--    ORDER BY nombre;
--
-- Precio final de cada combinación sabor × tamaño:
--
--   SELECT s.nombre AS sabor,
--          t.nombre AS tamano,
--          t.precio + s.recargo AS precio_final
--     FROM public.sabores s
--     CROSS JOIN public.tamanos_yogur t
--    WHERE s.activo
--    ORDER BY s.nombre, t.precio;
