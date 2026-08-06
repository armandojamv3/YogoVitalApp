-- Migration 0044: crear_pedido() aprende a llenar `tipo`, y un prediseñado
-- deja de necesitar sabor.
--
-- ── SÍNTOMA ─────────────────────────────────────────────────────────────
-- Al confirmar un pedido de prediseñado desde la app:
--   PostgrestException: new row for relation "pedidos" violates check
--   constraint "pedidos_predisenhado_segun_tipo" (23514)
--
-- ── CAUSA 1: desfase de esquema ─────────────────────────────────────────
-- La tabla `pedidos` real tiene dos columnas y tres CHECK constraints que
-- NO existen en ninguna migración de este repo ni en SUPABASE_SETUP.sql:
--
--   tipo         TEXT NOT NULL DEFAULT 'personalizado'
--   costo_envio  NUMERIC NOT NULL DEFAULT 3000
--
--   pedidos_tipo_valido
--     tipo ∈ ('personalizado', 'tradicional', 'predisenhado')
--
--   pedidos_predisenhado_segun_tipo
--     'predisenhado'                  → predisenhado_id NOT NULL
--     'personalizado' | 'tradicional' → predisenhado_id NULL
--
--   pedidos_sabor_segun_tipo
--     'tradicional'                   → sabor_id NULL
--     'personalizado' | 'predisenhado'→ sabor_id NOT NULL
--
-- La 0043 se escribió leyendo el repo, así que crear_pedido() nunca setea
-- `tipo`: se queda en el default 'personalizado'. Al insertar un pedido
-- con predisenhado_id lleno y tipo='personalizado', el segundo constraint
-- lo rechaza.
--
-- Es el cuarto caso del mismo problema: las migraciones 0026, 0031 y 0037
-- existen solo para reconciliar cosas creadas a mano en el dashboard. Esta
-- migración las deja versionadas para cortar la racha.
--
-- ── CAUSA 2: dos diseños de prediseñado peleando ────────────────────────
-- pedidos_sabor_segun_tipo exige que un pedido de prediseñado tenga sabor.
-- Pero la migración 0038 ya había declarado obsoletos `sabor_id` y
-- `tamano_id` en la tabla `predisenhados`, con este argumento textual:
--
--   "el diseño actual (con la columna `ingredientes` como lista libre) no
--    usa esos campos, así que los volvemos nullable para que el admin
--    pueda crear prediseñados sin necesitar esos datos"
--
-- El panel de admin, en consecuencia, nunca pide un sabor al crear un
-- prediseñado. Así que ese constraint pide un dato que el producto ya
-- había decidido no tener: es la regla del diseño viejo, sobreviviendo.
--
-- Decisión (confirmada con el equipo): un prediseñado es un producto
-- cerrado — su receta son sus `ingredientes` y su precio es `precio_total`.
-- No tiene sabor ni tamaño propios. Se relaja el constraint en vez de
-- reintroducir el diseño anterior.
--
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query → Run
-- Es idempotente.

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  1. DOCUMENTAR LAS COLUMNAS QUE FALTABAN EN EL REPO                  ║
-- ╚══════════════════════════════════════════════════════════════════════╝
-- No cambian nada si ya existen (que es el caso). Están aquí para que una
-- base creada desde cero con estas migraciones quede igual que la real.

ALTER TABLE public.pedidos
  ADD COLUMN IF NOT EXISTS tipo TEXT NOT NULL DEFAULT 'personalizado';

ALTER TABLE public.pedidos
  ADD COLUMN IF NOT EXISTS costo_envio NUMERIC(10,2) NOT NULL DEFAULT 3000;

ALTER TABLE public.pedidos
  DROP CONSTRAINT IF EXISTS pedidos_tipo_valido;
ALTER TABLE public.pedidos
  ADD CONSTRAINT pedidos_tipo_valido
  CHECK (tipo IN ('personalizado', 'tradicional', 'predisenhado'));

ALTER TABLE public.pedidos
  DROP CONSTRAINT IF EXISTS pedidos_predisenhado_segun_tipo;
