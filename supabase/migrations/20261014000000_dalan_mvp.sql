-- DALAN MVP schema. Apply with Supabase CLI after reviewing the RLS policies.
-- Private content is never placed in public storage or public profile fields.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = public as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Learner' check (char_length(display_name) between 1 and 40),
  grade_level smallint not null default 7 check (grade_level between 1 and 12),
  grade_band text generated always as (
    case when grade_level <= 5 then '1-5' when grade_level <= 8 then '6-8' else '9-12' end
  ) stored,
  interests text[] not null default '{}',
  career_interests text[] not null default '{}',
  opted_in_skills text[] not null default '{}',
  introduction text not null default '' check (char_length(introduction) <= 180),
  networking_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index profiles_networking_idx on public.profiles (networking_enabled, grade_band) where networking_enabled;
create trigger profiles_updated_at before update on public.profiles for each row execute function public.set_updated_at();

create or replace function public.create_profile_for_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(nullif(left(new.raw_user_meta_data ->> 'display_name', 40), ''), 'Learner'))
  on conflict (id) do nothing;
  return new;
end;
$$;
create trigger on_auth_user_created after insert on auth.users
for each row execute function public.create_profile_for_new_user();

create table public.user_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  theme text not null default 'system' check (theme in ('light','dark','system')),
  journal_ai_enabled boolean not null default false,
  profile_discovery_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger user_preferences_updated_at before update on public.user_preferences for each row execute function public.set_updated_at();

create table public.consent_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  purpose text not null check (purpose in ('journal_ai_analysis','profile_discovery','audio_recording','adult_supervision')),
  policy_version text not null,
  granted boolean not null,
  recorded_at timestamptz not null default now(),
  revoked_at timestamptz,
  metadata jsonb not null default '{}'
);
create index consent_records_user_time_idx on public.consent_records (user_id, recorded_at desc);

create or replace function public.protect_consent_record()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.purpose <> 'adult_supervision' then
    if auth.uid() is not null and new.user_id <> auth.uid() then raise exception 'Consent owner mismatch'; end if;
    new.recorded_at := now();
    new.revoked_at := null;
  end if;
  return new;
end;
$$;
create trigger consent_records_server_timestamp before insert on public.consent_records
for each row execute function public.protect_consent_record();

create table public.assessments (
  id uuid primary key default gen_random_uuid(),
  slug text not null,
  version text not null,
  title text not null,
  description text not null,
  scoring_rules jsonb not null default '{}',
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  unique (slug, version)
);
create table public.assessment_questions (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references public.assessments(id) on delete cascade,
  question_order smallint not null check (question_order > 0),
  prompt text not null check (char_length(prompt) <= 500),
  dimension text not null,
  unique (assessment_id, question_order),
  unique (id, assessment_id)
);
create table public.assessment_options (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.assessment_questions(id) on delete cascade,
  option_order smallint not null check (option_order between 1 and 5),
  score smallint not null check (score between 1 and 5),
  label text not null,
  unique (question_id, option_order),
  unique (id, question_id)
);
create table public.assessment_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  assessment_id uuid not null references public.assessments(id),
  version text not null,
  status text not null default 'in_progress' check (status in ('in_progress','completed','abandoned')),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (id, assessment_id),
  check ((status = 'completed') = (completed_at is not null))
);
create index assessment_attempts_user_date_idx on public.assessment_attempts (user_id, started_at desc);
create table public.assessment_answers (
  attempt_id uuid not null,
  assessment_id uuid not null,
  question_id uuid not null,
  selected_option_id uuid not null,
  answer_value smallint not null check (answer_value between 1 and 5),
  answered_at timestamptz not null default now(),
  primary key (attempt_id, question_id),
  foreign key (attempt_id, assessment_id) references public.assessment_attempts(id, assessment_id) on delete cascade,
  foreign key (question_id, assessment_id) references public.assessment_questions(id, assessment_id),
  foreign key (selected_option_id, question_id) references public.assessment_options(id, question_id)
);
create table public.assessment_results (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null unique references public.assessment_attempts(id) on delete cascade,
  scores jsonb not null,
  explanation text not null,
  created_at timestamptz not null default now()
);

create or replace function public.guard_assessment_attempt()
returns trigger language plpgsql set search_path = public as $$
declare
  expected_version text;
  question_count integer;
  answer_count integer;
begin
  select a.version into expected_version from public.assessments a
    where a.id = new.assessment_id and a.is_active;
  if expected_version is null or new.version <> expected_version then
    raise exception 'Assessment is inactive or the requested version is invalid';
  end if;
  if tg_op = 'INSERT' then
    if new.status <> 'in_progress' then raise exception 'An assessment attempt must start in progress'; end if;
    new.started_at := now();
  else
    if new.id <> old.id or new.user_id <> old.user_id or new.assessment_id <> old.assessment_id
       or new.version <> old.version or new.started_at <> old.started_at then
      raise exception 'Assessment attempt identity and version are immutable';
    end if;
    if old.status <> 'in_progress' and new.status <> old.status then
      raise exception 'A completed or abandoned attempt cannot be reopened';
    end if;
  end if;
  if new.status = 'completed' then
    select count(*) into question_count from public.assessment_questions q where q.assessment_id = new.assessment_id;
    select count(*) into answer_count from public.assessment_answers a where a.attempt_id = new.id;
    if question_count = 0 or answer_count <> question_count then
      raise exception 'Answer every assessment question before completing';
    end if;
    new.completed_at := now();
  else
    new.completed_at := null;
  end if;
  return new;
end;
$$;
create trigger assessment_attempt_guard before insert or update on public.assessment_attempts
for each row execute function public.guard_assessment_attempt();

create or replace function public.guard_assessment_answer()
returns trigger language plpgsql set search_path = public as $$
declare
  expected_score smallint;
  attempt_status text;
