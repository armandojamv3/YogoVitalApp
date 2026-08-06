-- Migration 0045: un prediseñado ahora se pide con tamaño, y el tamaño
-- entra en el precio.
--
-- ── QUÉ CAMBIA ──────────────────────────────────────────────────────────
-- Hasta la 0044 un prediseñado era un producto totalmente cerrado: precio
-- único (`predisenhados.precio_total`) y sin tamaño. En la app se veía raro
-- — el cliente no podía elegir si quería un Personal o un 2 Litros — y en
-- el historial el pedido salía sin tamaño ninguno.
--
-- A partir de aquí:
--   * El tamaño es OBLIGATORIO al pedir un prediseñado.
--   * Sale del mismo catálogo que usan los típicos: `tamanos_yogur`.
--   * El precio se calcula: precio_total (la receta) + precio del tamaño,
--     todo multiplicado por la cantidad.
--
-- Ejemplo — Tropical Explosión (12.000) en 2 Litros (25.000), 2 unidades:
--     (12000 + 25000) * 2 = 74000
--
-- Es la misma fórmula que ya usa el personalizado (tamaño + ingredientes),
-- donde `precio_total` ocupa el lugar de los ingredientes.
--
-- ── NO HACE FALTA TOCAR CONSTRAINTS ─────────────────────────────────────
-- pedidos_predisenhado_segun_tipo solo habla de `predisenhado_id`, y
-- pedidos_sabor_segun_tipo (tal como quedó en la 0044) deja libre el caso
-- 'predisenhado'. Ninguno restringe `tamano_id`, así que un pedido de
-- prediseñado ya puede llevarlo sin cambiar ninguna regla.
--
-- ── PEDIDOS ANTERIORES ──────────────────────────────────────────────────
-- Los prediseñados pedidos antes de esta migración se quedan con
-- tamano_id en NULL. No se tocan: cambiarles el tamaño a posteriori sería
-- inventar un dato que nadie eligió. La app los muestra sin tamaño.
--
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query → Run
-- Es idempotente.

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
  v_frutas     NUMERIC := 0;
  v_extras     NUMERIC := 0;
  v_total      NUMERIC := 0;
  v_n_frutas   INT;
  v_n_extras   INT;
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

    -- NUEVO en la 0045: el tamaño es obligatorio.
    IF p_tamano_id IS NULL THEN
      RAISE EXCEPTION 'Debes elegir un tamaño para el prediseñado';
    END IF;

    SELECT precio_total INTO v_base
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

    -- La receta ya trae sus ingredientes: no admite frutas ni extras
    -- sueltos, ni sabor propio. El tamaño sí se conserva.
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
      SELECT COALESCE(precio_base, 0) INTO v_base
        FROM sabores WHERE id = p_sabor_id AND activo;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'El sabor no existe o no está disponible';
      END IF;
    END IF;

    IF p_tamano_id IS NOT NULL AND p_sabor_id IS NOT NULL THEN
      IF NOT EXISTS (SELECT 1 FROM sabores WHERE id = p_sabor_id AND activo) THEN
        RAISE EXCEPTION 'El sabor no existe o no está disponible';
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
  -- veces.
  v_total := (COALESCE(v_base, 0) + v_tamano + v_frutas + v_extras) * p_cantidad;

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

  RETURN v_pedido_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.crear_pedido(
  UUID, TEXT, UUID, UUID, UUID, TEXT, UUID[], UUID[], INT
) TO authenticated;


-- ── Verificación ─────────────────────────────────────────────────────────
-- Correr después del COMMIT. Los pedidos de prediseñado nuevos deben salir
-- con tamaño y con total = (precio_total + precio del tamaño) * cantidad.
SELECT p.created_at::date AS fecha,
       pr.nombre          AS predisenhado,
       pr.precio_total    AS precio_receta,
       t.nombre           AS tamano,
       t.precio           AS precio_tamano,
       p.cantidad,
       p.total            AS total_cobrado,
       (pr.precio_total + COALESCE(t.precio, 0)) * p.cantidad AS total_esperado
FROM pedidos p
JOIN predisenhados pr ON pr.id = p.predisenhado_id
LEFT JOIN tamanos_yogur t ON t.id = p.tamano_id
WHERE p.tipo = 'predisenhado'
ORDER BY p.created_at DESC;
