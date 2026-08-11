# FIRSTVUE development handoff

Project path: `C:\Users\User1\Documents\Codex\2026-08-10\now-inspect-the-existing-firstvue-repository-2\firstvue`

## Current app state

FIRSTVUE is a dark, futuristic Flutter MVP using Supabase. The home-to-Barbers-to-results-to-profile flow works. Prototype barber cards remain intentionally marked as mock data. Approved FirstVue barber businesses are read from Supabase and appear in a separate **FIRSTVUE VERIFIED** section.

Flutter dependencies include `supabase_flutter`, `geolocator`, and `image_picker`. Flutter SDK is installed at `C:\Users\User1\develop\flutter\bin\flutter.bat`.

Run from the project root:

```powershell
& "C:\Users\User1\develop\flutter\bin\flutter.bat" pub get
& "C:\Users\User1\develop\flutter\bin\flutter.bat" run -d chrome
```

## Completed app features

- Dark neon FIRSTVUE home screen and bottom navigation.
- Barbers search, prototype location filters, current-location prototype distances, and business profile navigation.
- Supabase email/password authentication and Profile sign-in/sign-out.
- Rental listings: authenticated posting, pending/approved status, image/video upload for rentals, owner listing view, owner inquiry inbox, and admin rental approvals.
- Business owner workflow: create a new/unlisted business submission, admin approval/rejection, owner profile editing (about, address, city/state/ZIP, comma-separated services), and live verified-business profile display.
- Approved barber-type businesses appear in Barbers discovery and open `FirstVueBusinessProfileScreen`.
- Database and Storage security uses RLS. Do not use a Supabase service-role key in the Flutter app.

## Supabase configuration

The app initializes Supabase in `lib/main.dart` using `lib/config/supabase_config.dart`. The project URL and publishable key are already configured locally. Keep the publishable key only; never place a service-role key in the client.

## Migrations already created

All files are under `supabase/migrations/`. The user reported running these successfully:

- `20260810_initial_firstvue_schema.sql`
- `20260810_rental_media_storage.sql`
- `20260810_rental_media_read_policy.sql`
- `20260810_rental_admin_approval_policy.sql`
- `20260810_rental_owner_inquiries_policy.sql`
- `20260810_business_submissions.sql`
- `20260810_business_admin_approval_policy.sql`
- `20260810_owner_business_profile_policy.sql`
- `20260810_business_services.sql`
- `20260810_business_media_storage.sql`
- `20260810_business_reviews.sql`

The SQL scripts using `drop policy if exists` only replace named access policies; they do not delete listings, users, or media.

## Admin setup

The current project owner was promoted to admin with an SQL update against `public.profiles.account_type`. Admin screens are available through Profile:

- Rental approvals
- Business approvals

Admin access is enforced by RLS policies checking `profiles.account_type = 'admin'`.

## Important current files

- `lib/main.dart` — app shell and Explore category cards.
- `lib/screens/barber_results_screen.dart` — prototype barbers plus approved FirstVue barber discovery.
- `lib/screens/firstvue_business_profile_screen.dart` — live verified business profile.
- `lib/screens/my_businesses_screen.dart` — owner profile editor.
- `lib/screens/rentals_screen.dart` — rentals, post form, inquiry flow.
- `lib/screens/admin_rentals_screen.dart` — rental moderation.
- `lib/screens/admin_business_submissions_screen.dart` — business moderation.
- `lib/screens/rental_inquiries_screen.dart` — owner inquiry inbox.
- `lib/services/rentals_store.dart` — rental data and media uploads.
- `lib/services/business_submission_service.dart` — business submissions, approval data, owner editing.
- `lib/services/approved_businesses_service.dart` — public approved business discovery/profile data.

## Known unfinished work

1. **Business media gallery UI is not implemented yet.**
   - The database/table and `business-media` Storage bucket are ready from `20260810_business_media_storage.sql`.
   - `image_picker` is installed.
   - Next implementation: owner selects image in `EditBusinessProfileScreen`, upload to `business-media/<user-id>/...`, insert `business_media` row, then display signed image URLs in `FirstVueBusinessProfileScreen`.

2. **Reviews UI is not implemented yet.**
   - `business_reviews` database/RLS migration is complete.
   - Next implementation: create a review service, add rating and written-review sheet in `FirstVueBusinessProfileScreen`, and display only approved reviews. Add an admin moderation queue later.

3. **Explore imagery is not integrated.**
   - One generated asset exists at `assets/images/explore_barbers.png`, but is not yet declared in `pubspec.yaml` or rendered in `FuturisticButton`.
   - User wants images on all Explore cards, fitted with `BoxFit.cover`, dark overlay, and readable labels. They asked that the Barbers image depict an African American barber cutting an African American client's hair. This updated asset has not been completed.

4. External place/provider APIs are deliberately not integrated. Do not scrape Google Maps or Apple Maps. Verify official API terms, attribution, caching, review/photo licensing, commercial-use terms, and privacy requirements before adding provider data.

## Product rules

- Preserve the dark futuristic theme: background `#03050A`, cyan `#00E5FF`, purple `#7C4DFF`, pink `#FF4081`, yellow `#FFC107`.
- Do not present mock prototype businesses as real production businesses.
- Do not replace the visual design with a generic Flutter theme.
- Keep industries extensible; do not hard-code the overall architecture to barbers.
- New businesses remain private until admin approval.

## Verification

Latest verified static check before this handoff:

```text
dart analyze lib
No issues found!
```