begin
  if tg_op = 'UPDATE' and (new.attempt_id <> old.attempt_id or new.assessment_id <> old.assessment_id or new.question_id <> old.question_id) then
    raise exception 'Assessment answer identity is immutable';
  end if;
  select o.score into expected_score from public.assessment_options o
    where o.id = new.selected_option_id and o.question_id = new.question_id;
  if expected_score is null or new.answer_value <> expected_score then
    raise exception 'Answer value must match the selected assessment option';
  end if;
  select a.status into attempt_status from public.assessment_attempts a where a.id = new.attempt_id;
  if attempt_status <> 'in_progress' then raise exception 'Answers can only change during an in-progress attempt'; end if;
  new.answered_at := now();
  return new;
end;
$$;
create trigger assessment_answer_guard before insert or update on public.assessment_answers
for each row execute function public.guard_assessment_answer();

create table public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 20000),
  entry_type text not null default 'text' check (entry_type in ('text','voice_transcript')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index journal_entries_user_date_idx on public.journal_entries (user_id, updated_at desc) where deleted_at is null;
create or replace function public.guard_journal_timestamps()
returns trigger language plpgsql set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    new.created_at := now();
    new.updated_at := now();
  else
    if new.id <> old.id or new.user_id <> old.user_id or new.created_at <> old.created_at then
      raise exception 'Journal entry owner and creation time are immutable';
    end if;
    new.updated_at := now();
  end if;
  return new;
end;
$$;
create trigger journal_entries_timestamp_guard before insert or update on public.journal_entries
for each row execute function public.guard_journal_timestamps();
create table public.journal_audio_assets (
  id uuid primary key default gen_random_uuid(),
  journal_entry_id uuid not null unique references public.journal_entries(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  storage_path text not null unique,
  duration_seconds integer not null check (duration_seconds between 1 and 3600),
  created_at timestamptz not null default now(),
  check (storage_path like user_id::text || '/%')
);
create table public.journal_insights (
  id uuid primary key default gen_random_uuid(),
  journal_entry_id uuid not null references public.journal_entries(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  candidate_themes jsonb not null default '[]',
  student_confirmed boolean,
  status text not null default 'pending' check (status in ('pending','ready','dismissed','failed')),
  provider text,
  model_version text,
  analysis_version text not null,
  consent_record_id uuid references public.consent_records(id) on delete set null,
  created_at timestamptz not null default now(),
  check (status <> 'ready' or consent_record_id is not null)
);
create index journal_insights_owner_idx on public.journal_insights (user_id, created_at desc);

create or replace function public.current_consent_is_granted(subject_user uuid, subject_purpose text)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((
    select c.granted and c.revoked_at is null
    from public.consent_records c
    where c.user_id = subject_user and c.purpose = subject_purpose
    order by c.recorded_at desc limit 1
  ), false);
$$;
revoke all on function public.current_consent_is_granted(uuid, text) from public;

create or replace function public.enforce_preference_consents()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.profile_discovery_enabled and (
    not public.current_consent_is_granted(new.user_id, 'profile_discovery')
    or not public.current_consent_is_granted(new.user_id, 'adult_supervision')
    or not exists (select 1 from public.profiles p where p.id = new.user_id and p.networking_enabled)
  ) then raise exception 'Profile discovery requires current consent, supervision, and an opted-in profile'; end if;
  if new.journal_ai_enabled and not public.current_consent_is_granted(new.user_id, 'journal_ai_analysis') then
    raise exception 'Journal AI processing requires current consent';
  end if;
  return new;
end;
$$;
create trigger preferences_require_consents before insert or update on public.user_preferences
for each row execute function public.enforce_preference_consents();

create or replace function public.enforce_networking_consent()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.networking_enabled and (
    not public.current_consent_is_granted(new.id, 'profile_discovery')
    or not public.current_consent_is_granted(new.id, 'adult_supervision')
  ) then
    raise exception 'Profile discovery requires current consent and a server-verified supervision record';
  end if;
  return new;
end;
$$;
create trigger profiles_require_networking_consent before insert or update on public.profiles
for each row execute function public.enforce_networking_consent();

create or replace function public.disable_features_after_consent_revocation()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (not new.granted or new.revoked_at is not null) and new.purpose in ('profile_discovery','adult_supervision') then
    update public.profiles set networking_enabled = false where id = new.user_id;
    update public.user_preferences set profile_discovery_enabled = false where user_id = new.user_id;
  end if;
  if (not new.granted or new.revoked_at is not null) and new.purpose = 'journal_ai_analysis' then
    update public.user_preferences set journal_ai_enabled = false where user_id = new.user_id;
  end if;
  return new;
end;
$$;
create trigger consent_revocation_disables_features after insert or update on public.consent_records
for each row execute function public.disable_features_after_consent_revocation();

create table public.skills (
  id text primary key,
  name text not null,
  description text not null default '',
  created_at timestamptz not null default now()
);
create table public.interests (
  id text primary key,
  name text not null,
  created_at timestamptz not null default now()
);
create table public.careers (
  id text primary key,
  title text not null,
  summary text not null,
  responsibilities jsonb not null default '[]',
  education_pathway text not null,
  beginner_activity text not null,
  related_career_ids text[] not null default '{}',
  source_references jsonb not null default '[]',
  content_kind text not null default 'illustrative_seed' check (content_kind in ('illustrative_seed','verified')),
  last_reviewed_at date,
  is_published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index careers_published_title_idx on public.careers (title) where is_published;
create trigger careers_updated_at before update on public.careers for each row execute function public.set_updated_at();
create table public.career_skills (
  career_id text not null references public.careers(id) on delete cascade,
  skill_id text not null references public.skills(id) on delete cascade,
  relevance smallint not null default 1 check (relevance between 1 and 5),
  primary key (career_id, skill_id)
);
create table public.career_interests (
  career_id text not null references public.careers(id) on delete cascade,
  interest_id text not null references public.interests(id) on delete cascade,
  primary key (career_id, interest_id)
);
create table public.career_recommendations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  career_id text not null references public.careers(id),
  match_score numeric(5,2) not null check (match_score between 0 and 100),
  matched_interests text[] not null default '{}',
  relevant_skills text[] not null default '{}',
  skill_gaps text[] not null default '{}',
  explanation text not null,
  algorithm_version text not null,
  created_at timestamptz not null default now()
);
create index career_recommendations_user_idx on public.career_recommendations (user_id, created_at desc);
create table public.saved_careers (
  user_id uuid not null references auth.users(id) on delete cascade,
  career_id text not null references public.careers(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, career_id)
);

create table public.career_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  career_id text not null references public.careers(id),
  status text not null default 'active' check (status in ('active','paused','completed','changed')),
  started_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index one_active_goal_per_student on public.career_goals(user_id) where status = 'active';
create index career_goals_user_idx on public.career_goals(user_id, updated_at desc);
create trigger career_goals_updated_at before update on public.career_goals for each row execute function public.set_updated_at();
create table public.roadmaps (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  career_goal_id uuid not null unique references public.career_goals(id) on delete cascade,
  grade_level smallint not null check (grade_level between 1 and 12),
  template_version text not null,
  status text not null default 'active' check (status in ('active','paused','completed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index roadmaps_user_idx on public.roadmaps(user_id, updated_at desc);
create trigger roadmaps_updated_at before update on public.roadmaps for each row execute function public.set_updated_at();
create table public.roadmap_stages (
  id uuid primary key default gen_random_uuid(),
  roadmap_id uuid not null references public.roadmaps(id) on delete cascade,
  title text not null,
  description text not null default '',
  stage_order smallint not null check (stage_order > 0),
  unique (roadmap_id, stage_order)
);
create table public.learning_resources (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  url text,
  source_name text,
  age_min smallint not null default 1 check (age_min between 1 and 12),
  age_max smallint not null default 12 check (age_max between age_min and 12),
  is_reviewed boolean not null default false,
  is_published boolean not null default false,
  created_at timestamptz not null default now()
);
create table public.tasks (
  id text primary key,
  title text not null,
  description text not null,
  learning_objective text not null,
  career_relevance text not null,
  grade_min smallint not null check (grade_min between 1 and 12),
  grade_max smallint not null check (grade_max between grade_min and 12),
  difficulty text not null check (difficulty in ('beginner','developing','beginner_plus','intermediate')),
  estimated_minutes smallint not null check (estimated_minutes between 1 and 240),
  instructions jsonb not null default '[]',
  completion_criteria text not null,
  rubric jsonb,
  is_published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index tasks_grade_idx on public.tasks (grade_min, grade_max) where is_published;
create trigger tasks_updated_at before update on public.tasks for each row execute function public.set_updated_at();
create table public.task_skills (
  task_id text not null references public.tasks(id) on delete cascade,
  skill_id text not null references public.skills(id) on delete cascade,
  primary key (task_id, skill_id)
);
create table public.task_resources (
  task_id text not null references public.tasks(id) on delete cascade,
  resource_id uuid not null references public.learning_resources(id) on delete cascade,
  primary key (task_id, resource_id)
);
create table public.roadmap_stage_tasks (
  id uuid primary key default gen_random_uuid(),
  stage_id uuid not null references public.roadmap_stages(id) on delete cascade,
  task_id text not null references public.tasks(id),
  task_order smallint not null check (task_order > 0),
  unique (stage_id, task_order),
  unique (stage_id, task_id)
);
create table public.task_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  roadmap_stage_task_id uuid not null references public.roadmap_stage_tasks(id) on delete cascade,
  status text not null default 'not_started' check (status in ('not_started','in_progress','completed')),
  started_at timestamptz,
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (user_id, roadmap_stage_task_id),
  check ((status = 'completed') = (completed_at is not null))
);
create index task_progress_user_status_idx on public.task_progress(user_id, status, updated_at desc);
create or replace function public.guard_task_progress()
returns trigger language plpgsql set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    if new.status = 'not_started' then
      new.started_at := null;
    else
      new.started_at := now();
    end if;
    new.completed_at := case when new.status = 'completed' then now() else null end;
  else
    if new.id <> old.id or new.user_id <> old.user_id or new.roadmap_stage_task_id <> old.roadmap_stage_task_id then
      raise exception 'Task progress ownership and task identity are immutable';
    end if;
    new.started_at := coalesce(old.started_at, case when new.status = 'not_started' then null else now() end);
    new.completed_at := case
      when new.status = 'completed' then coalesce(old.completed_at, now())
      else null
    end;
  end if;
  new.updated_at := now();
  return new;
end;
$$;
create trigger task_progress_timestamp_guard before insert or update on public.task_progress
for each row execute function public.guard_task_progress();
create table public.task_attempts (
  id uuid primary key default gen_random_uuid(),
  task_progress_id uuid not null references public.task_progress(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  score numeric(7,2) not null check (score >= 0),
  max_score numeric(7,2) not null check (max_score > 0 and score <= max_score),
  feedback text not null default '',
  attempted_at timestamptz not null default now()
);
create index task_attempts_user_time_idx on public.task_attempts(user_id, attempted_at desc);
create or replace function public.guard_task_attempt_timestamp()
returns trigger language plpgsql set search_path = public as $$
begin
  new.attempted_at := now();
  return new;
end;
$$;
create trigger task_attempts_timestamp_guard before insert on public.task_attempts
for each row execute function public.guard_task_attempt_timestamp();
create table public.skill_evidence (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  skill_id text not null references public.skills(id),
  task_progress_id uuid not null references public.task_progress(id) on delete cascade,
  evidence_note text not null default '',
  created_at timestamptz not null default now(),
  unique (user_id, skill_id, task_progress_id)
);
create or replace function public.guard_skill_evidence_timestamp()
returns trigger language plpgsql set search_path = public as $$
begin
  new.created_at := now();
  return new;
end;
$$;
create trigger skill_evidence_timestamp_guard before insert on public.skill_evidence
for each row execute function public.guard_skill_evidence_timestamp();
-- Derived view: no duplicate mastery score is stored. Unassessed skills remain unscored.
create view public.student_skill_progress with (security_invoker = true) as
select tp.user_id,
       s.id as skill_id,
       s.name as skill_name,
       count(distinct tp.id) filter (where tp.status = 'completed') as completed_activities,
       count(distinct tp.id) filter (where tp.status = 'in_progress') as in_progress_activities,
       count(distinct ta.id) as assessed_attempts,
       avg(ta.score / nullif(ta.max_score, 0) * 100) as mean_assessment_percent,
       max(tp.completed_at) as last_completed_at
from public.task_progress tp
join public.roadmap_stage_tasks rst on rst.id = tp.roadmap_stage_task_id
join public.tasks t on t.id = rst.task_id
join public.task_skills ts on ts.task_id = t.id
join public.skills s on s.id = ts.skill_id
left join public.task_attempts ta on ta.task_progress_id = tp.id and ta.user_id = tp.user_id
group by tp.user_id, s.id, s.name;

create table public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_user_id uuid not null references auth.users(id) on delete cascade,
  reason text,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_user_id),
  check (blocker_id <> blocked_user_id)
);

create or replace function public.is_blocked_for_current_user(other_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = auth.uid() and b.blocked_user_id = other_user)
       or (b.blocker_id = other_user and b.blocked_user_id = auth.uid())
  );
$$;
revoke all on function public.is_blocked_for_current_user(uuid) from public;
grant execute on function public.is_blocked_for_current_user(uuid) to authenticated;

create table public.profile_discovery_events (
  user_id uuid not null references auth.users(id) on delete cascade,
  requested_at timestamptz not null default now()
);
create index profile_discovery_events_user_time_idx on public.profile_discovery_events(user_id, requested_at desc);
alter table public.profile_discovery_events enable row level security;
-- Accessed only by the bounded SECURITY DEFINER discovery RPC; no client table policies.

create table public.public_profile_approvals (
  user_id uuid primary key references auth.users(id) on delete cascade,
  status text not null check (status in ('pending','approved','rejected')),
  reviewer_id uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  check ((status = 'pending' and reviewed_at is null) or (status in ('approved','rejected') and reviewed_at is not null))
);
alter table public.public_profile_approvals enable row level security;
-- Moderation/server-only: no client policies. Any profile edit invalidates approval.
create or replace function public.invalidate_public_profile_approval()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.display_name is distinct from old.display_name
     or new.grade_band is distinct from old.grade_band
     or new.interests is distinct from old.interests
     or new.career_interests is distinct from old.career_interests
     or new.opted_in_skills is distinct from old.opted_in_skills
     or new.introduction is distinct from old.introduction then
    delete from public.public_profile_approvals where user_id = old.id;
  end if;
  return new;
end;
$$;
create trigger profile_edit_invalidates_approval before update on public.profiles
for each row execute function public.invalidate_public_profile_approval();

create table public.connection_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','declined','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (requester_id <> recipient_id)
);
create unique index active_connection_pair_unique on public.connection_requests
  (least(requester_id, recipient_id), greatest(requester_id, recipient_id))
  where status in ('pending','accepted');
create index connection_requests_recipient_idx on public.connection_requests(recipient_id, status, created_at desc);
create index connection_requests_requester_idx on public.connection_requests(requester_id, status, created_at desc);
create trigger connection_requests_updated_at before update on public.connection_requests for each row execute function public.set_updated_at();

create or replace function public.enforce_connection_request_rules()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  recent_count integer;
begin
  if tg_op = 'UPDATE' and (new.requester_id <> old.requester_id or new.recipient_id <> old.recipient_id) then
    raise exception 'Connection participants cannot be changed';
  end if;
  if tg_op = 'INSERT' then
    if new.requester_id = new.recipient_id or new.requester_id <> auth.uid()
       or public.is_blocked_for_current_user(new.recipient_id) then
      raise exception 'This connection request is not allowed';
    end if;
    if not public.current_consent_is_granted(new.requester_id, 'profile_discovery')
       or not public.current_consent_is_granted(new.requester_id, 'adult_supervision')
       or not public.current_consent_is_granted(new.recipient_id, 'profile_discovery')
       or not public.current_consent_is_granted(new.recipient_id, 'adult_supervision')
       or not exists (
         select 1 from public.profiles p join public.public_profile_approvals a on a.user_id = p.id and a.status = 'approved'
         where p.id = new.requester_id and p.networking_enabled
       )
       or not exists (
         select 1 from public.profiles p join public.public_profile_approvals a on a.user_id = p.id and a.status = 'approved'
         where p.id = new.recipient_id and p.networking_enabled
       ) then
      raise exception 'Both students must have approved, current profile discovery consent';
    end if;
      select count(*) into recent_count from public.connection_requests r
      where r.requester_id = new.requester_id and r.created_at > now() - interval '24 hours';
    if recent_count >= 10 then raise exception 'Daily connection request limit reached'; end if;
  end if;
  return new;
end;
$$;
create trigger connection_request_guard before insert or update on public.connection_requests
for each row execute function public.enforce_connection_request_rules();

create or replace function public.discover_profiles(max_results integer default 10)
returns table (
  profile_id uuid,
  display_name text,
  grade_band text,
  interests text[],
  career_interests text[],
  opted_in_skills text[],
  introduction text
)
language plpgsql security definer set search_path = public as $$
declare
  subject_user uuid := auth.uid();
  recent_count integer;
begin
  if subject_user is null or not exists (
    select 1 from public.profiles p
    join public.public_profile_approvals a on a.user_id = p.id and a.status = 'approved'
    where p.id = subject_user and p.networking_enabled
  ) or not public.current_consent_is_granted(subject_user, 'profile_discovery')
    or not public.current_consent_is_granted(subject_user, 'adult_supervision') then
    raise exception 'Profile discovery is unavailable until current consent and supervision checks are complete';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(subject_user::text, 0));
  select count(*) into recent_count from public.profile_discovery_events e
    where e.user_id = subject_user and e.requested_at > now() - interval '24 hours';
  if recent_count >= 5 then raise exception 'Daily profile discovery limit reached'; end if;
  insert into public.profile_discovery_events(user_id) values (subject_user);
  return query
    select p.id, p.display_name, p.grade_band, p.interests, p.career_interests, p.opted_in_skills, p.introduction
    from public.profiles p
    join public.public_profile_approvals approval on approval.user_id = p.id and approval.status = 'approved'
    where p.id <> subject_user and p.networking_enabled
      and public.current_consent_is_granted(p.id, 'profile_discovery')
      and public.current_consent_is_granted(p.id, 'adult_supervision')
      and not public.is_blocked_for_current_user(p.id)
    order by random()
    limit least(greatest(coalesce(max_results, 10), 1), 20);
end;
$$;
revoke all on function public.discover_profiles(integer) from public;
grant execute on function public.discover_profiles(integer) to authenticated;

create or replace function public.send_connection_request(target_user uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  subject_user uuid := auth.uid();
  recent_count integer;
  request_id uuid;
begin
  if subject_user is null or target_user is null or subject_user = target_user then
    raise exception 'Connection request is not allowed';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(subject_user::text, 1));
  if public.is_blocked_for_current_user(target_user)
     or not exists (select 1 from public.profiles p join public.public_profile_approvals a on a.user_id = p.id and a.status = 'approved' where p.id = subject_user and p.networking_enabled)
     or not exists (select 1 from public.profiles p join public.public_profile_approvals a on a.user_id = p.id and a.status = 'approved' where p.id = target_user and p.networking_enabled)
     or not public.current_consent_is_granted(subject_user, 'profile_discovery')
     or not public.current_consent_is_granted(subject_user, 'adult_supervision')
     or not public.current_consent_is_granted(target_user, 'profile_discovery')
     or not public.current_consent_is_granted(target_user, 'adult_supervision') then
    raise exception 'Connection request is not allowed';
  end if;
  select count(*) into recent_count from public.connection_requests r
    where r.requester_id = subject_user and r.created_at > now() - interval '24 hours';
  if recent_count >= 10 then raise exception 'Daily connection request limit reached'; end if;
  insert into public.connection_requests(requester_id, recipient_id)
    values (subject_user, target_user) returning id into request_id;
  return request_id;
end;
$$;
revoke all on function public.send_connection_request(uuid) from public;
grant execute on function public.send_connection_request(uuid) to authenticated;

create or replace function public.remove_connections_after_block()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from public.connection_requests r
  where (r.requester_id = new.blocker_id and r.recipient_id = new.blocked_user_id)
     or (r.requester_id = new.blocked_user_id and r.recipient_id = new.blocker_id);
  return new;
end;
$$;
create trigger blocks_remove_connections after insert on public.user_blocks
for each row execute function public.remove_connections_after_block();

create table public.user_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reported_user_id uuid not null references auth.users(id) on delete cascade,
  category text not null check (category in ('inappropriate_profile','harassment','safety_concern','other')),
  details text not null default '' check (char_length(details) <= 2000),
  status text not null default 'open' check (status in ('open','reviewing','resolved','dismissed')),
  created_at timestamptz not null default now(),
  check (reporter_id <> reported_user_id)
);
create index user_reports_status_idx on public.user_reports(status, created_at desc);
create or replace function public.limit_user_reports()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  recent_count integer;
begin
  if new.reporter_id <> auth.uid() then raise exception 'Report owner mismatch'; end if;
  new.created_at := now();
  perform pg_advisory_xact_lock(hashtextextended(new.reporter_id::text, 2));
  select count(*) into recent_count from public.user_reports r
    where r.reporter_id = new.reporter_id and r.created_at > now() - interval '24 hours';
  if recent_count >= 5 then raise exception 'Daily report limit reached'; end if;
  return new;
end;
$$;
create trigger user_reports_rate_limit before insert on public.user_reports
for each row execute function public.limit_user_reports();

create table public.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  report_id uuid references public.user_reports(id) on delete set null,
  moderator_id uuid references auth.users(id) on delete set null,
  target_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  notes text not null default '',
  created_at timestamptz not null default now()
);

