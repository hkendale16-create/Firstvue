# FIRSTVUE development export handoff

Export date: August 10, 2026

Project path on the original machine:

`C:\Users\User1\Documents\Codex\2026-08-10\now-inspect-the-existing-firstvue-repository-2\firstvue`

## Product overview

FIRSTVUE is a dark futuristic Flutter MVP backed by Supabase. It supports discovery of service businesses, verified business profiles, rental listings, authentication, owner workflows, media, reviews, and administrator moderation.

Preserve the established palette and design:

- Background: `#080B0F`
- Elevated surfaces: `#10151B` and `#151B22`
- Champagne gold: `#D8B56A`
- Warm gold: `#E5C16F`
- Muted teal: `#78B9BE`
- Muted blush: `#D68E98`
- Warm ivory: `#F4EFE6`

Typography and symbols now follow an elegant editorial system:

- Cormorant Garamond for branding, page titles, and major headings.
- Space Grotesk for readable body copy, controls, metadata, and navigation.
- Thin circular line symbols replace the earlier graffiti-sticker treatment.
- The shared theme is implemented in `lib/theme/firstvue_theme.dart`.
- Both fonts and their OFL licenses are bundled locally under `assets/fonts/`.

Do not present mock prototype businesses as real businesses. Keep business industries extensible rather than hard-coding the architecture exclusively to barbers. New businesses, rentals, and reviews remain private until administrator approval.

## Flutter environment

Flutter SDK used on the original machine:

`C:\Users\User1\develop\flutter\bin\flutter.bat`

Verified versions:

- Flutter 3.44.9 stable
- Dart 3.12.2

Run from the project root:

```powershell
& "C:\Users\User1\develop\flutter\bin\flutter.bat" pub get
& "C:\Users\User1\develop\flutter\bin\flutter.bat" test
& "C:\Users\User1\develop\flutter\bin\flutter.bat" run -d chrome
```

The machine has other Dart/Flutter installations on `PATH`. Calling the intended `flutter.bat` by its full path avoids version ambiguity. Flutter wrapper commands sometimes wait on stale SDK locks when another Flutter process is alive. Close stale `dart`, `dartvm`, and `dartaotruntime` processes before retrying.

## Supabase configuration and security

Supabase initializes in `lib/main.dart` using `lib/config/supabase_config.dart`.

- Keep only the project URL and publishable/anon client key in Flutter.
- Never place a Supabase service-role key in the client.
- Database and Storage access is protected by RLS.
- Administrator policies check `public.profiles.account_type = 'admin'`.

This handoff intentionally does not reproduce any configured key.

## Applied migrations

The user previously reported running these migrations successfully:

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
- `20260811_professional_profiles.sql` — the user reported this migration applied successfully on August 11, 2026.
- `20260811_professional_media_availability.sql` — created locally and must be applied after the professional profiles migration.

No new migration was required for the media gallery, review submission, or review moderation UI because they use the existing tables, buckets, and policies.

## Completed functionality

### App shell and discovery

- Dark neon home screen and bottom navigation.
- Search and prototype location filtering.
- Current-location prototype distances.
- Prototype barber profiles remain labeled as mock/prototype data.
- Approved Supabase barber businesses appear separately under `FIRSTVUE VERIFIED`.
- Approved businesses open a live `FirstVueBusinessProfileScreen`.

### Explore imagery

All Explore cards now use project images with `BoxFit.cover`, dark gradient overlays, readable labels, icons, and accent-aware pressed states.

Assets:

- `assets/images/explore_barbers.png`
- `assets/images/explore_stylists.png`
- `assets/images/explore_salons.png`
- `assets/images/explore_beauty.png`
- `assets/images/explore_barbershops.png`
- `assets/images/explore_rentals.png`

The barber image depicts an African American barber cutting an African American client's hair. The full `assets/images/` directory is declared in `pubspec.yaml`.

### Authentication and profile

- Supabase email/password sign-up, sign-in, and sign-out.
- Profile creation/upsert after authentication.
- Profile navigation to owner and administrator tools.

### Rentals

- Authenticated rental posting.
- Pending, approved, rejected, and owner listing states.
- Image/video upload to Supabase Storage.
- Rental inquiries and owner inbox.
- Administrator rental approval/rejection screen.

