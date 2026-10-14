# Security and safeguarding notes

## Current demo

- The local demo is not an account-backed service. Its `shared_preferences` JSON is **not encrypted at rest**. Do not enter sensitive journal or identifying information. A user with access to the unlocked device/app data may access it.
- Journal text and assessment responses are not sent to a network or AI provider by the demo.
- Supabase auth credentials use the Supabase Flutter SDK only when explicitly configured. The app contains no service-role key, AI provider key, or database password. Authentication does not imply cloud workspace sync.
- Demo network profiles are fictional. Request/accept/report/block actions are local UI demonstrations; reports do not reach moderators.

## Database safeguards in the migration

- RLS is enabled on every app table and the internal profile-discovery rate-log table.
- Journal, assessment attempts/answers/results, recommendations, roadmaps, task progress, skill evidence, and preferences use user ownership checks.
- Career/task/resource seed tables are read-only to client roles; only published/reviewed content is exposed.
- Profiles have no public table-select policy. A bounded RPC returns only chosen alias, broad grade band, explicitly opted-in topics/skills, and short introduction; no email, precise location, journal, or raw assessment result is returned. Profiles require a server-managed approval, and edits invalidate that approval; no moderation approval workflow is deployed.
- Discovery RPC is capped at 20 profiles per call and five calls per user per day. Connection requests are capped at ten per sender per 24 hours; reports are capped at five per sender per 24 hours.
- Requests require both students to have profile-discovery consent and a server-written supervision record. The mobile client cannot create `adult_supervision` consent. Both users must opt in. A block removes relationship rows and prevents further requests.
- Journal audio storage is private with UID-prefixed paths and owner-only object policies. Audio recording/upload is not implemented in the app.
- `assessment_results` and `journal_insights` have no client write policy; they require a server function that validates scoring/consent.

## Not a launch approval

A structural SQL security-contract test is present in `supabase/tests/security_contract.sql`, but RLS has not been applied, that test has not been executed, the policies have not been tested with two real Supabase users, and no security specialist has reviewed them. A SQL policy is not a substitute for penetration testing, operational monitoring, or legal review. Before production:

1. Apply migrations to a disposable Supabase project and run automated RLS tests for cross-user access, forged IDs, storage paths, blocked relationships, and request/report rate limits.
2. Review auth settings, password recovery redirects, email enumeration, account deletion, backup/retention, logging, and incident response.
3. Replace local preference storage with encrypted/appropriately protected storage and server-side ownership repositories; verify journal deletion also deletes audio and derived insights.
4. Do not enable real discovery until age-assurance, legally appropriate guardian consent/adult supervision, moderation staffing, abuse escalation, and child-safety/privacy review are operational.
5. Implement report review and moderation actions server-side; test that moderators are authorized and actions are auditable.
6. Obtain security review of all `SECURITY DEFINER` functions, grants, search paths, rate limits, and storage policies. Service-role credentials must remain server-side.
