-- SAUH - Políticas RLS sugeridas para Supabase.
-- Executar no SQL Editor do Supabase depois de confirmar os nomes das tabelas.
-- Estas políticas exigem utilizador autenticado para ler e alterar dados clínicos.

alter table public.patients enable row level security;
alter table public.medications enable row level security;
alter table public.clinical_history enable row level security;

create policy "authenticated users can read patients"
on public.patients
for select
to authenticated
using (true);

create policy "authenticated users can insert patients"
on public.patients
for insert
to authenticated
with check (true);

create policy "authenticated users can update patients"
on public.patients
for update
to authenticated
using (true)
with check (true);

create policy "authenticated users can read medications"
on public.medications
for select
to authenticated
using (true);

create policy "authenticated users can insert medications"
on public.medications
for insert
to authenticated
with check (true);

create policy "authenticated users can update medications"
on public.medications
for update
to authenticated
using (true)
with check (true);

create policy "authenticated users can read clinical history"
on public.clinical_history
for select
to authenticated
using (true);

create policy "authenticated users can insert clinical history"
on public.clinical_history
for insert
to authenticated
with check (true);
