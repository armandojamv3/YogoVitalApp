-- Migración 0021: Hacer campos críticos obligatorios

BEGIN;

-- Estos ya se ejecutaron manualmente en Supabase (2026-06-13):
ALTER TABLE public.pedidos ALTER COLUMN direccion_id SET NOT NULL;
ALTER TABLE public.usuarios ALTER COLUMN nombre SET NOT NULL;
ALTER TABLE public.predisenhados ALTER COLUMN sabor_id SET NOT NULL;
ALTER TABLE public.predisenhados ALTER COLUMN tamano_id SET NOT NULL;

-- Este se ejecutará después de hacer metodo_pago obligatorio en la app:
ALTER TABLE public.pedidos ALTER COLUMN metodo_pago SET NOT NULL;

COMMIT;
