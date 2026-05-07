-- Migration: add used_at column to email_verification_tokens
ALTER TABLE IF EXISTS public.email_verification_tokens
  ADD COLUMN IF NOT EXISTS used_at timestamptz;
