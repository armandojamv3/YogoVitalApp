-- Create auth events table for auditing
CREATE TABLE IF NOT EXISTS public.auth_events (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT,
  event_type TEXT NOT NULL,
  ip_address TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