-- Curated content is explicitly illustrative until sources and review dates are supplied.
insert into public.skills(id, name, description) values
 ('problem_solving','Problem-solving','Breaking a challenge into manageable steps.'),
 ('coding','Coding','Giving clear instructions to a computer.'),
 ('communication','Communication','Sharing ideas and listening to others.'),
 ('teamwork','Teamwork','Working with others toward a shared goal.'),
 ('science','Science','Observing, questioning, and testing ideas.'),
 ('creativity','Creativity','Imagining and improving ideas.')
on conflict (id) do nothing;
insert into public.interests(id, name) values
 ('technology','Technology'),('creating','Creating'),('problem_solving','Solving problems'),
 ('helping','Helping people'),('science','Science'),('communication','Communication'),
 ('learning','Learning'),('people','Understanding people'),('nature','Nature')
on conflict (id) do nothing;
insert into public.careers(id,title,summary,responsibilities,education_pathway,beginner_activity,related_career_ids,content_kind) values
 ('software_developer','Software Developer','Creates and improves apps, websites, and other software.','["Break problems into steps","Write and test code","Work with a team to improve a product"]','Many routes are possible, including school courses, projects, certificates, or a degree. Requirements vary by role and location.','Design a simple app that helps with one small everyday problem.',array['game_designer','data_analyst'],'illustrative_seed'),
 ('nurse','Nurse','Supports people’s health as part of a care team.','["Listen to patients","Share health information","Work with a supervised care team"]','Nursing roles require approved education and licensing that depend on the country and role. Check official local guidance.','Explore how a care team communicates, then make a poster about a healthy habit using trusted sources.',array['teacher','environmental_scientist'],'illustrative_seed'),
 ('teacher','Teacher','Helps learners understand ideas and build confidence.','["Explain ideas in different ways","Plan learning activities","Encourage and support learners"]','Teacher preparation and certification depend on the school system and location.','Teach someone a favorite concept using a drawing, demonstration, or short explanation.',array['nurse','designer'],'illustrative_seed'),
 ('designer','Product Designer','Plans how products look, feel, and work for people.','["Learn what people need","Sketch and test ideas","Improve designs using feedback"]','Designers build skills through projects and different education routes.','Redesign a classroom object so it is easier for more people to use.',array['software_developer','game_designer'],'illustrative_seed'),
 ('environmental_scientist','Environmental Scientist','Studies the natural world and ways to care for it.','["Observe the environment","Collect and interpret information","Explain findings and possible solutions"]','Some roles ask for science education or field experience. Requirements differ; consult current local sources.','Keep a short observation log about a local plant, animal, or weather pattern.',array['nurse','data_analyst'],'illustrative_seed'),
 ('game_designer','Game Designer','Creates the rules, stories, and experiences in games.','["Develop game ideas","Test whether play is clear and fun","Collaborate with artists and developers"]','People enter game design through varied study and project paths.','Create a paper prototype for a short game, then ask someone to try it.',array['software_developer','designer'],'illustrative_seed'),
 ('data_analyst','Data Analyst','Looks for useful patterns in information and explains them.','["Ask clear questions","Organize and explore data","Communicate findings honestly"]','Data roles use different tools and education routes; specific employer requirements vary.','Collect a small, non-private class survey and show its results in a simple chart.',array['software_developer','environmental_scientist'],'illustrative_seed')
