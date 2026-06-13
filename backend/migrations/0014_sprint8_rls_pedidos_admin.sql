-- Sprint 8 — adapted for plain PostgreSQL (Supabase RLS removed)

-- fcm_token already added in 0010, this is a safety check
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'users' AND column_name = 'fcm_token'
  ) THEN
    ALTER TABLE users ADD COLUMN fcm_token TEXT;
  END IF;
END $$;
