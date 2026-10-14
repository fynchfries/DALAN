# DALAN MVP

DALAN is a Flutter student career-discovery app with five connected areas: Discover, Career, Planner, Skills, and Network. This repository started empty. The current implementation is a **local, persistent product demo plus a Supabase schema/auth integration boundary**—it is not yet a production-ready, cloud-synced student service.

## Current implementation

- Material 3 app shell, light/dark themes, persistent five-tab navigation, profile/settings, and grade 1–12 onboarding.
- Original eight-question reflection questionnaire with deterministic, documented 1–5 scoring. It is not validated, diagnostic, or a measure of ability.
- Text journal create/edit/delete with a 2,000-character UI limit. Journal content is stored locally in app preferences (not encrypted at rest) and never sent to AI. The demo warns users not to enter sensitive details.
- Curated illustrative career catalog, search/save, explainable preference matching, skill-gap hints, and career details. Match scores are not success probabilities; catalog copy is not verified labor-market guidance.
- Career goal selection builds a three-step, grade-banded starter roadmap. Task completion is persisted and drives practice-evidence summaries in Skills.
- Networking is **fictional sample data only**, disabled by default, with local request/accept/decline/cancel/block/report interactions. Nothing is sent to other users or a moderation service; there is no messaging.
- Local demo state persists with `shared_preferences`. The UI calls this out. Clearing local data is not account deletion.
- Optional Supabase email/password sign-up, sign-in, reset, and sign-out are wired when public client configuration is provided. **The app's profile, journals, assessments, goals, and task data remain local even when authenticated.**
- A relational Supabase migration includes catalog seeds, private user tables, storage restrictions, RLS, consent gates, connection rate limits, and restricted profile-discovery/request RPCs. It has not been applied or security-tested against a Supabase project.

## Important deferrals / release blockers

1. **Cloud data repositories and sync:** not connected. Do not use Supabase authentication with an expectation that workspace data is backed up or shared across devices.
2. **Voice journals and transcription:** not implemented. No microphone/audio permission or storage upload is implied.
3. **AI insights or explanations:** not implemented; no provider is configured and no journal text is transmitted.
4. **Real networking:** not connected to the app. The database RPCs are safeguards, not a launched social feature. Age assurance, guardian/supervision verification, staffed moderation, operational reporting, and safeguarding review are required before enabling real student discovery. The migration deliberately prevents a client from self-granting the supervision record.
5. **Task assessment/scoring and verified career/resource data:** no scored tasks or labor-market statistics are seeded. Verified sources and content review are needed before presenting qualifications or pathways as authoritative.
6. **Device toolchains:** Android and iOS project scaffolding is present, but this environment lacks Android Studio/SDK and full Xcode. Device builds need those toolchains; generated package identifiers are placeholders and must be changed before release.

See [Architecture and implementation status](docs/ARCHITECTURE.md) and [Security notes](docs/SECURITY.md).

## Requirements

- Flutter SDK with Dart **3.6 or newer** (Flutter 3.27+)
- Xcode for iOS builds; Android Studio/Android SDK for Android builds
- Optional Supabase CLI and a Supabase project for backend setup
- A GitHub Actions workflow runs Flutter analysis and tests when pushed

Flutter 3.47.7 and Dart 3.13.5 are installed. `flutter pub get`, `flutter analyze`, all 13 Flutter tests, and `flutter build web` have passed. iOS and Android builds have not been run: full Xcode and the Android SDK are not installed. This environment has Java 11, which is too old for the generated Android Gradle setup.

## Run the local demo

1. From this checkout, the browser demo can be launched with:
   ```sh
   flutter run -d chrome
   ```
   Or run `flutter build web` to produce `build/web/`.
2. For iOS, install and select full Xcode, accept its license, and install CocoaPods if prompted; then open an iOS simulator and run `flutter run -d ios`.
3. For Android, install Android Studio, its Android SDK and an emulator, and a supported JDK (17 or later); then run `flutter doctor --android-licenses` and `flutter run -d android`.
4. The generated native folders use a placeholder `com.example` identifier. Replace it with your own reverse-domain application/bundle ID before release.

After initializing/linking a local Supabase project, run `supabase test db` for the structural security contract. It has not been run here and is not a substitute for behavioral RLS tests.

The local demo needs no account or external service. Data is stored in app preferences on the current device without at-rest encryption; uninstalling the app or clearing its data may remove it. Do not use this demo for sensitive journal entries.

## Optional Supabase authentication

1. Create a Supabase project and review `supabase/migrations/20261014000000_dalan_mvp.sql` with your security reviewer.
2. The local Supabase CLI configuration is in `supabase/config.toml`. For local migration/security-contract checks and remote deployment:
   ```sh
   supabase start
   supabase db reset
   supabase test db
   supabase link --project-ref YOUR_PROJECT_REF
   supabase db push
   ```
3. Configure email confirmation and password-reset redirect URLs in Supabase Auth.
4. Copy the placeholders from `.env.example` into your local shell/secret manager. Pass only the project URL and publishable/anon key to Flutter:
   ```sh
   flutter run \
     --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
     --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
   ```

Do not add `.env` files, service-role keys, database passwords, AI keys, or other privileged secrets to the app or repository. A public Supabase key is not an authorization boundary; RLS is required. Supabase auth can be tested independently, but application workspace data currently remains device-local.

## Database notes

- Schema and seed data are in `supabase/migrations/`.
- Journal audio uses a private bucket and UID-prefixed storage object policies; the mobile app currently does not upload audio.
- Career seed content is explicitly `illustrative_seed`; no unsupported salary, employment outlook, or universal qualification claims are provided.
- Assessment results are intended to be server-written; a consent-aware scoring Edge Function is not included yet.
- `student_skill_progress` is a derived view, not a second source of task-completion truth.
- `supabase/tests/security_contract.sql` checks schema-level security invariants; it does not replace behavioral two-user RLS tests.
- Profile discovery is available only through a bounded RPC, not a public `profiles` table policy. The real app does not call this RPC.
- Service-role access is for trusted server operations only and must never be placed in the client.

## Tests

Flutter tests are under `test/` and cover scoring, missing recommendation inputs, grade-adapted roadmaps, local workspace persistence, task states, demo connection transitions, onboarding, and navigation. All 13 tests pass; `flutter analyze` reports no issues and the web build succeeds. iOS/Android builds and Supabase SQL/security tests remain unrun because their toolchains or project credentials are not configured.