ALTER TABLE public.pedidos
  ADD CONSTRAINT pedidos_predisenhado_segun_tipo
  CHECK (
    (tipo = 'predisenhado' AND predisenhado_id IS NOT NULL)
    OR (tipo IN ('personalizado', 'tradicional') AND predisenhado_id IS NULL)
  );


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  2. UN PREDISEÑADO YA NO NECESITA SABOR                              ║
-- ╚══════════════════════════════════════════════════════════════════════╝
-- Cambio real respecto a lo que hay hoy en la base. Antes:
--     'personalizado' | 'predisenhado' → sabor_id NOT NULL
-- Ahora 'predisenhado' queda libre: puede llevar sabor o no.
--
-- Se mantiene la exigencia para 'personalizado' (un yogur personalizado sí
-- se arma eligiendo un sabor) y para 'tradicional' (que por definición no
-- lleva sabor, solo tamaño).

ALTER TABLE public.pedidos
  DROP CONSTRAINT IF EXISTS pedidos_sabor_segun_tipo;
ALTER TABLE public.pedidos
  ADD CONSTRAINT pedidos_sabor_segun_tipo
  CHECK (
    (tipo = 'tradicional'   AND sabor_id IS NULL)
    OR (tipo = 'personalizado' AND sabor_id IS NOT NULL)
    OR (tipo = 'predisenhado')  -- con o sin sabor: da igual
  );


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  3. crear_pedido() DECIDE EL TIPO                                    ║
-- ╚══════════════════════════════════════════════════════════════════════╝
-- Igual que la versión de la 0043, con una sola diferencia de fondo: ahora
-- calcula `tipo` a partir de lo que recibe y lo inserta explícitamente, en
-- vez de dejar que caiga en el default.
--
--   predisenhado_id            → 'predisenhado'
--   tamaño sin sabor           → 'tradicional'
--   el resto (con sabor)       → 'personalizado'

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
  v_tipo      TEXT;
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

    SELECT precio_total INTO v_base
      FROM predisenhados
     WHERE id = p_predisenhado_id AND activo;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'El prediseñado no existe o no está disponible';
    END IF;

    -- Producto cerrado: ni sabor, ni tamaño, ni ingredientes sueltos.
    p_frutas    := ARRAY[]::UUID[];
    p_extras    := ARRAY[]::UUID[];
    p_tamano_id := NULL;
    p_sabor_id  := NULL;
  ELSE
    -- 'tradicional' = solo tamaño, sin sabor. Es la única combinación que
    -- pedidos_sabor_segun_tipo permite con sabor_id en NULL.
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

  v_total := (COALESCE(v_base, 0) + v_frutas + v_extras) * p_cantidad;

  -- ── Inserción atómica ─────────────────────────────────────────────────
  -- costo_envio no se toca: lo pone el DEFAULT de la columna, que es la
  -- única fuente de verdad de cuánto cuesta el envío.
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


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  4. VERIFICACIÓN                                                     ║
-- ╚══════════════════════════════════════════════════════════════════════╝
-- Correr después del COMMIT, una a la vez.

-- 4.1 Los constraints quedaron como se espera
SELECT c.conname,
       g.i AS parte,
       substr(pg_get_constraintdef(c.oid), (g.i - 1) * 55 + 1, 55) AS texto
FROM pg_constraint c
CROSS JOIN LATERAL generate_series(
       1, ceil(length(pg_get_constraintdef(c.oid)) / 55.0)::int
     ) AS g(i)
WHERE c.conrelid = 'public.pedidos'::regclass
  AND c.contype = 'c'
  AND c.conname LIKE '%tipo%'
ORDER BY c.conname, g.i;

-- 4.2 Reparto de pedidos por tipo (los históricos son todos
--     'personalizado' por el DEFAULT; los nuevos ya se distinguen)
SELECT tipo,
       COUNT(*)                                  AS pedidos,
       COUNT(*) FILTER (WHERE sabor_id IS NULL)   AS sin_sabor,
       COUNT(*) FILTER (WHERE tamano_id IS NULL)  AS sin_tamano,
       COUNT(*) FILTER (WHERE predisenhado_id IS NOT NULL) AS con_predisenhado
FROM pedidos
GROUP BY tipo
ORDER BY tipo;
