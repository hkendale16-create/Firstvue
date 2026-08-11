# FirstVue — Full Build Log & Launch Checklist

Last updated: August 11, 2026

Project path:

`C:\Users\User1\Documents\Codex\2026-08-10\now-inspect-the-existing-firstvue-repository-2\firstvue`

---

## Part 1 — Work completed (start to finish)

### Phase 0 — Project handoff & environment (Aug 10, 2026)

| Step | What was done | Status |
|------|---------------|--------|
| 0.1 | Inspected existing Flutter + Supabase MVP | Done |
| 0.2 | Confirmed Flutter 3.44.9 / Dart 3.12.2 on `C:\Users\User1\develop\flutter\bin\flutter.bat` | Done |
| 0.3 | Documented palette, typography, and product rules in `FIRSTVUE_EXPORT_HANDOFF.md` | Done |
| 0.4 | Confirmed Supabase init in `lib/main.dart` + `lib/config/supabase_config.dart` (anon key only) | Done |

**Issues encountered**

- Multiple Flutter/Dart installs on PATH — full path to `flutter.bat` required to avoid version conflicts.
- Stale `dart` / `dartvm` / `dartaotruntime` processes can block Flutter wrapper commands; close them before retrying.
- Git metadata was not available in the working directory during early sessions.

---

### Phase 1 — Core MVP (Aug 10, 2026)

| Step | What was done | Status |
|------|---------------|--------|
| 1.1 | Dark editorial theme (`lib/theme/firstvue_theme.dart`) — Cormorant Garamond + Space Grotesk | Done |
| 1.2 | Home shell + bottom navigation | Done |
| 1.3 | Supabase email/password auth + profile upsert | Done |
| 1.4 | Explore discovery categories (barbers, stylists, salons, beauty, barbershops, rentals) | Done |
| 1.5 | Prototype vs FIRSTVUE VERIFIED business separation in discovery | Done |
| 1.6 | Business owner submission workflow (pending → admin approval) | Done |
| 1.7 | Owner business profile editor (description, address, services) | Done |
| 1.8 | Rental posting, media upload, inquiries, admin approval | Done |
| 1.9 | Business media gallery (owner upload/delete, verified profile display) | Done |
| 1.10 | Customer reviews (pending insert, approved display, one per user/business) | Done |
| 1.11 | Admin moderation screens (businesses, rentals, reviews) | Done |
| 1.12 | Applied Supabase migrations through Aug 10 batch (see migration list below) | Done (per user report) |

**Issues encountered**

- Business media and reviews require authenticated reads; signed-out visitors cannot load private bucket images unless anon policies are added later.
- Rejected reviews are terminal under current unique constraint + pending-only update policy.

---

### Phase 2 — Professional profiles (Aug 11, 2026)

| Step | What was done | Status |
|------|---------------|--------|
| 2.1 | `20260811_professional_profiles.sql` — person-based provider model | Done (migration applied per user) |
| 2.2 | Professional profile editor, admin approval queue, public profile screen | Done |
| 2.3 | Portfolio images, availability status, booking URL validation | Done in code |
| 2.4 | `20260811_professional_media_availability.sql` | **Must be applied in Supabase** |
| 2.5 | Social showcase + catalog (`20260811_professional_showcase.sql`) | **Must be applied in Supabase** |

---

### Phase 3 — Home screen visual redesign (Aug 11, 2026)

| Step | What was done | Status |
|------|---------------|--------|
| 3.1 | Matched reference mockup: centered FIRSTVUE header, champagne gold styling | Done |
| 3.2 | Generated coordinated explore card artwork (warm editorial, 6 portraits) | Done |
| 3.3 | Copied images from `.codex\generated_images\019fef92-dc3d-7e32-afb0-58187891663a` → `assets/images/` | Done |
| 3.4 | 2-column portrait explore grid on mobile | Done |
| 3.5 | Bottom nav: Home / Search / Saved / Profile with gold active states | Done (later expanded to 5 tabs — see Phase 4) |

**Issues encountered**

- User-provided generated-images folder path was missing trailing `a` (`...91663` vs `...91663a`).
- Prior Codex/FAC session froze during image generation; six images were already present in repo when work resumed.
- `assets/images/*.png` must stay in the project folder — do not rely on build cache alone.

---

### Phase 4 — Discovery, Vue feed, AI search, mobile polish (Aug 11, 2026)

