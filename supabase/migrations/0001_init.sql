-- RoomCraft: saved projects and live share sessions.

create table public.projects (
  id uuid primary key,
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 40),
  scene jsonb not null,
  updated_at timestamptz not null default now(),   -- set by the client
  created_at timestamptz not null default now()
);
create index projects_owner_idx on public.projects (owner_id, updated_at desc);

create table public.share_sessions (
  code text primary key check (code ~ '^[A-HJ-NP-Z2-9]{6}$'),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  project_id uuid references public.projects(id) on delete set null,
  scene jsonb not null,
  revision bigint not null default 0,
  active boolean not null default true,
  expires_at timestamptz not null default now() + interval '24 hours',
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.projects enable row level security;
alter table public.share_sessions enable row level security;

create policy projects_owner_all on public.projects
  for all to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy share_owner_all on public.share_sessions
  for all to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy share_viewer_read on public.share_sessions
  for select to authenticated
  using (active and expires_at > now());

alter publication supabase_realtime add table public.share_sessions;
