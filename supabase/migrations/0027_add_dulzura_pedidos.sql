-- Migration 0027: Add nivel de dulzura a public.pedidos.
--
-- Objetivo 3 del proyecto: la personalización del pedido debe permitir
-- elegir, además de ingredientes, un nivel de dulzura ('Bajo', 'Normal',
-- 'Alto'). La columna no existía en ninguna capa (BD/modelo/UI).
-- Se agrega con DEFAULT 'Normal' para no romper pedidos existentes,
-- y con un CHECK constraint que valida los mismos 3 valores que expone
-- la app en lib/core/providers/pedido_provider.dart (kNivelesDulzura).

-- 1. Añadir la columna si no existe.
ALTER TABLE public.pedidos
  ADD COLUMN IF NOT EXISTS dulzura TEXT NOT NULL DEFAULT 'Normal';

-- 2. (Re)crear el CHECK constraint con los valores válidos.
ALTER TABLE public.pedidos
  DROP CONSTRAINT IF EXISTS pedidos_dulzura_valida;

ALTER TABLE public.pedidos
  ADD CONSTRAINT pedidos_dulzura_valida
  CHECK (dulzura IN ('Bajo', 'Normal', 'Alto'));
