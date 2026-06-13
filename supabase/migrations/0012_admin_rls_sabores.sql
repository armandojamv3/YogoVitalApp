-- Sprint 6 — adapted for plain PostgreSQL (Supabase RLS removed)

-- Ensure activo column exists on sabores (already present from 0009)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'sabores' AND column_name = 'activo'
  ) THEN
    ALTER TABLE sabores ADD COLUMN activo BOOLEAN NOT NULL DEFAULT true;
  END IF;
END $$;
