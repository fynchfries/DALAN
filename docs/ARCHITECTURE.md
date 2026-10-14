# Architecture and implementation status

## Repository baseline

The repository started empty. The app source, Supabase schema, tests, and Android/iOS/web project scaffolding are now present. Flutter 3.47.7 and Dart 3.13.5 were installed; dependency resolution, static analysis, all 13 Flutter tests, and a web build succeeded. iOS/Android builds remain unverified because full Xcode and the Android SDK are not installed (the available Java runtime is 11).

## Architecture decisions

- **Flutter/Dart, Material 3:** requested cross-platform stack and custom student-friendly green/cream theme.
- **Riverpod:** `WorkspaceController` owns synchronous app state and persists JSON through `shared_preferences` in explicit demo mode.
- **GoRouter:** five indexed shell branches keep navigation state while switching tabs; profile, authentication, and career detail are separate routes.
- **Feature-first layout:** `features/{discover,career,planner,skill_tracker,networking,onboarding,profile}` holds presentation/domain/data responsibilities; shared workspace models and storage live under `shared/`.
- **Deterministic personalization:** career matching v1 uses available interests (50%), self-reflection dimensions (30%), and completed-task skill evidence (20%); missing signal groups are excluded and remaining weights are normalized. These are configurable product assumptions, not validated measurements. Roadmaps are curated templates with grade-band changes.
- **Local demo boundary:** local state is not silently described as cloud persistence. The UI says it is saved on this device. Supabase email/password auth is an optional boundary, but cloud repositories/sync are not connected.
- **PostgreSQL/Supabase:** a single relational migration models identity, consent, assessment, journals, catalog, recommendations, goals, tasks, evidence, networking, and reports. Private records use ownership policies. Content tables are client read-only. RLS has not been deployed or independently reviewed.
- **No AI microservice:** no AI or speech provider is configured; no FastAPI server is justified for this demo. Journal text is never sent to an external service.

## State and derived data

`Workspace` is the sole source of truth for the local demo. Skill summaries are derived from completed roadmap tasks, not copied into separate mutable counters. A completed practice task is not a proficiency score. The SQL view `student_skill_progress` similarly derives progress from task-progress/attempt records and leaves skills with no assessment unscored.

The local demonstration supports one latest reflection result; the database model supports historical assessment attempts. Local demo relationships are explicitly fictional and cannot reach other users.

## Small complete user journey implemented locally

1. Create a local profile and select a grade/interests.
2. Optionally answer all eight reflection questions and see reproducible dimension scores.
3. Create/edit/delete private local journal notes.
4. Search/save a career and review a reasoned recommendation.
5. Set a career goal; generate three grade-banded tasks.
6. Update task state; see completion reflected in the Skill Tracker.

The five navigation areas are present. Networking is a local, fictional safety-control walkthrough, not a real social service.

## Deferred integrations

- Cloud data repositories for profile, assessment, journal, career preferences, goals, tasks, and evidence.
- Device microphone/voice recording, private audio upload/download, and transcription.
- Consent UI and server-side journal AI insight processing, output validation, model cost/retention controls, and deletion propagation.
- Moderated, real-user profile discovery/request APIs in the mobile app. The SQL provides bounded RPCs and consent/rate-limit checks, but age assurance, adult-supervision verification, moderation operations, abuse response, and legal review are prerequisites.
- Server-side assessment scoring/result insertion, task scoring workflows, push notifications, telemetry, and release CI.
- Verified career/education resources with source provenance and review cadence.

## Next engineering phases

1. Install/select full Xcode and set up Android Studio/SDK with a supported JDK; then build and smoke-test on iOS and Android devices/emulators.
2. Apply migrations to a disposable Supabase project and build automated RLS tests with at least two users, including storage and block scenarios.
3. Add Supabase repositories for normalized domain tables; switch off local demo only after end-to-end backend persistence is proven.
4. Implement auth-gated onboarding, password reset/deep links, and account/data deletion through reviewed server workflows.
5. Build age assurance and guardian consent, staffed moderation/reporting, and operational rate monitoring before real networking.
6. Add optional audio and AI only after consent, privacy, security, cost, deletion, and failure-mode reviews.
