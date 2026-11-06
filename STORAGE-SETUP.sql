-- EXXPRESS: настройки Supabase Storage для аватаров и фотографий объявлений.
-- Выполнить один раз в Supabase → SQL Editor → New query → Run.
-- Загрузка доступна авторизованным пользователям только в собственную папку.
-- Чтение изображений публичное, чтобы их могли видеть карточки каталога.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 5242880, array['image/jpeg','image/png','image/webp']),
  ('listing-images', 'listing-images', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "EXXPRESS public image read" on storage.objects;
create policy "EXXPRESS public image read"
on storage.objects for select
to anon, authenticated
using (bucket_id in ('avatars', 'listing-images'));

drop policy if exists "EXXPRESS users upload own images" on storage.objects;
create policy "EXXPRESS users upload own images"
on storage.objects for insert
to authenticated
with check (
  bucket_id in ('avatars', 'listing-images')
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "EXXPRESS users update own images" on storage.objects;
create policy "EXXPRESS users update own images"
on storage.objects for update
to authenticated
using (
  bucket_id in ('avatars', 'listing-images')
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id in ('avatars', 'listing-images')
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "EXXPRESS users delete own images" on storage.objects;
create policy "EXXPRESS users delete own images"
on storage.objects for delete
to authenticated
using (
  bucket_id in ('avatars', 'listing-images')
  and (storage.foldername(name))[1] = auth.uid()::text
);
