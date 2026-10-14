-- Structural regression checks for DALAN's Supabase schema.
-- Run after migrations with `supabase test db`; not a replacement for two-user RLS tests.
begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(6);

select extensions.ok(
  not exists (
    select 1
    from unnest(array[
      'profiles','user_preferences','consent_records','assessments','assessment_questions',
      'assessment_options','assessment_attempts','assessment_answers','assessment_results',
      'journal_entries','journal_audio_assets','journal_insights','skills','interests','careers',
      'career_skills','career_interests','career_recommendations','saved_careers','career_goals',
      'roadmaps','roadmap_stages','learning_resources','tasks','task_skills','task_resources',
      'roadmap_stage_tasks','task_progress','task_attempts','skill_evidence','user_blocks',
      'profile_discovery_events','public_profile_approvals','connection_requests','user_reports','moderation_actions'
    ]::text[]) as expected(table_name)
    left join pg_class c on c.oid = to_regclass('public.' || quote_ident(expected.table_name))
    where c.oid is null or not c.relrowsecurity
  ),
  'RLS is enabled on every DALAN table'
);

select extensions.ok(
  not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'profiles'
      and cmd = 'SELECT' and ('anon' = any(roles::text[]) or 'public' = any(roles::text[]))
  ),
  'profiles cannot be enumerated through direct public table reads'
);

select extensions.ok(
  not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'assessment_results'
      and cmd in ('INSERT','UPDATE','ALL')
  ),
  'assessment results remain server-written'
);

select extensions.ok(
  not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'journal_insights'
      and cmd in ('INSERT','UPDATE','ALL')
  ),
  'journal insight writes remain server-side and consent checked'
);

select extensions.ok(
  not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'connection_requests'
      and cmd = 'INSERT'
  ),
  'connection requests cannot bypass the bounded RPC'
);

select extensions.ok(
  has_function_privilege('authenticated', 'public.discover_profiles(integer)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.discover_profiles(integer)', 'EXECUTE'),
  'profile discovery RPC is authenticated-only'
);

select * from extensions.finish();
rollback;
