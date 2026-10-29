-- Provision the team's sign-in accounts.
--
-- This writes straight into auth.users rather than going through the
-- Admin API, because that is what you can do from the SQL Editor. It
-- works, but it is a back door into a Supabase-managed schema: if an
-- upgrade changes the shape of auth.users, this script is what breaks.
-- For anything beyond seeding a handful of accounts, prefer
-- `supabase.auth.admin.createUser()` with the service role key.
--
-- Usernames map to emails as <username>@example.com. That domain is
-- also hardcoded as EMAIL_DOMAIN in index.html — change both together.
--
-- Re-running is safe: existing accounts are skipped, not reset.

-- ============================================================
-- !! The initial password below is the literal string 'password'.
-- !! It is on a public repo and the site is on a public URL.
-- !! Change it, or have everyone change theirs, before this board
-- !! holds anything you would not post publicly.
-- ============================================================

do $$
declare
  u record;
  new_id uuid;
  initial_password constant text := 'password';
begin
  for u in
    select * from (values
      ('priya',  'Priya'),
      ('dan',    'Dan'),
      ('marcus', 'Marcus')
    ) as t(username, display_name)
  loop
    if exists (select 1 from auth.users where email = u.username || '@example.com') then
      raise notice 'skipping %, already exists', u.username;
      continue;
    end if;

    new_id := gen_random_uuid();

    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data,
      confirmation_token, recovery_token, email_change, email_change_token_new,
      created_at, updated_at
    ) values (
      '00000000-0000-0000-0000-000000000000', new_id, 'authenticated', 'authenticated',
      u.username || '@example.com',
      extensions.crypt(initial_password, extensions.gen_salt('bf')),
      now(),                                    -- pre-confirmed: no verification email
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('username', u.username, 'display_name', u.display_name),
      '', '', '', '',                           -- GoTrue expects empty strings, not nulls
      now(), now()
    );

    -- Without a matching identity row, password sign-in fails.
    insert into auth.identities (
      id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), new_id, new_id::text,
      jsonb_build_object(
        'sub', new_id::text,
        'email', u.username || '@example.com',
        'email_verified', true,
        'phone_verified', false
      ),
      'email', now(), now(), now()
    );
  end loop;
end
$$;

-- The on_auth_user_created trigger in schema.sql fills public.profiles.
select p.username, p.display_name, u.email, u.last_sign_in_at
from public.profiles p
join auth.users u on u.id = p.id
order by p.username;

-- Reset one person's password:
--   update auth.users
--      set encrypted_password = extensions.crypt('new-password', extensions.gen_salt('bf')),
--          updated_at = now()
--    where email = 'priya@example.com';
--
-- Remove an account (cascades to profiles, identities and sessions):
--   delete from auth.users where email = 'priya@example.com';
