# Early Access Feedback + Founding Member

## Files changed

### Migration (existing)
- `supabase/migrations/20261012_early_access_feedback_founding.sql`

### Dependencies
- `pubspec.yaml` — added `package_info_plus: ^10.0.0` (compatible with `geolocator`)

### Services
- `lib/services/profile_recognition_service.dart`
- `lib/services/early_access_feedback_service.dart`
- `lib/services/feature_ideas_service.dart`
- `lib/services/product_analytics_service.dart`
- `lib/services/early_access_prompt_service.dart`

### Screens
- `lib/screens/help_build_firstvue_screen.dart`
- `lib/screens/early_access_feedback_form_screen.dart`
- `lib/screens/feature_ideas_board_screen.dart`
- `lib/screens/about_firstvue_screen.dart`
- `lib/screens/admin_early_access_screen.dart`

### Widgets
- `lib/widgets/early_access_badge.dart`
- `lib/widgets/founding_member_badge.dart`
- `lib/widgets/early_access_feedback_prompt.dart`

### Wiring
- `lib/widgets/firstvue_settings_drawer.dart` — Early Access chip, Help Build FirstVue, About FirstVue, Admin → Early Access
- `lib/screens/profile_screen.dart` — founding badge loader
- `lib/screens/member_public_profile_screen.dart` — founding badge loader
- `lib/main.dart` — session counter + delayed feedback prompt after signed-in use

### Tests / docs
- `test/early_access_feedback_test.dart`
- `docs/EARLY_ACCESS_FEEDBACK_REPORT.md` (this file)

## Schema / RLS (from migration)

| Table | Purpose | RLS highlights |
| --- | --- | --- |
| `profile_recognition_badges` | Founding Member / Builder | Public read of active non-demo; admin manage |
| `early_access_feedback` | Feedback submissions | Insert/read own; admin read/update |
| `feature_ideas` | Idea board | Public reads approved; own pending visible; admin moderate via RPC |
| `feature_idea_votes` | Votes | One vote per (idea, profile); toggle via `fv_toggle_feature_idea_vote` |
| `product_events` | First-party analytics | Insert own; sanitize trigger strips query/message/tokens |
| `product_survey_responses` | PMF survey | Own responses; unique per survey_key |
| `early_access_prompt_state` | Prompt cooldown | Own row only |
| Storage `early-access-feedback` | Private screenshots | Upload under `{uid}/…`; owner + admin read |

RPCs: `fv_grant_recognition_badge`, `fv_revoke_recognition_badge`, `fv_toggle_feature_idea_vote`, `fv_moderate_feature_idea`, `fv_early_access_admin_overview`.

Demo profiles cannot receive badges and are excluded from admin overview aggregates (users, founding, DAU/WAU, events).

## Reused systems

- `AdminGate` / `AdminAuthService` for admin screen
- Settings drawer patterns (`_SettingsGroup` / `_SettingsTile`)
- `FirstVueTheme` / `context.fv` / gold accent
- `ProfileCards.fetchByUsername` for admin grant-by-username
- `image_picker` for optional screenshots
- `SharedPreferences` fallback for prompt cooldown (alongside remote `early_access_prompt_state`)
- Supabase Storage directly for `early-access-feedback` (bucket not in closed `MediaBucket` enum)

## Features

- Help Build FirstVue hub with six feedback categories
- Category forms with bug fields / near-me fields / optional title, screenshot, related feature, city
- Auto-attach: user id, app version, build, platform, device type, screen, timestamp
- Feature Ideas board: approved list, ▲ I want this votes, roadmap labels, submit idea, pending own ideas
- About FirstVue: Early Access copy + version/build
- Founding Member / Builder profile badge (subtle text under header)
- Early Access chip in Settings header
- Soft “How’s FirstVue going so far?” prompt after meaningful sessions (cooldown 14d / max 3 dismissals / weekly re-show cap)
- Optional PMF survey (“If FirstVue disappeared…”) for established testers via Help Build FirstVue — not shown in onboarding

## Admin

`AdminEarlyAccessScreen` tabs:
1. Overview — live `fv_early_access_admin_overview` (no invented metrics)
2. Feedback — list + mark reviewed/archived
3. Ideas — approve/reject + roadmap status
4. Founding — grant/revoke by profile UUID or username

## Analytics

`ProductAnalyticsService.recordEvent` writes allowed `product_events` names only; client strips sensitive keys (`password`, tokens, `query`, `message`, …) before insert; failures are silent.

Recorded from this feature set: `feedback_opened`, `feedback_submitted`, `idea_submitted`, `idea_voted`, `early_access_prompt_shown`, `early_access_prompt_dismissed`, `pmf_survey_answered`.

## Intentionally disabled

- No Stripe / checkout / paid Founding Member purchase path
- No password, auth token, DM body, or precise GPS collection in feedback/analytics
- Screenshot bucket remains private (not public CDN)
- PMF survey helper exists (`shouldShowPmfSurvey` / `submitPmfSurvey`) but is not auto-surfaced in UI yet (prompt focuses on feedback first)

## Issues needing attention

1. Apply migration `20261012_early_access_feedback_founding.sql` on the target Supabase project before shipping the client paths.
2. Confirm storage policies for `early-access-feedback` are live after migration.
3. `package_info_plus` on web returns platform package metadata; verify version/build display on Netlify web build.
4. Admin overview DAU/WAU only reflect users who emit `product_events` — sparse until more call sites adopt `ProductAnalyticsService`.
5. Optional follow-up: instrument more product surfaces with `ProductAnalyticsService` so DAU/WAU fill in.
