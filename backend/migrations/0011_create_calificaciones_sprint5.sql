-- Sprint 5 — adapted for plain PostgreSQL (Supabase RLS removed)
-- calificaciones table already created in 0009

-- Indexes (idempotent)
CREATE INDEX IF NOT EXISTS idx_calificaciones_pedido  ON calificaciones(pedido_id);
CREATE INDEX IF NOT EXISTS idx_calificaciones_cliente ON calificaciones(cliente_id);

-- Add updated_at to users if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'users' AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE users ADD COLUMN updated_at TIMESTAMPTZ DEFAULT now();
  END IF;
END $$;
