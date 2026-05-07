-- Migration: create table to persist resend attempts for verification emails
CREATE TABLE IF NOT EXISTS public.email_verification_resends (
  id bigserial PRIMARY KEY,
  email character varying NOT NULL,
  created_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_email_verification_resends_email_created_at ON public.email_verification_resends (email, created_at);
