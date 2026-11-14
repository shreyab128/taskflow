-- Adds the fields required by TaskFlow's Categories and Projects screens.
-- Existing category/project records receive safe defaults.

alter table public.categories
  add column if not exists color text not null default '#6750A4';

alter table public.projects
  add column if not exists deadline date,
  add column if not exists status text not null default 'not_started',
  add column if not exists archived_at timestamptz;

alter table public.projects
  drop constraint if exists projects_status_check;

alter table public.projects
  add constraint projects_status_check
  check (status in ('not_started', 'active', 'on_hold', 'completed'));

-- The existing schema already provides nullable tasks.category_id and
-- tasks.project_id references. The app clears those links before deletion so
-- the task records remain intact.
