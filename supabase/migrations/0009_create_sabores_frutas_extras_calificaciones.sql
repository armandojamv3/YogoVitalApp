-- Migration 0009: Create tables for pedidos, sabores, frutas, extras, and calificaciones, and alter users to support roles.

-- Add rol to public.users if not exists
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS rol TEXT NOT NULL DEFAULT 'cliente';

CREATE TABLE IF NOT EXISTS public.pedidos (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cliente_id  BIGINT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  direccion   TEXT,
  total       NUMERIC(10,2) NOT NULL CHECK (total >= 0),
  estado      TEXT NOT NULL DEFAULT 'Recibido',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.sabores (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre      TEXT NOT NULL UNIQUE,
  descripcion TEXT NOT NULL,
  precio_base NUMERIC(10,2) NOT NULL CHECK (precio_base > 0),
  activo      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.frutas (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre           TEXT NOT NULL UNIQUE,
  precio_adicional NUMERIC(10,2) NOT NULL CHECK (precio_adicional >= 0),
  disponible       BOOLEAN NOT NULL DEFAULT TRUE,
  imagen_url       TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.extras (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre           TEXT NOT NULL UNIQUE,
  precio_adicional NUMERIC(10,2) NOT NULL CHECK (precio_adicional >= 0),
  disponible       BOOLEAN NOT NULL DEFAULT TRUE,
  imagen_url       TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.calificaciones (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_id   UUID NOT NULL REFERENCES public.pedidos(id) ON DELETE CASCADE UNIQUE,
  cliente_id  BIGINT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  estrellas   INT NOT NULL CHECK (estrellas >= 1 AND estrellas <= 5),
  comentario  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
