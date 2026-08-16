-- Record Terms/Privacy acceptance after OAuth create-account flows.
-- Email signup already stores these via handle_firstvue_auth_signup metadata.

create or replace function public.accept_legal_terms()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'Sign in to accept the Terms and Privacy Policy.';
  end if;

  insert into public.profiles (id, account_type, terms_accepted_at, privacy_accepted_at)
  values (v_uid, 'customer', now(), now())
  on conflict (id) do update
    set terms_accepted_at = coalesce(public.profiles.terms_accepted_at, now()),
        privacy_accepted_at = coalesce(public.profiles.privacy_accepted_at, now()),
        updated_at = now()
    where public.profiles.id = v_uid;
end;
$$;

revoke all on function public.accept_legal_terms() from public;
grant execute on function public.accept_legal_terms() to authenticated;
