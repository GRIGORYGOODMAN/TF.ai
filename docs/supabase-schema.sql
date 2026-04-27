create table if not exists public.characters (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users(id) on delete set null,
  name text not null,
  description text default '',
  tags text[] default '{}',
  avatar_url text default '',
  background_url text default '',
  author_name text default '',
  system_prompt text default '',
  scenario text default '',
  first_message text default '',
  example_dialogue text default '',
  downloads integer not null default 0,
  likes integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.characters
add column if not exists owner_id uuid references auth.users(id) on delete set null;

alter table public.characters
add column if not exists updated_at timestamptz not null default now();

create index if not exists characters_owner_id_idx
on public.characters(owner_id);

alter table public.characters enable row level security;

drop policy if exists "Anyone can read characters" on public.characters;
create policy "Anyone can read characters"
on public.characters
for select
using (true);

drop policy if exists "Anyone can create characters" on public.characters;
drop policy if exists "Authenticated users can create characters" on public.characters;
create policy "Authenticated users can create characters"
on public.characters
for insert
to authenticated
with check (owner_id = auth.uid());

drop policy if exists "Owners can update characters" on public.characters;
create policy "Owners can update characters"
on public.characters
for update
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

drop policy if exists "Owners can delete characters" on public.characters;
create policy "Owners can delete characters"
on public.characters
for delete
to authenticated
using (owner_id = auth.uid());

insert into storage.buckets (id, name, public)
values ('character-assets', 'character-assets', true)
on conflict (id) do update set public = true;

drop policy if exists "Anyone can read character assets" on storage.objects;
create policy "Anyone can read character assets"
on storage.objects
for select
using (bucket_id = 'character-assets');

drop policy if exists "Anyone can upload character assets" on storage.objects;
drop policy if exists "Authenticated users can upload character assets" on storage.objects;
create policy "Authenticated users can upload character assets"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'character-assets');