| Step | What was done | Status |
|------|---------------|--------|
| 4.1 | Smaller homepage category tiles (`childAspectRatio` ~1.18 mobile, 1.05 desktop) | Done |
| 4.2 | Responsive grid: **4 columns at ≥900px**, 2 columns on mobile | Done |
| 4.3 | Added **Restaurants** category → `AiSearchScreen` | Done (reuses `explore_rentals.png` placeholder) |
| 4.4 | Added **All Nearby** category → `SearchScreen` | Done (reuses `explore_barbershops.png` placeholder) |
| 4.5 | **Trending Near You** section with larger horizontal card (168px) | Done (**static mock** — "District Barber Co.") |
| 4.6 | **See all** button → switches to Vue tab (`DiscoveryFeedScreen`) | Done |
| 4.7 | Homepage search → **Ask FirstVue AI** (`AiSearchScreen` + `SmartSearchService`) | Done |
| 4.8 | Vue feed tab with interactive cards | Done |
| 4.9 | Hexagonal engagement buttons (Like, Save, Share) | Done |
| 4.10 | Like/Save toggle states; Share copies text to clipboard | Done |
| 4.11 | `DiscoveryFeedService.recordEngagement()` → `feed_engagements` table | Done (auth + live items only) |
| 4.12 | Verified business premium emblem (`Icons.workspace_premium_rounded`) | Done |
| 4.13 | Business growth / monetization tiers screen | Done |
| 4.14 | Migrations added: `20260811_social_discovery_monetization.sql`, `20260811_ai_commerce_owner_connections.sql` | **Must be applied in Supabase** |

**Partial / not fully finished**

- Engagement labels show **Like / Save / Share**, not branded **Spark / Collection / Route**.
- Share copies descriptive text, not a real deep link URL.
- Vue feed mode tabs (For You / Nearby / Trending) do not filter data yet.
- Trending Near You card is prototype data, not live Supabase ranking.
- Restaurants and All Nearby need dedicated explore artwork (currently reuse other PNGs).

---

### Phase 5 — Build & verification (Aug 11, 2026)

| Step | What was done | Status |
|------|---------------|--------|
| 5.1 | `dart analyze lib test` | **No issues found** |
| 5.2 | `flutter test` (home smoke test) | **All tests passed** |
| 5.3 | `flutter build web` | **Succeeded** (Aug 11, 2026 — fresh build after mobile/Vue updates) |

**Issues encountered**

- **Flutter web compiler stalled twice** in prior FAC/Codex session — new source was not deployed online.
- Windows sandbox unavailable in some Cursor agent sessions; shell required `all` permissions.
- Web build takes ~45–75s; concurrent Flutter processes increase stall risk.
- `build/web/` is local only — **no hosting config exists yet** (no Firebase, Vercel, Netlify, or CI).

---

## Part 2 — Supabase migrations

### Reported applied (Aug 10–11)

1. `20260810_initial_firstvue_schema.sql`
2. `20260810_rental_media_storage.sql`
3. `20260810_rental_media_read_policy.sql`
4. `20260810_rental_admin_approval_policy.sql`
5. `20260810_rental_owner_inquiries_policy.sql`
6. `20260810_business_submissions.sql`
7. `20260810_business_admin_approval_policy.sql`
8. `20260810_owner_business_profile_policy.sql`
9. `20260810_business_services.sql`
10. `20260810_business_media_storage.sql`
11. `20260810_business_reviews.sql`
12. `20260811_professional_profiles.sql`

### Still need to be applied (required for full launch)

| Migration | Required for |
|-----------|--------------|
| `20260811_professional_media_availability.sql` | Professional portfolio, availability, booking URL |
| `20260811_professional_showcase.sql` | Social links, post links, catalog |
| `20260811_social_discovery_monetization.sql` | Vue feed, `feed_engagements`, promotions |
| `20260811_ai_commerce_owner_connections.sql` | AI search view, bookings, leads, subscriptions |

Apply each in the Supabase SQL Editor in filename order after the Aug 10 batch.

---

## Part 3 — Launch checklist (what still needs to be done)

### A. Immediate — get online

- [ ] **Deploy `build/web/`** to your FirstVue hosting URL (hosting provider not configured in repo).
- [ ] Configure SPA rewrites so all routes serve `index.html` (required for Flutter web).
- [ ] Set production Supabase URL + anon key in `lib/config/supabase_config.dart` (or build-time env injection).
- [ ] Apply the **4 pending migrations** listed above.
- [ ] Smoke-test deployed URL: home, Vue tab, AI search, sign-in, one business profile.

### B. Backend & data

- [ ] Run full **account-based QA** with real test accounts (owner, customer, admin) using email aliases you control.
- [ ] Seed at least 3–5 approved businesses across categories for live discovery (not prototypes).
- [ ] Wire **Trending Near You** to real Supabase data (`popularity_score`, distance, open status).
- [ ] Wire Vue feed **For You / Nearby / Trending** filters to backend ranking.
- [ ] Decide anon read policy for business media/reviews when signed out; add migrations if yes.
- [ ] Decide rejected-review resubmission UX; adjust DB constraint/policies if needed.

### C. Product polish

- [ ] Rename engagement labels to **Spark / Collection / Route** (or custom icons + labels).
- [ ] Share action should copy a **real business URL** (e.g. `https://yourdomain.com/business/{id}`).
- [ ] Generate dedicated explore images for **Restaurants** and **All Nearby**.
- [ ] Replace static **District Barber Co.** trending card with live data or clearly label as prototype.
- [ ] Notification bell (header) — implement or hide until ready.
- [ ] Pagination for media, reviews, admin queues, and Vue feed before scale.
- [ ] Improve user-facing error messages (hide raw Supabase errors).

