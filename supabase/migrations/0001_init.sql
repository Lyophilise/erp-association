-- ERP Association — schéma initial (multi-association / multi-club)
-- Convention : toute table métier porte organization_id et est protégée par RLS
-- via la fonction is_member()/has_role() définies plus bas.
-- NB : ce fichier documente le schéma déjà appliqué en direct sur le projet
-- Supabase "erp-association" (hmeovaorwozazltidhbh) via apply_migration.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- Cœur multi-tenant : organisations (clubs/groupements) + rôles des membres
-- ---------------------------------------------------------------------------

create table organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique not null,
  created_at timestamptz not null default now()
);

create type membership_role as enum (
  'president', 'bureau', 'tresorier', 'secretaire', 'coach', 'benevole', 'membre'
);

create table memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role membership_role not null default 'membre',
  created_at timestamptz not null default now(),
  unique(organization_id, user_id)
);

create table invites (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  email text not null,
  role membership_role not null default 'membre',
  token uuid not null default gen_random_uuid(),
  invited_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  accepted_at timestamptz
);

create or replace function is_member(org_id uuid)
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from memberships
    where organization_id = org_id and user_id = auth.uid()
  );
$$;

create or replace function has_role(org_id uuid, roles membership_role[])
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from memberships
    where organization_id = org_id and user_id = auth.uid() and role = any(roles)
  );
$$;

-- ---------------------------------------------------------------------------
-- Équipes / catégories
-- ---------------------------------------------------------------------------

create table teams (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  name text not null,
  category text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Module 1 — Licences & effectifs
-- ---------------------------------------------------------------------------

create type licence_status as enum ('a_faire', 'en_attente', 'payee', 'expiree');

create table members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  team_id uuid references teams(id) on delete set null,
  first_name text not null,
  last_name text not null,
  birth_date date,
  licence_number text,
  licence_status licence_status not null default 'a_faire',
  licence_season text,
  parent_name text,
  parent_email text,
  parent_phone text,
  notes text,
  created_at timestamptz not null default now()
);

create table member_payments (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references members(id) on delete cascade,
  organization_id uuid not null references organizations(id) on delete cascade,
  amount numeric(10,2) not null,
  paid_at date not null default current_date,
  method text,
  note text
);

-- ---------------------------------------------------------------------------
-- Module 2 — Trésorerie
-- ---------------------------------------------------------------------------

create table finance_accounts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  name text not null,
  opening_balance numeric(10,2) not null default 0
);

create type transaction_type as enum ('recette', 'depense');

create table finance_transactions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  account_id uuid references finance_accounts(id) on delete set null,
  date date not null default current_date,
  label text not null,
  category text,
  type transaction_type not null,
  amount numeric(10,2) not null,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Module 3 — Encadrants & bénévoles
-- ---------------------------------------------------------------------------

create table team_staff (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references teams(id) on delete cascade,
  organization_id uuid not null references organizations(id) on delete cascade,
  user_id uuid references auth.users(id),
  display_name text,
  role text not null default 'coach'
);

create type volunteer_event_type as enum ('match', 'tournoi', 'ag', 'reunion', 'autre');

create table volunteer_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  title text not null,
  type volunteer_event_type not null default 'autre',
  event_date date not null,
  slots_needed int not null default 0,
  location text,
  notes text
);

create table volunteer_signups (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references volunteer_events(id) on delete cascade,
  organization_id uuid not null references organizations(id) on delete cascade,
  user_id uuid references auth.users(id),
  display_name text,
  role text,
  status text not null default 'inscrit'
);

-- ---------------------------------------------------------------------------
-- Module 4 — Calendrier, tournois & matériel
-- ---------------------------------------------------------------------------

create type calendar_event_type as enum ('match', 'tournoi', 'reunion', 'ag', 'autre');

create table calendar_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  team_id uuid references teams(id) on delete set null,
  title text not null,
  type calendar_event_type not null default 'match',
  start_at timestamptz not null,
  end_at timestamptz,
  location text,
  description text
);

create table equipment_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  name text not null,
  category text,
  quantity numeric(10,2) not null default 0,
  unit text default 'unite',
  location text
);

create table equipment_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  supplier text,
  items jsonb not null default '[]',
  total_cost numeric(10,2),
  status text not null default 'brouillon',
  order_date date not null default current_date
);

-- ---------------------------------------------------------------------------
-- Module 5 — Communication (convocations, relances)
-- ---------------------------------------------------------------------------

create type communication_type as enum ('convocation', 'relance', 'newsletter', 'autre');

create table communications (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  team_id uuid references teams(id) on delete set null,
  type communication_type not null default 'autre',
  subject text not null,
  body text,
  sent_at timestamptz,
  sent_by uuid references auth.users(id),
  recipients_count int default 0
);

-- ---------------------------------------------------------------------------
-- Module 6 — Partenaires / sponsoring (pubs)
-- ---------------------------------------------------------------------------

