-- Migration 0046: avisar al administrador cuando entra un pedido nuevo.
--
-- ── EL PROBLEMA ─────────────────────────────────────────────────────────
-- Las notificaciones del proyecto van en un solo sentido: del admin al
-- cliente. Se crean en un único punto, cambiarEstado(), con mensajes como
-- "Tu yogur está siendo preparado".
--
-- Cuando un cliente hace un pedido no se crea ningún aviso para nadie. El
-- administrador solo se entera si tiene abierta la pantalla de pedidos —y
-- aun así, en silencio, porque el Realtime actualiza la lista sin avisar—
-- o si entra a mirar por su cuenta.
--
-- Para un negocio de comida eso significa pedidos entrando sin que nadie
-- lo sepa.
--
-- ── LA SOLUCIÓN ─────────────────────────────────────────────────────────
-- crear_pedido() inserta además una fila en `notificaciones` para CADA
-- usuario con rol 'administrador'. Al ir dentro de la misma función, entra
-- en la misma transacción: o se guardan pedido y avisos, o no se guarda
-- nada.
--
-- La notificación persiste en la base, que es lo que la hace útil: si el
-- admin tuvo la app cerrada tres horas, al abrirla ve los pedidos que
-- entraron mientras tanto. Un aviso en tiempo real que se pierde si nadie
-- está mirando no sirve de mucho.
--
-- No hace falta tocar RLS. La política "notificaciones_select_own" ya deja
-- que cada quien lea las suyas (usuario_id = auth.uid()), y la inserción la
-- hace esta función como SECURITY DEFINER, sin pasar por RLS.
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
      SELECT COALESCE(precio_base, 0) INTO v_base
        FROM sabores WHERE id = p_sabor_id AND activo;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'El sabor no existe o no está disponible';
      END IF;
    END IF;

    IF p_sabor_id IS NOT NULL THEN
      SELECT nombre INTO v_producto FROM sabores
       WHERE id = p_sabor_id AND activo;
      IF NOT FOUND THEN
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

  -- ── NUEVO en la 0046: avisar a los administradores ────────────────────
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


-- ── Verificación ─────────────────────────────────────────────────────────
-- Correr después del COMMIT.

-- 1. ¿Hay algún administrador a quien avisar? Si esto sale vacío, la
--    notificación no se creará para nadie.
SELECT id, nombre, correo FROM usuarios WHERE rol = 'administrador';

-- 2. Avisos de pedidos nuevos ya generados (tras hacer un pedido de prueba)
SELECT n.created_at, n.titulo, n.mensaje, n.leida, u.nombre AS destinatario
FROM notificaciones n
JOIN usuarios u ON u.id = n.usuario_id
WHERE n.tipo = 'pedido_nuevo'
ORDER BY n.created_at DESC
LIMIT 10;