### Business owner workflow

- Submit a new/unlisted business.
- New submissions remain pending and private.
- Administrator approval/rejection.
- Owner business list and profile editor.
- Editable description, address, city, state, ZIP, and comma-separated services.
- Approved profile data appears live on verified business profiles.

### Business media gallery

Implemented in:

- `lib/services/business_media_service.dart`
- `lib/screens/my_businesses_screen.dart`
- `lib/screens/firstvue_business_profile_screen.dart`

Features:

- Owners select and upload multiple JPEG, PNG, or WebP images.
- Each image is limited to the Storage bucket's 50 MB maximum.
- Upload paths are scoped under `business-media/<user-id>/...`.
- Owners preview and delete their images.
- Verified profiles display a horizontal photo gallery.
- Images open in a full-size interactive viewer.
- Loading, empty, error, broken-image, and signed-out states are handled.

Current security boundary: business media policies grant approved-media reads to authenticated users. Signed-out visitors cannot load these private bucket images unless a future migration deliberately adds narrowly scoped `anon` read policies.

### Customer reviews

Implemented in:

- `lib/services/business_reviews_service.dart`
- `lib/screens/firstvue_business_profile_screen.dart`

Features:

- Signed-in users choose a 1–5 star rating.
- Written reviews support 1–2,000 characters.
- New reviews are inserted with `pending` status.
- Only approved reviews are displayed publicly to permitted readers.
- Approved review count and average rating are calculated in the client.
- Review cards show stars, body, and submission date.
- The database permits one review per user per business.

### Administrator review moderation

Implemented in:

- `lib/screens/admin_business_reviews_screen.dart`
- `lib/services/business_reviews_service.dart`
- `lib/screens/profile_screen.dart`

Features:

- `Review approvals` entry in Profile.
- Administrator-only pending review queue.
- Displays business name, rating, review body, and submission date.
- Approve and reject actions.
- Refresh, loading, error, restricted-access, and empty states.
- Access remains enforced by existing Supabase administrator RLS.

### Individual professional profiles

Implemented in:

- `supabase/migrations/20260811_professional_profiles.sql`
- `lib/services/professional_profiles_service.dart`
- `lib/screens/professional_profile_editor_screen.dart`
- `lib/screens/admin_professional_profiles_screen.dart`
- `lib/screens/professional_public_profile_screen.dart`
- `lib/screens/barber_results_screen.dart`

Features:

- Barbers, stylists, and beauty professionals have a separate person-based data model from business locations.
- Signed-in users create or edit one professional profile with type, biography, service area, and services.
- New and edited profiles return to pending and remain private until approval.
- Rejected professionals can revise and resubmit.
- Administrators have a pending professional approval queue with approve/reject actions.
- Approved professionals appear above fictional prototype professionals in matching discovery categories.
- Live profiles show only stored facts and never invent ratings, reviews, prices, or availability.
- Public reads are limited to approved profiles; owner and administrator access is enforced with RLS.
- Professionals can publish an accepting-new-clients status, a short availability note, and an optional booking URL.
- Owners can upload and delete JPEG, PNG, or WebP portfolio images in a private, user-scoped Storage bucket.
- Approved public profiles display availability and an interactive portfolio to authenticated readers.
- Booking URLs are validated and can be copied from the profile without adding a cross-platform browser-launch dependency.

## Important source files

- `lib/main.dart` — app shell, navigation, and Explore cards.
- `lib/screens/barber_results_screen.dart` — prototype and verified discovery.
- `lib/screens/firstvue_business_profile_screen.dart` — verified profile, gallery, and reviews.
- `lib/screens/my_businesses_screen.dart` — owner profile and media editor.
- `lib/screens/profile_screen.dart` — account, owner, and admin navigation.
- `lib/screens/rentals_screen.dart` — rental discovery, posting, media, and inquiries.
- `lib/screens/admin_rentals_screen.dart` — rental moderation.
- `lib/screens/admin_business_submissions_screen.dart` — business moderation.
- `lib/screens/admin_business_reviews_screen.dart` — review moderation.
- `lib/services/business_media_service.dart` — business image Storage and records.
- `lib/services/business_reviews_service.dart` — review reads, submission, and moderation.
- `lib/services/business_submission_service.dart` — business owner/admin workflow.
- `lib/services/approved_businesses_service.dart` — approved business discovery/details.
- `lib/services/rentals_store.dart` — rentals, media, inquiries, and admin checks.

