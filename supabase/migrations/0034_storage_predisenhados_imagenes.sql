-- Migration 0034: Storage bucket para fotos de prediseñados.
--
-- Mismo patrón que la migración 0030 (bucket "sabores"), pero para las
-- fotos de los yogures prediseñados que el admin puede crear ahora desde
-- el panel de administración.

INSERT INTO storage.buckets (id, name, public)
VALUES ('predisenhados', 'predisenhados', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "predisenhados_imagenes_select_public" ON storage.objects;
DROP POLICY IF EXISTS "predisenhados_imagenes_insert_admin" ON storage.objects;
DROP POLICY IF EXISTS "predisenhados_imagenes_update_admin" ON storage.objects;
DROP POLICY IF EXISTS "predisenhados_imagenes_delete_admin" ON storage.objects;

CREATE POLICY "predisenhados_imagenes_select_public"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'predisenhados');

CREATE POLICY "predisenhados_imagenes_insert_admin"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'predisenhados'
    AND EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador')
  );

CREATE POLICY "predisenhados_imagenes_update_admin"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'predisenhados'
    AND EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador')
  );

CREATE POLICY "predisenhados_imagenes_delete_admin"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'predisenhados'
    AND EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador')
  );
