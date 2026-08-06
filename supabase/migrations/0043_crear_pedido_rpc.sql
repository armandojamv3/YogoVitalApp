-- Migration 0043: crear_pedido() — creación de pedidos atómica y con el
-- total calculado del lado del servidor.
--
-- ── PROBLEMA 1: REGRESIÓN de la 0041 — el total dejó de incluir frutas ───
-- PedidoSupabaseRepository.createPedido() hace 4 INSERT sueltos, en este
-- orden: pedidos → pedido_frutas → pedido_extras → historial_estados.
-- trg_fijar_total_pedido es BEFORE INSERT sobre `pedidos` y sobrescribe
-- NEW.total con calcular_total_pedido(), que suma frutas y extras leyendo
-- pedido_frutas / pedido_extras... filas que en ese instante TODAVÍA NO
-- EXISTEN, porque se insertan después.
--
-- La migración 0035 resolvía esto con trg_recalcular_total_desde_detalle:
-- un AFTER INSERT en pedido_frutas/pedido_extras que "tocaba" la fila del
-- pedido (UPDATE pedidos SET updated_at = updated_at) para que el trigger
-- BEFORE UPDATE recalculara el total, esta vez con los ingredientes ya
-- guardados. Funcionaba.
--
-- La migración 0041 lo rompió sin querer. Para evitar que un simple cambio
-- de estado disparara el cálculo del total, restringió el recálculo en
-- UPDATE a los casos en que `tamano_id IS DISTINCT FROM OLD.tamano_id`.
-- Pero el "toque" de la 0035 no cambia tamano_id — solo reescribe
-- updated_at — así que desde el 30 de julio ese UPDATE ya no recalcula
-- nada. Resultado: el total guardado quedó siendo solo el precio del
-- tamaño, y cada pedido con frutas o extras se cobra de menos.
--
-- En vez de reponer el mecanismo de los dos triggers encadenados (frágil,
-- y ya falló una vez), esta migración calcula el total de una sola vez,
-- antes de insertar, dentro de crear_pedido().
--
-- ── PROBLEMA 2: createPedidoFromCartItem() confiaba en el cliente ────────
-- Ese método no manda tamano_id, así que el trigger no tocaba el total y
-- se guardaba tal cual venía de la app. Cualquiera con la anon key podía
-- insertar un pedido con total = 0.
--
-- ── PROBLEMA 3: la creación no era atómica ──────────────────────────────
-- Si fallaba el INSERT de pedido_frutas o el de historial_estados, el
-- pedido ya estaba creado y quedaba huérfano, sin ingredientes o sin
-- historial, imposible de reconstruir.
--
-- ── SOLUCIÓN ────────────────────────────────────────────────────────────
-- Una única función crear_pedido() SECURITY DEFINER que:
--   1. Valida sesión, dirección, método de pago y cantidad.
--   2. Calcula el total leyendo SIEMPRE los precios del catálogo
--      (tamanos_yogur, sabores, frutas, extras, predisenhados). El precio
--      que manda la app pasa a ser solo informativo para la UI.
--   3. Inserta pedido + frutas + extras + historial en una sola
--      transacción (el cuerpo de una función plpgsql ya lo es): si algo
--      falla, no queda nada a medias.
-- Y se cierra el INSERT directo sobre `pedidos` desde la API de cliente,
-- para que esta función sea el único camino posible.
--
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query → Run
-- Es idempotente: se puede correr varias veces sin daño.

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  1. AJUSTES DE SCHEMA                                                ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- Los pedidos que salen del carrito con un prediseñado no tienen sabor ni
-- tamaño propios: el prediseñado ya trae su precio cerrado. Guardamos la
-- referencia para poder reconstruir el pedido y para cobrar del catálogo.
ALTER TABLE public.pedidos
  ADD COLUMN IF NOT EXISTS predisenhado_id UUID REFERENCES public.predisenhados(id);