on conflict (id) do nothing;
insert into public.career_skills(career_id,skill_id) values
 ('software_developer','problem_solving'),('software_developer','coding'),('software_developer','communication'),
 ('nurse','communication'),('nurse','teamwork'),('nurse','science'),
 ('teacher','communication'),('teacher','teamwork'),('teacher','creativity'),
 ('designer','creativity'),('designer','problem_solving'),('designer','communication'),
 ('environmental_scientist','science'),('environmental_scientist','problem_solving'),('environmental_scientist','communication'),
 ('game_designer','creativity'),('game_designer','problem_solving'),('game_designer','coding'),
 ('data_analyst','problem_solving'),('data_analyst','communication'),('data_analyst','coding')
on conflict do nothing;
insert into public.career_interests(career_id,interest_id) values
 ('software_developer','technology'),('software_developer','creating'),('software_developer','problem_solving'),
 ('nurse','helping'),('nurse','science'),('nurse','communication'),
 ('teacher','helping'),('teacher','learning'),('teacher','communication'),('teacher','creating'),
 ('designer','creating'),('designer','people'),('designer','problem_solving'),
 ('environmental_scientist','science'),('environmental_scientist','nature'),('environmental_scientist','problem_solving'),
 ('game_designer','technology'),('game_designer','creating'),('game_designer','problem_solving'),
 ('data_analyst','technology'),('data_analyst','science'),('data_analyst','problem_solving')