### D. Professional & owner features

- [ ] QA professional profile create → pending → admin approve → public discovery flow.
- [ ] QA showcase (social links, post links, catalog) after showcase migration.
- [ ] Social OAuth connection (documented as "coming later" — official platform APIs only).
- [ ] Business growth / subscription tiers — connect to payment provider if monetizing at launch.

### E. Testing & CI

- [ ] Expand beyond single widget smoke test (`test/widget_test.dart`).
- [ ] Add service tests for `SmartSearchService`, `DiscoveryFeedService`, review/media services.
- [ ] Add GitHub Actions (or similar): `flutter analyze`, `flutter test`, `flutter build web`.
- [ ] Optional: golden/screenshot tests for home + Vue feed layouts.

### F. Legal, ops, and store readiness

- [ ] Privacy policy + terms of service (required for auth, location, analytics).
- [ ] App Store / Play Store assets if shipping native builds (currently web-first MVP).
- [ ] Custom domain + SSL for production hosting.
- [ ] Supabase backup strategy and RLS audit before public launch.
- [ ] Rate limiting / abuse protection on auth and review submission.
- [ ] Analytics dashboard for owners (feed engagements exist in DB; UI/reporting TBD).

### G. Known blockers & risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Flutter web build stalls | Deploy falls behind source | Close stale Dart processes; build with full flutter path; use `--no-wasm-dry-run` |
| Unapplied migrations | Vue feed / AI search fail at runtime | Apply all 4 pending SQL files before QA |
| Prototype data shown as real | Trust/reputation damage | Keep prototypes labeled; only show verified badge on approved records |
| No deployment pipeline | Manual, error-prone releases | Add CI + documented deploy script |
| Minimal test coverage | Regressions slip through | Expand tests before marketing launch |

---

## Part 4 — Deploy commands (when hosting is ready)

```powershell
cd "C:\Users\User1\Documents\Codex\2026-08-10\now-inspect-the-existing-firstvue-repository-2\firstvue"

# Close stale processes if build stalls
Get-Process dart,dartvm,dartaotruntime -ErrorAction SilentlyContinue | Stop-Process -Force

& "C:\Users\User1\develop\flutter\bin\flutter.bat" pub get
& "C:\Users\User1\develop\flutter\bin\flutter.bat" analyze lib test
& "C:\Users\User1\develop\flutter\bin\flutter.bat" test
& "C:\Users\User1\develop\flutter\bin\flutter.bat" build web --no-wasm-dry-run

# Output ready to upload:
# build\web\
```

Upload the entire `build/web/` folder to your host, or connect the repo to Vercel/Netlify/Firebase Hosting with `build/web` as the publish directory.

---

## Part 5 — Key source files

| Area | File |
|------|------|
| Home + explore grid + trending | `lib/main.dart` |
| Vue feed + hex engagement | `lib/screens/discovery_feed_screen.dart` |
| AI search | `lib/screens/ai_search_screen.dart`, `lib/services/smart_search_service.dart` |
| Feed analytics | `lib/services/discovery_feed_service.dart` |
| Verified profiles | `lib/screens/firstvue_business_profile_screen.dart` |
| Admin tools | `lib/screens/profile_screen.dart` + admin screens |
| Theme | `lib/theme/firstvue_theme.dart` |
| Migrations | `supabase/migrations/*.sql` (16 files) |
| Tests | `test/widget_test.dart` |
| Web output | `build/web/` |

---

## Part 6 — Recommended next step (priority order)

1. ~~**Apply 4 pending Supabase migrations**~~ — combined script ready: `supabase/apply_pending_migrations.sql` + `supabase/APPLY_MIGRATIONS.md` (**you run this in Supabase Dashboard**)
2. ~~**Deploy fresh `build/web/`**~~ — deploy configs added (`netlify.toml`, `firebase.json`, `scripts/build-web.ps1`); **upload `build/web/` to your host**
3. **End-to-end QA** — checklist ready: `FIRSTVUE_QA_CHECKLIST.md` (**manual — requires your test accounts**)
4. ~~**Replace prototype trending + share URLs**~~ — live trending from Supabase; share copies `https://domain/?business={id}`; Spark/Collection/Route labels
5. ~~**Add CI**~~ — `.github/workflows/flutter_ci.yml` (requires git remote + GitHub repo)

### Aug 11, 2026 session — items 1–5 progress

| # | Task | Status | Notes |
|---|------|--------|-------|
| 1 | Migrations | **Ready to apply** | Cannot run from IDE without DB credentials; use SQL Editor |
| 2 | Deploy | **Build ready** | Fresh `build/web/` compiled; no hosting URL in repo |
| 3 | QA | **Checklist created** | Automated smoke test passes; manual QA pending |
| 4 | Live trending + share | **Done in code** | Removed District Barber Co. mock |
| 5 | CI | **Done in repo** | GitHub Actions workflow added; repo not yet initialized as git |
