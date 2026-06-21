create table if not exists public.vitals (
  id bigint generated always as identity primary key,
  patient_name text not null,
  heart_rate integer not null,
  oxygen integer not null,
  temperature numeric(4, 1) not null,
  systolic_pressure integer not null,
  diastolic_pressure integer not null,
  respiratory_rate integer not null,
  patient_status text not null,
  alert_level text not null,
  measured_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists vitals_patient_measured_at_idx
  on public.vitals (patient_name, measured_at desc);

create table if not exists public.vitals_current (
  patient_name text primary key,
  heart_rate integer not null,
  oxygen integer not null,
  temperature numeric(4, 1) not null,
  systolic_pressure integer not null,
  diastolic_pressure integer not null,
  respiratory_rate integer not null,
  patient_status text not null,
  alert_level text not null,
  measured_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.alerts (
  id bigint generated always as identity primary key,
  patient_name text not null,
  alert_type text not null,
  message text not null,
  level text not null,
  created_at timestamptz not null default now()
);

create index if not exists alerts_patient_created_at_idx
  on public.alerts (patient_name, created_at desc);