on conflict do nothing;

insert into public.tasks(id,title,description,learning_objective,career_relevance,grade_min,grade_max,difficulty,estimated_minutes,instructions,completion_criteria) values
 ('career_snapshot','Explore a career','Choose a career and learn what a person might do in a typical day.','Describe one responsibility and ask a question.','Career exploration and communication.',1,5,'beginner',15,'["Pick a career topic","Draw or describe one activity","Share one question with a trusted adult"]','Create one description or drawing and one question.'),
 ('career_research','Explore a career pathway','Compare trusted information about a career and its possible learning routes.','Summarize responsibilities and identify questions about local pathways.','Research and critical thinking.',6,12,'developing',25,'["Use trusted school or official sources","Compare two information sources","Record what you still want to learn"]','Write a short summary and list one open question.'),
 ('practice_communication','Practice communication','Explain an idea to someone and invite feedback.','Share an idea clearly and listen to another perspective.','Communication and reflection.',1,12,'beginner',20,'["Choose an idea","Explain it in your own words","Ask what was clear or confusing"]','Record one piece of feedback and one thing you might improve.'),
 ('small_project','Create a small project','Make a beginner-sized project connected to an interest.','Plan, create, and reflect on a simple project.','Planning, creativity, and problem-solving.',1,12,'beginner',35,'["Choose a small goal","Make a first version","Reflect on one next step"]','Share a completed first version and one possible improvement.')
