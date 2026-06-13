-- Migration 0020: Add metodo_pago column and CHECK constraint to public.pedidos.
--
-- El método de pago se capturaba en la app pero la columna y su CHECK constraint
-- ('pedidos_metodo_pago_valido') se habían creado directamente en Supabase, sin
-- quedar versionados. Esta migración los formaliza de forma idempotente.
-- Valores válidos: 'Efectivo', 'Nequi', 'Daviplata', 'Tarjeta'.

-- 1. Añadir la columna si no existe (nullable: pedidos antiguos pueden no tenerla)
ALTER TABLE public.pedidos
  ADD COLUMN IF NOT EXISTS metodo_pago TEXT;

-- 2. Normalizar datos existentes que pudieran estar en minúsculas
--    (antes del fix la app insertaba 'efectivo', 'nequi', etc.)
UPDATE public.pedidos
SET metodo_pago = initcap(metodo_pago)
WHERE metodo_pago IS NOT NULL
  AND metodo_pago <> initcap(metodo_pago);

-- 3. (Re)crear el CHECK constraint con los valores exactos esperados por la app
ALTER TABLE public.pedidos
  DROP CONSTRAINT IF EXISTS pedidos_metodo_pago_valido;

ALTER TABLE public.pedidos
  ADD CONSTRAINT pedidos_metodo_pago_valido
  CHECK (metodo_pago IS NULL
         OR metodo_pago IN ('Efectivo', 'Nequi', 'Daviplata', 'Tarjeta'));
