-- Additive migration: classmates RPC and durable daily locked-link reports.
begin;

create table public.locked_link_reports (
  post_id uuid not null references public.posts(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  report_day date not null,
  created_at timestamptz not null default now(),
  primary key (post_id, reporter_id, report_day)
);
alter table public.locked_link_reports enable row level security;
revoke all on public.locked_link_reports from public, anon, authenticated;
grant all on public.locked_link_reports to service_role;

create function public.list_classmates(p_class uuid)
returns table (id uuid, display_name text, avatar_path text, google_photo_url text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  if not (public.is_class_owner(p_class) or public.is_class_member(p_class)) then
    raise exception 'Active membership or class ownership required' using errcode = '42501';
  end if;
  return query
    select p.id, p.display_name, p.avatar_path, p.google_photo_url
    from public.class_members m join public.profiles p on p.id = m.student_id
    where m.class_id = p_class and m.status = 'active' and p.deleted_at is null
    order by p.display_name, p.id;
end;
$$;

create function public.report_locked_link(p_post uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_class uuid;
  v_owner uuid;
  v_title text;
  v_name text;
begin
  if not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  if public.my_role() is distinct from 'student' then
    raise exception 'Only active students can report links' using errcode = '42501';
  end if;
  select p.class_id, c.owner_id, p.title into v_class, v_owner, v_title
    from public.posts p join public.classes c on c.id = p.class_id
    where p.id = p_post and p.deleted_at is null and c.deleted_at is null;
  if not found or not public.is_class_member(v_class) then
    raise exception 'Active membership and an available post required' using errcode = '42501';
  end if;
  select p.display_name into v_name from public.profiles p
    where p.id = auth.uid() and p.deleted_at is null;
  if not found then
    raise exception 'Active student profile required' using errcode = '42501';
  end if;
  if not exists (select 1 from public.post_attachments a
    where a.post_id = p_post and a.kind = 'link' and a.deleted_at is null) then
    raise exception 'Post has no available link' using errcode = '22023';
  end if;
  insert into public.locked_link_reports(post_id, reporter_id, report_day)
    values (p_post, auth.uid(), (statement_timestamp() at time zone 'UTC')::date)
    on conflict do nothing;
  if not found then
    raise exception 'Link already reported today' using errcode = '22023';
  end if;
  perform public.notify(v_owner, 'link_report', v_class, 'Locked link reported',
    v_name || ' reported a locked link on ' || v_title, 'post', p_post);
end;
$$;

revoke all on function public.list_classmates(uuid), public.report_locked_link(uuid)
  from public, anon, authenticated;
grant execute on function public.list_classmates(uuid), public.report_locked_link(uuid)
  to authenticated, service_role;
commit;