on conflict (id) do nothing;
insert into public.task_skills(task_id,skill_id) values
 ('career_snapshot','communication'),('career_research','problem_solving'),('career_research','communication'),
 ('practice_communication','communication'),('small_project','creativity'),('small_project','problem_solving')
on conflict do nothing;

insert into public.assessments(id,slug,version,title,description,scoring_rules,is_active) values
 ('00000000-0000-4000-8000-000000000001','self-reflection','1.0','Self-reflection snapshot','An original reflection exercise. Not a validated psychological or career assessment.','{"scale":"1-5 agreement","dimensions":"mean of two responses scaled to 0-100","limitations":"not clinical; not a measure of ability or suitability"}',true)
on conflict (slug,version) do nothing;
insert into public.assessment_questions(id,assessment_id,question_order,prompt,dimension) values
 ('00000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000001',1,'I enjoy finding different ways to make something.','creative'),
 ('00000000-0000-4000-8000-000000000012','00000000-0000-4000-8000-000000000001',2,'I like expressing ideas through stories, art, or design.','creative'),
 ('00000000-0000-4000-8000-000000000013','00000000-0000-4000-8000-000000000001',3,'I enjoy figuring out how a problem works.','analytical'),
 ('00000000-0000-4000-8000-000000000014','00000000-0000-4000-8000-000000000001',4,'I like looking for patterns and asking why.','analytical'),
 ('00000000-0000-4000-8000-000000000015','00000000-0000-4000-8000-000000000001',5,'I feel good when I help someone learn or solve a challenge.','helping'),
 ('00000000-0000-4000-8000-000000000016','00000000-0000-4000-8000-000000000001',6,'I like listening to people and understanding their point of view.','helping'),
 ('00000000-0000-4000-8000-000000000017','00000000-0000-4000-8000-000000000001',7,'I enjoy making, fixing, or trying things hands-on.','building'),
 ('00000000-0000-4000-8000-000000000018','00000000-0000-4000-8000-000000000001',8,'I like learning how tools, machines, or systems work.','building')
