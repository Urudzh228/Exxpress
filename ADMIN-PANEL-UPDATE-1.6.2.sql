-- EXXPRESS 1.6.2 — автоматическое снятие объявлений с публикации при блокировке аккаунта.
-- Запусти весь файл в Supabase → SQL Editor → New query → Run.
-- Объявления не удаляются. При разблокировке они остаются скрытыми до повторного одобрения.

create or replace function public.exxpress_admin_set_listing_active(p_listing_id bigint, p_is_active boolean)
returns void
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_title text;
  v_seller_id uuid;
begin
  if not public.exxpress_is_admin() then raise exception 'Недостаточно прав администратора.'; end if;
  select title, seller_id into v_title, v_seller_id
    from public.listings where id = p_listing_id;
  if not found then raise exception 'Объявление не найдено.'; end if;
  if p_is_active and public.exxpress_is_banned(v_seller_id) then
    raise exception 'Нельзя опубликовать объявление заблокированного пользователя. Сначала разблокируйте аккаунт.';
  end if;
  update public.listings
    set is_active = p_is_active,
        moderation_status = case when p_is_active then 'approved' else 'hidden' end
    where id = p_listing_id;
  insert into public.exxpress_admin_audit(actor_user_id, action, target_type, target_id, details)
  values (auth.uid(), case when p_is_active then 'listing_approved' else 'listing_hidden' end,
    'listing', p_listing_id::text, jsonb_build_object('title', v_title, 'is_active', p_is_active));
end;
$$;

create or replace function public.exxpress_admin_set_user_ban(p_user_id uuid, p_is_banned boolean, p_reason text default null)
returns void
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_email text;
  v_hidden_listings integer := 0;
begin
  if not public.exxpress_is_admin() then raise exception 'Недостаточно прав администратора.'; end if;
  if p_user_id is null then raise exception 'Не выбран аккаунт.'; end if;
  if p_user_id = auth.uid() then raise exception 'Нельзя заблокировать собственный аккаунт.'; end if;
  if exists (select 1 from public.exxpress_user_roles r where r.user_id = p_user_id and r.role = 'superadmin') then
    raise exception 'Нельзя изменить статус SUPERADMIN.';
  end if;
  select u.email::text into v_email from auth.users u where u.id = p_user_id;
  if not found then raise exception 'Аккаунт не найден.'; end if;

  insert into public.exxpress_account_status(user_id, is_banned, ban_reason, banned_at, banned_by, updated_at)
  values (p_user_id, p_is_banned,
    case when p_is_banned then left(nullif(trim(coalesce(p_reason, '')), ''), 500) else null end,
    case when p_is_banned then now() else null end,
    case when p_is_banned then auth.uid() else null end,
    now())
  on conflict (user_id) do update set
    is_banned = excluded.is_banned,
    ban_reason = excluded.ban_reason,
    banned_at = excluded.banned_at,
    banned_by = excluded.banned_by,
    updated_at = now();

  if p_is_banned then
    update public.listings
       set is_active = false,
           moderation_status = 'hidden'
     where seller_id = p_user_id
       and (is_active is distinct from false or moderation_status is distinct from 'hidden');
    get diagnostics v_hidden_listings = row_count;
  end if;

  insert into public.exxpress_admin_audit(actor_user_id, action, target_type, target_id, details)
  values (auth.uid(), case when p_is_banned then 'account_banned' else 'account_unbanned' end,
    'user', p_user_id::text,
    jsonb_build_object(
      'email', v_email,
      'reason', case when p_is_banned then left(coalesce(p_reason, ''), 500) else null end,
      'listings_hidden', v_hidden_listings
    ));
end;
$$;

revoke all on function public.exxpress_admin_set_listing_active(bigint, boolean) from public;
revoke all on function public.exxpress_admin_set_user_ban(uuid, boolean, text) from public;
grant execute on function public.exxpress_admin_set_listing_active(bigint, boolean) to authenticated;
grant execute on function public.exxpress_admin_set_user_ban(uuid, boolean, text) to authenticated;
