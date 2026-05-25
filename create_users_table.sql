-- Crear tabla users en yogo_vital_db
-- Ejecutar este script conectado a la BD yogo_vital_db

CREATE TABLE IF NOT EXISTS public.users (
  id BIGSERIAL PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  name VARCHAR(255),
  telefono VARCHAR(50),
  email_verified BOOLEAN DEFAULT FALSE,
  verification_token VARCHAR(255),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Crear índice en email para búsquedas más rápidas
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);

-- Crear índice en created_at para ordenar por fecha
CREATE INDEX IF NOT EXISTS idx_users_created_at ON public.users(created_at);