on conflict do nothing;
insert into public.assessment_options(question_id,option_order,score,label)
select q.id, n, n, case n when 1 then 'Not like me' when 2 then 'A little like me' when 3 then 'Sometimes like me' when 4 then 'Often like me' else 'Very like me' end
from public.assessment_questions q cross join generate_series(1,5) n
where q.assessment_id = '00000000-0000-4000-8000-000000000001'
on conflict do nothing;

-- RLS is mandatory on all client-accessible tables. Seed/catalog tables are read-only to clients.
alter table public.profiles enable row level security;
alter table public.user_preferences enable row level security;
alter table public.consent_records enable row level security;
alter table public.assessments enable row level security;
alter table public.assessment_questions enable row level security;
alter table public.assessment_options enable row level security;
alter table public.assessment_attempts enable row level security;
alter table public.assessment_answers enable row level security;
alter table public.assessment_results enable row level security;
alter table public.journal_entries enable row level security;
alter table public.journal_audio_assets enable row level security;
alter table public.journal_insights enable row level security;
alter table public.skills enable row level security;
alter table public.interests enable row level security;
alter table public.careers enable row level security;
alter table public.career_skills enable row level security;
alter table public.career_interests enable row level security;
alter table public.career_recommendations enable row level security;
alter table public.saved_careers enable row level security;
alter table public.career_goals enable row level security;
alter table public.roadmaps enable row level security;
alter table public.roadmap_stages enable row level security;
alter table public.learning_resources enable row level security;
alter table public.tasks enable row level security;
alter table public.task_skills enable row level security;
alter table public.task_resources enable row level security;
alter table public.roadmap_stage_tasks enable row level security;
alter table public.task_progress enable row level security;
alter table public.task_attempts enable row level security;
alter table public.skill_evidence enable row level security;
alter table public.user_blocks enable row level security;
alter table public.connection_requests enable row level security;
alter table public.user_reports enable row level security;
alter table public.moderation_actions enable row level security;

-- Public profile discovery is served only through the bounded, consent-checked RPC above.
create policy profiles_read_self_only on public.profiles for select to authenticated using (id = auth.uid());
create policy profiles_insert_self on public.profiles for insert to authenticated with check (id = auth.uid());
create policy profiles_update_self on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy preferences_owner_all on public.user_preferences for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy consent_owner_read on public.consent_records for select to authenticated using (user_id = auth.uid());
create policy consent_owner_insert on public.consent_records for insert to authenticated with check (user_id = auth.uid() and purpose <> 'adult_supervision');

create policy assessments_read_active on public.assessments for select to authenticated using (is_active);
create policy assessment_questions_read_active on public.assessment_questions for select to authenticated using (
  exists (select 1 from public.assessments a where a.id = assessment_id and a.is_active)
);
create policy assessment_options_read_active on public.assessment_options for select to authenticated using (
  exists (select 1 from public.assessment_questions q join public.assessments a on a.id = q.assessment_id where q.id = question_id and a.is_active)
);
create policy attempts_owner_select on public.assessment_attempts for select to authenticated using (user_id = auth.uid());
create policy attempts_owner_insert on public.assessment_attempts for insert to authenticated with check (user_id = auth.uid());
create policy attempts_owner_update on public.assessment_attempts for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy answers_owner_select on public.assessment_answers for select to authenticated using (
  exists (select 1 from public.assessment_attempts a where a.id = attempt_id and a.user_id = auth.uid())
);
create policy answers_owner_insert on public.assessment_answers for insert to authenticated with check (
  exists (select 1 from public.assessment_attempts a where a.id = attempt_id and a.user_id = auth.uid() and a.status = 'in_progress')
);
create policy answers_owner_update on public.assessment_answers for update to authenticated using (
  exists (select 1 from public.assessment_attempts a where a.id = attempt_id and a.user_id = auth.uid() and a.status = 'in_progress')
) with check (
  exists (select 1 from public.assessment_attempts a where a.id = attempt_id and a.user_id = auth.uid() and a.status = 'in_progress')
);
create policy results_owner_select on public.assessment_results for select to authenticated using (
  exists (select 1 from public.assessment_attempts a where a.id = attempt_id and a.user_id = auth.uid())
);
-- Results are server-written only; no client INSERT/UPDATE policy is intentionally provided.

create policy journals_owner_all on public.journal_entries for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy journal_audio_owner_all on public.journal_audio_assets for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid() and exists (
    select 1 from public.journal_entries j where j.id = journal_entry_id and j.user_id = auth.uid()
  ));
create policy journal_insights_owner_select on public.journal_insights for select to authenticated using (user_id = auth.uid());
-- AI insight records must be written by a consent-checking server function.

create policy skills_read_authenticated on public.skills for select to authenticated using (true);
create policy interests_read_authenticated on public.interests for select to authenticated using (true);
create policy careers_read_published on public.careers for select to authenticated using (is_published);
create policy career_skills_read_authenticated on public.career_skills for select to authenticated using (true);
create policy career_interests_read_authenticated on public.career_interests for select to authenticated using (true);
create policy recommendations_owner_all on public.career_recommendations for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy saved_careers_owner_all on public.saved_careers for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy career_goals_owner_all on public.career_goals for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy roadmaps_owner_all on public.roadmaps for all to authenticated
  using (user_id = auth.uid() and exists (select 1 from public.career_goals g where g.id = career_goal_id and g.user_id = auth.uid()))
  with check (user_id = auth.uid() and exists (select 1 from public.career_goals g where g.id = career_goal_id and g.user_id = auth.uid()));