create table sponsors (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  name text not null,
  contact_name text,
  contact_email text,
  contact_phone text,
  contract_amount numeric(10,2),
  contract_start date,
  contract_end date,
  benefits_text text,
  logo_url text
);

-- ---------------------------------------------------------------------------
-- Module 7 — Boutique
-- ---------------------------------------------------------------------------

create table shop_products (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  name text not null,
  price numeric(10,2) not null,
  stock numeric(10,2) default 0,
  image_url text,
  active boolean not null default true
);

create table shop_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  buyer_name text,
  buyer_contact text,
  items jsonb not null default '[]',
  total numeric(10,2),
  status text not null default 'en_attente',
  order_date date not null default current_date
);

-- ---------------------------------------------------------------------------
-- Module 8 — Documents & gouvernance (PV de réunion, statuts...)
-- ---------------------------------------------------------------------------

create table documents (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  title text not null,
  type text not null default 'autre',
  file_url text,
  doc_date date,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table organizations enable row level security;
alter table memberships enable row level security;
alter table invites enable row level security;
alter table teams enable row level security;
alter table members enable row level security;
alter table member_payments enable row level security;
alter table finance_accounts enable row level security;
alter table finance_transactions enable row level security;
alter table team_staff enable row level security;
alter table volunteer_events enable row level security;
alter table volunteer_signups enable row level security;
alter table calendar_events enable row level security;
alter table equipment_items enable row level security;
alter table equipment_orders enable row level security;
alter table communications enable row level security;
alter table sponsors enable row level security;
alter table shop_products enable row level security;
alter table shop_orders enable row level security;
alter table documents enable row level security;

create policy org_select on organizations for select using (is_member(id));

create policy memberships_select on memberships for select using (is_member(organization_id));
create policy memberships_write on memberships for all using (has_role(organization_id, array['president','bureau']::membership_role[]));

create policy invites_all on invites for all using (has_role(organization_id, array['president','bureau']::membership_role[]));

create policy teams_select on teams for select using (is_member(organization_id));
create policy teams_write on teams for all using (has_role(organization_id, array['president','bureau']::membership_role[]));

create policy members_select on members for select using (is_member(organization_id));
create policy members_write on members for all using (has_role(organization_id, array['president','bureau','secretaire','coach']::membership_role[]));

create policy member_payments_select on member_payments for select using (is_member(organization_id));
create policy member_payments_write on member_payments for all using (has_role(organization_id, array['president','bureau','tresorier']::membership_role[]));

create policy finance_accounts_select on finance_accounts for select using (is_member(organization_id));
create policy finance_accounts_write on finance_accounts for all using (has_role(organization_id, array['president','tresorier']::membership_role[]));

create policy finance_tx_select on finance_transactions for select using (is_member(organization_id));
create policy finance_tx_write on finance_transactions for all using (has_role(organization_id, array['president','tresorier']::membership_role[]));

create policy team_staff_select on team_staff for select using (is_member(organization_id));
create policy team_staff_write on team_staff for all using (has_role(organization_id, array['president','bureau']::membership_role[]));

create policy volunteer_events_select on volunteer_events for select using (is_member(organization_id));
create policy volunteer_events_write on volunteer_events for all using (has_role(organization_id, array['president','bureau']::membership_role[]));

create policy volunteer_signups_select on volunteer_signups for select using (is_member(organization_id));
create policy volunteer_signups_write on volunteer_signups for all using (is_member(organization_id));

create policy calendar_events_select on calendar_events for select using (is_member(organization_id));
create policy calendar_events_write on calendar_events for all using (has_role(organization_id, array['president','bureau','coach']::membership_role[]));

create policy equipment_items_select on equipment_items for select using (is_member(organization_id));
create policy equipment_items_write on equipment_items for all using (has_role(organization_id, array['president','bureau']::membership_role[]));

create policy equipment_orders_select on equipment_orders for select using (is_member(organization_id));
create policy equipment_orders_write on equipment_orders for all using (has_role(organization_id, array['president','bureau','tresorier']::membership_role[]));

create policy communications_select on communications for select using (is_member(organization_id));
create policy communications_write on communications for all using (has_role(organization_id, array['president','bureau','secretaire','coach']::membership_role[]));

create policy sponsors_select on sponsors for select using (is_member(organization_id));
create policy sponsors_write on sponsors for all using (has_role(organization_id, array['president','bureau']::membership_role[]));

create policy shop_products_select on shop_products for select using (is_member(organization_id));
create policy shop_products_write on shop_products for all using (has_role(organization_id, array['president','bureau','tresorier']::membership_role[]));

create policy shop_orders_select on shop_orders for select using (is_member(organization_id));
create policy shop_orders_write on shop_orders for all using (has_role(organization_id, array['president','bureau','tresorier']::membership_role[]));

create policy documents_select on documents for select using (is_member(organization_id));
create policy documents_write on documents for all using (has_role(organization_id, array['president','bureau','secretaire']::membership_role[]));
