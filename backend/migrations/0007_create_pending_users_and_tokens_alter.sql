-- Create pending_users table and alter email_verification_tokens to support pending_user_id

CREATE TABLE IF NOT EXISTS public.pending_users (
  id BIGSERIAL PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  name TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Make user_id nullable to allow tokens for pending users
ALTER TABLE public.email_verification_tokens ALTER COLUMN user_id DROP NOT NULL;

-- Add pending_user_id column referencing pending_users
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'email_verification_tokens' AND column_name = 'pending_user_id'
  ) THEN
    ALTER TABLE public.email_verification_tokens ADD COLUMN pending_user_id BIGINT REFERENCES public.pending_users(id) ON DELETE CASCADE;
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS idx_ev_tokens_pending_user_id ON public.email_verification_tokens(pending_user_id);
