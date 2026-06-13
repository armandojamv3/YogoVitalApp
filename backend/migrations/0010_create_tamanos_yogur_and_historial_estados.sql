-- Migration 0010: Create tables for tamanos_yogur and historial_estados, and alter users to add telefono and fcm_token.

-- Add columns to public.users if they don't exist
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS telefono TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- Tabla historial_estados
CREATE TABLE IF NOT EXISTS public.historial_estados (
  id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  pedido_id      UUID NOT NULL REFERENCES public.pedidos(id) ON DELETE CASCADE,
  estado_anterior TEXT,
  estado_nuevo    TEXT NOT NULL,
  fecha_cambio   TIMESTAMPTZ DEFAULT now(),
  admin_id       BIGINT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE
);

-- Tabla tamanos_yogur
CREATE TABLE IF NOT EXISTS public.tamanos_yogur (
  id     UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  nombre TEXT NOT NULL UNIQUE,
  precio NUMERIC(10,2) NOT NULL CHECK (precio >= 0)
);

-- Insert sizes
INSERT INTO public.tamanos_yogur (nombre, precio) VALUES 
  ('Personal', 5000), 
  ('½ Litro', 8000), 
  ('1 Litro', 14000), 
  ('2 Litros', 25000)
ON CONFLICT (nombre) DO UPDATE SET precio = EXCLUDED.precio;
