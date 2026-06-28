-- SAUH - Persistência de pacientes, medicação e RLS clínica.
-- Executa no SQL Editor do Supabase depois de criares/atualizares public.app_users.

create table if not exists public.patients (
  id uuid primary key default gen_random_uuid(),
  nome text not null check (length(trim(nome)) > 0),
  idade integer not null check (idade >= 0),
  genero text not null default 'Não indicado',
  numero_processo text not null,
  motivo_entrada text not null default 'Avaliação clínica',
  estado_clinico text not null default 'Normal',
  prioridade text not null default 'Normal',
  hospital text not null,
  departamento text not null default 'Urgência',
  medico_responsavel_auth_user_id uuid not null references auth.users(id) on delete restrict,
  created_by_auth_user_id uuid not null references auth.users(id) on delete restrict,
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.medications (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null,
  name text not null check (length(trim(name)) > 0),
  dose text not null default 'Não indicada',
  time text not null default '00:00',
  responsible_professional text not null default 'Por atribuir',
  administered boolean not null default false,
  created_by_auth_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.medications
  add column if not exists patient_id uuid,
  add column if not exists name text,
  add column if not exists dose text not null default 'Não indicada',
  add column if not exists time text not null default '00:00',
  add column if not exists responsible_professional text not null default 'Por atribuir',
  add column if not exists administered boolean not null default false,
  add column if not exists created_by_auth_user_id uuid references auth.users(id) on delete set null,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

update public.medications
set name = 'Medicação'
where name is null;

alter table public.medications
  alter column patient_id set not null,
  alter column name set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'medications_patient_id_fkey'
      and conrelid = 'public.medications'::regclass
  ) then
    alter table public.medications
      add constraint medications_patient_id_fkey
      foreign key (patient_id)
      references public.patients(id)
      on delete cascade;
  end if;
end;
$$;

create index if not exists patients_hospital_idx
  on public.patients (hospital);

create index if not exists patients_medico_responsavel_idx
  on public.patients (medico_responsavel_auth_user_id);

create index if not exists patients_created_at_idx
  on public.patients (created_at desc);

create index if not exists medications_patient_id_idx
  on public.medications (patient_id);

create index if not exists medications_created_at_idx
  on public.medications (created_at desc);

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

create or replace function public.set_patients_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.set_medications_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_patients_updated_at on public.patients;
create trigger set_patients_updated_at
before update on public.patients
for each row execute function public.set_patients_updated_at();

drop trigger if exists set_medications_updated_at on public.medications;
create trigger set_medications_updated_at
before update on public.medications
for each row execute function public.set_medications_updated_at();

alter table public.patients enable row level security;
alter table public.medications enable row level security;

drop policy if exists "patients select by clinical role"
on public.patients;

drop policy if exists "patients insert by clinical role"
on public.patients;

drop policy if exists "patients insert by admin or triage"
on public.patients;

drop policy if exists "patients update by clinical role"
on public.patients;

drop policy if exists "patients delete by admin"
on public.patients;

create policy "patients select by clinical role"
on public.patients
for select
to authenticated
using (
  public.is_admin_user()
  or (
    public.current_app_user_cargo() = 'triagem'
    and hospital = public.current_app_user_hospital_id()
  )
  or (
    public.current_app_user_cargo() = 'medico'
    and medico_responsavel_auth_user_id = auth.uid()
  )
);

create policy "patients insert by clinical role"
on public.patients
for insert
to authenticated
with check (
  created_by_auth_user_id = auth.uid()
  and (
    public.is_admin_user()
    or (
      public.current_app_user_cargo() = 'triagem'
      and hospital = public.current_app_user_hospital_id()
    )
  )
);

create policy "patients update by clinical role"
on public.patients
for update
to authenticated
using (
  public.is_admin_user()
  or (
    public.current_app_user_cargo() = 'triagem'
    and hospital = public.current_app_user_hospital_id()
  )
  or (
    public.current_app_user_cargo() = 'medico'
    and medico_responsavel_auth_user_id = auth.uid()
  )
)
with check (
  public.is_admin_user()
  or (
    public.current_app_user_cargo() = 'triagem'
    and hospital = public.current_app_user_hospital_id()
    and ativo = true
  )
  or (
    public.current_app_user_cargo() = 'medico'
    and medico_responsavel_auth_user_id = auth.uid()
    and ativo = true
  )
);

create policy "patients delete by admin"
on public.patients
for delete
to authenticated
using (public.is_admin_user());

drop policy if exists "medications select by clinical role"
on public.medications;

drop policy if exists "medications insert by clinical role"
on public.medications;

drop policy if exists "medications update by clinical role"
on public.medications;

drop policy if exists "medications delete by admin"
on public.medications;

drop policy if exists "authenticated users can read medications"
on public.medications;

drop policy if exists "authenticated users can insert medications"
on public.medications;

drop policy if exists "authenticated users can update medications"
on public.medications;

create policy "medications select by clinical role"
on public.medications
for select
to authenticated
using (
  public.is_admin_user()
  or exists (
    select 1
    from public.patients p
    where p.id = medications.patient_id
      and (
        (
          public.current_app_user_cargo() = 'triagem'
          and p.hospital = public.current_app_user_hospital_id()
        )
        or (
          public.current_app_user_cargo() = 'medico'
          and p.medico_responsavel_auth_user_id = auth.uid()
        )
      )
  )
);

create policy "medications insert by clinical role"
on public.medications
for insert
to authenticated
with check (
  public.is_admin_user()
  or exists (
    select 1
    from public.patients p
    where p.id = medications.patient_id
      and (
        (
          public.current_app_user_cargo() = 'triagem'
          and p.hospital = public.current_app_user_hospital_id()
        )
        or (
          public.current_app_user_cargo() = 'medico'
          and p.medico_responsavel_auth_user_id = auth.uid()
        )
      )
  )
);

create policy "medications update by clinical role"
on public.medications
for update
to authenticated
using (
  public.is_admin_user()
  or exists (
    select 1
    from public.patients p
    where p.id = medications.patient_id
      and (
        (
          public.current_app_user_cargo() = 'triagem'
          and p.hospital = public.current_app_user_hospital_id()
        )
        or (
          public.current_app_user_cargo() = 'medico'
          and p.medico_responsavel_auth_user_id = auth.uid()
        )
      )
  )
)
with check (
  public.is_admin_user()
  or exists (
    select 1
    from public.patients p
    where p.id = medications.patient_id
      and (
        (
          public.current_app_user_cargo() = 'triagem'
          and p.hospital = public.current_app_user_hospital_id()
        )
        or (
          public.current_app_user_cargo() = 'medico'
          and p.medico_responsavel_auth_user_id = auth.uid()
        )
      )
  )
);

create policy "medications delete by admin"
on public.medications
for delete
to authenticated
using (public.is_admin_user());