## Verification state

Latest static verification:

```text
dart analyze lib test
No issues found!
```

The obsolete generated counter test was replaced with a FIRSTVUE home-screen smoke test in `test/widget_test.dart`. The user subsequently reported:

```text
All tests passed!
```

## Known limitations and recommended next work

The original handoff's three main unfinished features—business gallery UI, reviews UI/moderation, and Explore imagery—are now implemented.

Current priority: finish configuring the non-barber Explore categories and their complete workflows before final account-based QA:

1. ~~Salons and suites.~~ Completed: category-aware location discovery, approved-business filtering, search/location filters, salon-specific symbols, and clearly labeled fictional prototype locations.
2. ~~Stylists.~~ Completed at the prototype level as individual-professional discovery. A future professional/provider schema is required before live verified stylist accounts can appear.
3. ~~Beauty providers.~~ Completed as a people-versus-places gateway: individual beauty professionals remain fictional prototypes, while beauty studios/spas/suites use location discovery and approved-business filtering.
4. ~~Barbershops and suites.~~ Completed: separate location discovery with approved-business filtering and fictional prototype locations.
5. Any other Explore categories or category-specific screens that are still placeholders.

Discovery taxonomy rule:

- Barbers and stylists are individual professionals. Do not treat them as businesses or physical locations.
- Barbershops, barber suites, salons, and salon suites are business locations.
- The current database supports approved business locations but has no individual professional/provider table. Until that schema exists, individual barber and stylist results must remain clearly labeled fictional prototypes and must never receive FIRSTVUE verified-business treatment.

After those categories are finalized, perform a manual end-to-end QA pass against the configured Supabase project. Create dedicated test accounts using email aliases from an inbox the user controls; do not register invented Gmail addresses that may belong to other people.

1. Sign in as a business owner.
2. Upload and delete business photos.
3. Confirm photos appear on an approved verified profile.
4. Sign in as a customer and submit a review.
5. Sign in as an admin and approve/reject the review.
6. Confirm only approved reviews affect the displayed count and average.
7. Inspect all Explore cards at narrow and wide browser sizes.

Account QA is intentionally deferred until the category work above is complete. The attempted fictional Gmail credentials were not registered and must not be reused.

After QA, prioritize product decisions rather than adding unverified provider data:

- Decide whether approved business media/reviews should be visible while signed out; if yes, add narrowly scoped `anon` RLS and Storage read policies.
- Decide how rejected reviewers can revise/resubmit, because the current unique `(business_id, reviewer_id)` constraint plus pending-only update policy makes rejection terminal.
- Add automated service/widget tests using a mock or local Supabase test strategy.
- Improve error reporting so raw backend error details are not shown to end users.
- Add pagination for media, reviews, and administrator queues before production scale.
- Consider moving review aggregates to a secure database view/RPC as volume increases.

## External provider rule

No external places/provider API is integrated. Do not scrape Google Maps or Apple Maps. Before adding provider data, verify official API terms, attribution, caching, photo/review licensing, commercial-use restrictions, and privacy requirements.

## Professional social showcase and catalog

The professional profile editor now supports social profile links, selected social-post links with optional captions, and catalog items with title, description, price label, and optional image URL. Approved public professional profiles display all three showcase sections.

Apply `supabase/migrations/20260811_professional_showcase.sql` in the Supabase SQL Editor before testing this feature. Its RLS policies allow owners to manage their own link-based showcase records and allow public reads only for approved professional profiles.

Direct social-account connection is intentionally marked as coming later. Implement it only through each platform's official OAuth/API flow, with tokens stored server-side (for example in a secured Edge Function integration), never in Flutter or the public showcase tables. The current implementation does not scrape or copy social-platform content; professionals choose the post links and captions they want to feature.

## Repository note

The working directory did not expose usable Git repository metadata during the prior session, so no reliable Git diff or commit history was available. Preserve the complete project directory when transferring this handoff.
