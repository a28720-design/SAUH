-- SAUH - Contas persistentes com Supabase Auth + perfis profissionais.
-- Executa este ficheiro no SQL Editor do projeto Supabase.

create table if not exists public.app_users (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  nome text not null check (length(trim(nome)) > 0),
  email text not null unique,
  cargo text not null check (
    cargo in (
      'super_admin',
      'admin',
      'medico',
      'enfermeiro',
      'tecnico',
      'rececionista',
      'triagem'
    )
  ),
  hospital text,
  ativo boolean not null default true,
  departamento text not null default 'Não definido',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists app_users_hospital_idx
  on public.app_users (hospital);

create index if not exists app_users_cargo_idx
  on public.app_users (cargo);

create or replace function public.set_app_users_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  new.email = lower(trim(new.email));
  new.departamento = coalesce(nullif(trim(new.departamento), ''), 'Não definido');
  return new;
end;
$$;

drop trigger if exists set_app_users_updated_at on public.app_users;
create trigger set_app_users_updated_at
before insert or update on public.app_users
for each row execute function public.set_app_users_updated_at();

create or replace function public.current_app_user_cargo()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select cargo
  from public.app_users
  where auth_user_id = auth.uid()
  limit 1;
$$;

create or replace function public.current_app_user_hospital_id()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select hospital
  from public.app_users
  where auth_user_id = auth.uid()
  limit 1;
$$;

create or replace function public.is_admin_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.app_users
    where auth_user_id = auth.uid()
      and ativo = true
      and cargo in ('super_admin', 'admin', 'admin_hospital')
  );
$$;

alter table public.app_users enable row level security;

drop policy if exists "app users can read own and managed accounts"
on public.app_users;

create policy "app users can read own and managed accounts"
on public.app_users
for select
to authenticated
using (
  auth.uid() = auth_user_id
  or public.current_app_user_cargo() = 'super_admin'
  or (
    public.current_app_user_cargo() in ('admin', 'admin_hospital', 'triagem')
    and hospital = public.current_app_user_hospital_id()
  )
);

-- Não cries políticas de insert/update/delete para o cliente Flutter.
-- A criação e edição de contas é feita pela Edge Function manage-account,
-- usando a service role key guardada apenas no Supabase.

-- Bootstrap do primeiro administrador:
-- 1. No Supabase Dashboard, cria um utilizador em Authentication > Users.
-- 2. Copia o UUID desse utilizador.
-- 3. Substitui o UUID abaixo e executa o insert.
--
-- insert into public.app_users (
--   auth_user_id,
--   nome,
--   email,
--   cargo,
--   hospital,
--   departamento,
--   ativo
-- ) values (
--   '00000000-0000-0000-0000-000000000000',
--   'Administrador SAUH',
--   'super@sauh.pt',
--   'super_admin',
--   null,
--   'Sistema',
--   true
-- )
-- on conflict (auth_user_id) do update set
--   nome = excluded.nome,
--   email = excluded.email,
--   cargo = excluded.cargo,
--   hospital = excluded.hospital,
--   departamento = excluded.departamento,
--   ativo = excluded.ativo;