-- Cantidad de unidades del mismo ítem (el carrito ya la manejaba, pero
-- solo existía en memoria: se multiplicaba en Dart y se perdía).
ALTER TABLE public.pedidos
  ADD COLUMN IF NOT EXISTS cantidad INT NOT NULL DEFAULT 1;

ALTER TABLE public.pedidos
  DROP CONSTRAINT IF EXISTS pedidos_cantidad_positiva;
ALTER TABLE public.pedidos
  ADD CONSTRAINT pedidos_cantidad_positiva CHECK (cantidad >= 1);

-- Un pedido de carrito no lleva tamaño ni sabor propios. La app ya venía
-- insertando filas así (ver comentario en createPedidoFromCartItem), pero
-- el NOT NULL nunca se relajó de forma versionada.
ALTER TABLE public.pedidos ALTER COLUMN tamano_id DROP NOT NULL;
ALTER TABLE public.pedidos ALTER COLUMN sabor_id  DROP NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pedidos_predisenhado
  ON public.pedidos(predisenhado_id);


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  2. EL TRIGGER YA NO PISA EL TOTAL EN EL INSERT                      ║
-- ╚══════════════════════════════════════════════════════════════════════╝
-- Este es el fix del PROBLEMA 1. A partir de ahora el total lo fija
-- crear_pedido() con los ingredientes ya conocidos, así que el trigger no
-- tiene nada que recalcular al crear. Se conserva el recálculo en UPDATE
-- (cuando cambia tamano_id), donde sí es correcto: en ese momento las
-- filas de pedido_frutas / pedido_extras ya existen.

CREATE OR REPLACE FUNCTION public.trg_fijar_total_pedido()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- INSERT: no se toca NEW.total. Viene de crear_pedido(), que ya lo
  -- calculó desde el catálogo con frutas y extras incluidos. Recalcularlo
  -- aquí daría de menos, porque pedido_frutas/pedido_extras se llenan
  -- después de esta fila.
  -- Los IF van anidados, NO como un solo AND: en un BEFORE INSERT el
  -- registro OLD no está asignado, y Postgres no garantiza cortocircuito
  -- al evaluar AND (la migración 0042 ya se topó con esto). Un
  -- `TG_OP = 'UPDATE' AND ... OLD.tamano_id ...` podría intentar leer OLD
  -- durante un INSERT y reventar con "record 'old' is not assigned yet".
  IF TG_OP = 'UPDATE' THEN
    IF NEW.tamano_id IS NOT NULL
       AND NEW.tamano_id IS DISTINCT FROM OLD.tamano_id THEN
      BEGIN
        NEW.total := public.calcular_total_pedido(NEW.tamano_id, NEW.id);
      EXCEPTION WHEN OTHERS THEN
        -- No dejar que un fallo aquí bloquee el UPDATE completo del pedido
        -- (por ejemplo, un cambio de estado hecho por el admin).
        RAISE WARNING 'calcular_total_pedido falló al actualizar pedido %: %',
          NEW.id, SQLERRM;
      END;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- Los triggers que "tocaban" el pedido desde pedido_frutas/pedido_extras
-- (migración 0035) ya no sirven para nada: desde la 0041 ese UPDATE no
-- recalcula el total, y ahora el total lo fija crear_pedido() antes de
-- insertar. Se eliminan para que no queden dos mecanismos compitiendo por
-- el mismo campo — que es exactamente lo que causó esta regresión.
DROP TRIGGER IF EXISTS trg_recalcular_total_frutas ON public.pedido_frutas;
DROP TRIGGER IF EXISTS trg_recalcular_total_extras ON public.pedido_extras;
DROP FUNCTION IF EXISTS public.trg_recalcular_total_desde_detalle();


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  3. crear_pedido() — punto de entrada único                          ║
-- ╚══════════════════════════════════════════════════════════════════════╝

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
  v_uid       UUID := auth.uid();
  v_pedido_id UUID;
  v_base      NUMERIC := 0;
  v_frutas    NUMERIC := 0;
  v_extras    NUMERIC := 0;
  v_total     NUMERIC := 0;
  v_n_frutas  INT;
  v_n_extras  INT;
