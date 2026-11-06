-- EXXPRESS: минимум 90 RUB для опубликованного объявления.
-- Выполни один раз в Supabase -> SQL Editor -> New query -> Run.
-- Объявления дешевле 90 ₽ будут сняты с публикации, но не удалены.
-- Продавец сможет открыть их в профиле, изменить цену и опубликовать снова.

begin;

update public.listings
set is_active = false
where price < 90 and is_active = true;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.listings'::regclass
      and conname = 'listings_minimum_active_price_90'
  ) then
    alter table public.listings
      add constraint listings_minimum_active_price_90
      check (price >= 90 or is_active = false);
  end if;
end
$$;

commit;