create policy roadmap_stages_owner_all on public.roadmap_stages for all to authenticated
  using (exists (select 1 from public.roadmaps r where r.id = roadmap_id and r.user_id = auth.uid()))
  with check (exists (select 1 from public.roadmaps r where r.id = roadmap_id and r.user_id = auth.uid()));
create policy resources_read_reviewed on public.learning_resources for select to authenticated using (is_published and is_reviewed);
create policy tasks_read_published on public.tasks for select to authenticated using (is_published);
create policy task_skills_read_authenticated on public.task_skills for select to authenticated using (true);
create policy task_resources_read_authenticated on public.task_resources for select to authenticated using (
  exists (select 1 from public.tasks t join public.learning_resources r on r.id = resource_id where t.id = task_id and t.is_published and r.is_published and r.is_reviewed)
);
create policy roadmap_stage_tasks_owner_all on public.roadmap_stage_tasks for all to authenticated
  using (exists (select 1 from public.roadmap_stages s join public.roadmaps r on r.id = s.roadmap_id where s.id = stage_id and r.user_id = auth.uid()))
  with check (exists (select 1 from public.roadmap_stages s join public.roadmaps r on r.id = s.roadmap_id where s.id = stage_id and r.user_id = auth.uid()));
create policy task_progress_owner_all on public.task_progress for all to authenticated
  using (user_id = auth.uid() and exists (
    select 1 from public.roadmap_stage_tasks rt join public.roadmap_stages s on s.id = rt.stage_id
    join public.roadmaps r on r.id = s.roadmap_id where rt.id = roadmap_stage_task_id and r.user_id = auth.uid()
  ))
  with check (user_id = auth.uid() and exists (
    select 1 from public.roadmap_stage_tasks rt join public.roadmap_stages s on s.id = rt.stage_id
    join public.roadmaps r on r.id = s.roadmap_id where rt.id = roadmap_stage_task_id and r.user_id = auth.uid()
  ));
create policy task_attempts_owner_read on public.task_attempts for select to authenticated using (user_id = auth.uid());
create policy task_attempts_owner_insert on public.task_attempts for insert to authenticated with check (
  user_id = auth.uid() and exists (select 1 from public.task_progress p where p.id = task_progress_id and p.user_id = auth.uid())
);
create policy skill_evidence_owner_read on public.skill_evidence for select to authenticated using (user_id = auth.uid());
create policy skill_evidence_owner_insert on public.skill_evidence for insert to authenticated with check (
  user_id = auth.uid() and exists (
    select 1 from public.task_progress p
    join public.roadmap_stage_tasks rst on rst.id = p.roadmap_stage_task_id
    join public.task_skills ts on ts.task_id = rst.task_id and ts.skill_id = skill_evidence.skill_id
    where p.id = task_progress_id and p.user_id = auth.uid() and p.status = 'completed'
  )
);

create policy blocks_participant_read on public.user_blocks for select to authenticated using (blocker_id = auth.uid() or blocked_user_id = auth.uid());
create policy blocks_owner_insert on public.user_blocks for insert to authenticated with check (blocker_id = auth.uid());
create policy blocks_owner_delete on public.user_blocks for delete to authenticated using (blocker_id = auth.uid());
create policy requests_participant_read on public.connection_requests for select to authenticated using (
  (requester_id = auth.uid() or recipient_id = auth.uid())
  and not public.is_blocked_for_current_user(case when requester_id = auth.uid() then recipient_id else requester_id end)
);
-- Inserts are available only through send_connection_request(), which checks consent and rate limits.
create policy requests_recipient_respond on public.connection_requests for update to authenticated
  using (recipient_id = auth.uid() and status = 'pending' and not public.is_blocked_for_current_user(requester_id))
  with check (recipient_id = auth.uid() and status in ('accepted','declined') and not public.is_blocked_for_current_user(requester_id));
create policy requests_sender_cancel on public.connection_requests for update to authenticated
  using (requester_id = auth.uid() and status = 'pending' and not public.is_blocked_for_current_user(recipient_id))
  with check (requester_id = auth.uid() and status = 'cancelled');
create policy requests_connected_remove on public.connection_requests for update to authenticated
  using (status = 'accepted' and (requester_id = auth.uid() or recipient_id = auth.uid())
    and not public.is_blocked_for_current_user(case when requester_id = auth.uid() then recipient_id else requester_id end))
  with check (status = 'cancelled' and (requester_id = auth.uid() or recipient_id = auth.uid()));
create policy reports_submit_self on public.user_reports for insert to authenticated with check (
  reporter_id = auth.uid() and reported_user_id <> auth.uid()
);
-- Reports and moderation actions are not readable/writable by ordinary client users.
-- Trusted moderation tooling uses the service role only on a server; never in the app.

-- Private voice journal bucket. Paths MUST be <auth.uid()>/<entry-id>/<filename>.
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('journal-audio','journal-audio',false,52428800,array['audio/mp4','audio/aac','audio/m4a','audio/mpeg','audio/wav','audio/webm'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
create policy journal_audio_storage_read_owner on storage.objects for select to authenticated using (
  bucket_id = 'journal-audio' and (storage.foldername(name))[1] = auth.uid()::text
);
create policy journal_audio_storage_insert_owner on storage.objects for insert to authenticated with check (
  bucket_id = 'journal-audio' and (storage.foldername(name))[1] = auth.uid()::text
);
create policy journal_audio_storage_delete_owner on storage.objects for delete to authenticated using (
  bucket_id = 'journal-audio' and (storage.foldername(name))[1] = auth.uid()::text
);

-- Seed content has no fabricated salary, growth, or licensing statistics.
-- Replace illustrative seed copy only through reviewed admin migrations/workflows.