BEGIN
  -- ── Validaciones ──────────────────────────────────────────────────────
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  IF p_cantidad IS NULL OR p_cantidad < 1 THEN
    RAISE EXCEPTION 'La cantidad debe ser al menos 1';
  END IF;

  -- Mismos valores que el CHECK 'pedidos_metodo_pago_valido' (migración 0020)
  IF p_metodo_pago IS NULL
     OR p_metodo_pago NOT IN ('Efectivo', 'Nequi', 'Daviplata', 'Tarjeta') THEN
    RAISE EXCEPTION 'Método de pago inválido: %', COALESCE(p_metodo_pago, '(vacío)');
  END IF;

  IF p_dulzura IS NULL OR p_dulzura NOT IN ('Bajo', 'Normal', 'Alto') THEN
    RAISE EXCEPTION 'Nivel de dulzura inválido: %', COALESCE(p_dulzura, '(vacío)');
  END IF;

  -- La dirección tiene que ser del propio cliente. Como esta función es
  -- SECURITY DEFINER (se salta RLS), esta comprobación es obligatoria:
  -- sin ella un cliente podría mandar el id de la dirección de otro.
  IF NOT EXISTS (
    SELECT 1 FROM direcciones
    WHERE id = p_direccion_id AND cliente_id = v_uid
  ) THEN
    RAISE EXCEPTION 'La dirección no existe o no pertenece al usuario';
  END IF;

  IF p_predisenhado_id IS NULL AND p_tamano_id IS NULL AND p_sabor_id IS NULL THEN
    RAISE EXCEPTION 'El pedido necesita un prediseñado, un tamaño o un sabor';
  END IF;

  -- ── Cálculo del total, siempre desde el catálogo ──────────────────────
  IF p_predisenhado_id IS NOT NULL THEN
    -- Prediseñado: precio cerrado, no admite frutas ni extras sueltos.
    SELECT precio_total INTO v_base
      FROM predisenhados
     WHERE id = p_predisenhado_id AND activo;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'El prediseñado no existe o no está disponible';
    END IF;

    p_frutas    := ARRAY[]::UUID[];
    p_extras    := ARRAY[]::UUID[];
    p_tamano_id := NULL;
    p_sabor_id  := NULL;
  ELSE
    -- Personalizado o sabor suelto: base = tamaño si lo hay, si no el sabor.
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

    -- El sabor, cuando además hay tamaño, es solo la elección de sabor del
    -- yogur personalizado: se valida pero no suma aparte del tamaño.
    IF p_tamano_id IS NOT NULL AND p_sabor_id IS NOT NULL THEN
      IF NOT EXISTS (SELECT 1 FROM sabores WHERE id = p_sabor_id AND activo) THEN
        RAISE EXCEPTION 'El sabor no existe o no está disponible';
      END IF;
    END IF;

    -- Frutas: se cobran solo las que existen y están disponibles. Si la app
    -- mandó alguna que no lo está, se rechaza el pedido entero en vez de
    -- cobrarla de menos en silencio.
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

  v_total := (COALESCE(v_base, 0) + v_frutas + v_extras) * p_cantidad;

  -- ── Inserción atómica ─────────────────────────────────────────────────
  INSERT INTO pedidos (
    cliente_id, direccion_id, tamano_id, sabor_id, predisenhado_id,
    dulzura, cantidad, estado, total, metodo_pago
  ) VALUES (
    v_uid, p_direccion_id, p_tamano_id, p_sabor_id, p_predisenhado_id,
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


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  4. CERRAR EL INSERT DIRECTO SOBRE `pedidos`                         ║
-- ╚══════════════════════════════════════════════════════════════════════╝
-- Este es el fix del PROBLEMA 2. Al quitar la política de INSERT, la API
-- de cliente (PostgREST) ya no puede insertar en `pedidos` bajo ningún
-- concepto — ni con un total manipulado. crear_pedido() sigue funcionando
-- porque es SECURITY DEFINER: corre como el dueño de la tabla y no pasa
-- por RLS.
--
-- Verificado antes de aplicar: los únicos INSERT sobre `pedidos` en la app
-- estaban en PedidoSupabaseRepository (createPedido y
-- createPedidoFromCartItem), ambos migrados a esta RPC.

-- Se eliminan por nombre real (pedidos_insert_own, presente desde la 0015)
-- y además con un barrido por cmd = 'INSERT', porque a lo largo de las
-- migraciones 0015 → 0035 esta política se recreó varias veces y no hay
-- garantía de qué nombres quedaron vivos en la base real.
DROP POLICY IF EXISTS "pedidos_insert_own" ON public.pedidos;

DO $$
DECLARE
  pol TEXT;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'pedidos' AND cmd = 'INSERT'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.pedidos', pol);
  END LOOP;
END;
$$;

-- NOTA — pedido_frutas / pedido_extras se dejan como están a propósito.
-- Sus políticas están repartidas entre la 0018, la 0022, la 0025 y
-- SUPABASE_SETUP.sql, con nombres que se pisan entre sí (_access FOR ALL,
-- _select, _insert), y no hay forma de saber desde el repo cuáles quedaron
-- vivas en la base real. Tocarlas a ciegas se arriesga a romper la lectura
-- del detalle del pedido, que es lo que usan la factura, el historial y el
-- panel de admin.
--
-- El riesgo residual es acotado: con el total ya fijado al crear el pedido,
-- insertar una fruta a mano después NO abarata el pedido — como mucho
-- regala un ingrediente. Conviene limpiarlo, pero en una migración aparte
-- y después de listar en el dashboard qué políticas existen de verdad:
--   SELECT tablename, policyname, cmd, qual FROM pg_policies
--   WHERE tablename IN ('pedido_frutas', 'pedido_extras');


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  5. VERIFICACIÓN                                                     ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- 5.1 La función existe y es SECURITY DEFINER
SELECT proname, prosecdef AS security_definer
FROM pg_proc
WHERE proname = 'crear_pedido';

-- 5.2 Ya no queda ninguna política de INSERT en pedidos ni en las puente
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('pedidos', 'pedido_frutas', 'pedido_extras')
ORDER BY tablename, policyname;

-- 5.3 Columnas nuevas en pedidos
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'pedidos'
  AND column_name IN ('predisenhado_id', 'cantidad', 'tamano_id', 'sabor_id')
ORDER BY column_name;

-- 5.4 Pedidos históricos con el total mal calculado (frutas/extras sin
--     cobrar). Solo diagnóstico — NO se corrigen solos, porque cambiar el
--     total de un pedido ya entregado y facturado no sería correcto.
SELECT p.id,
       p.created_at::date AS fecha,
       p.total            AS total_cobrado,
       COALESCE(t.precio, 0)
         + COALESCE(pf.suma, 0)
         + COALESCE(pe.suma, 0) AS total_correcto
FROM pedidos p
LEFT JOIN tamanos_yogur t ON t.id = p.tamano_id
LEFT JOIN (
  SELECT pf.pedido_id, SUM(f.precio_adicional) AS suma
  FROM pedido_frutas pf JOIN frutas f ON f.id = pf.fruta_id
  GROUP BY pf.pedido_id
) pf ON pf.pedido_id = p.id
LEFT JOIN (
  SELECT pe.pedido_id, SUM(e.precio_adicional) AS suma
  FROM pedido_extras pe JOIN extras e ON e.id = pe.extra_id
  GROUP BY pe.pedido_id
) pe ON pe.pedido_id = p.id
WHERE p.tamano_id IS NOT NULL
  AND p.total <> COALESCE(t.precio, 0) + COALESCE(pf.suma, 0) + COALESCE(pe.suma, 0)
ORDER BY p.created_at DESC;
