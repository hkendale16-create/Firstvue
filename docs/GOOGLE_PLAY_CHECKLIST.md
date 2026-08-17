# Google Play — FirstVue personal developer account checklist

Path for a **personal** Google Play developer account publishing `com.FirstVue`.

**Post-approval walkthrough:** `docs/GOOGLE_CONSOLE_SETUP.md` (Play app creation + Google Cloud OAuth + signing order).

| Milestone | Status |
|-----------|--------|
| Developer account approved | **Yes** (operator confirmed) |
| App created in Play Console | **Yes** |
| Signed AAB on Internal testing | **Yes** (versionCode `3` live; next upload `4` / `1.0.3`) |

---

## 1. Build and signing

- [ ] Install Flutter SDK and run `flutter pub get` from the repo root.
- [ ] Confirm `android/app/build.gradle.kts` uses `applicationId = "com.FirstVue"` and namespace `com.FirstVue`.
- [ ] Generate an **upload keystore locally** (never commit it):

  ```bash
  keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA \
    -keysize 2048 -validity 10000 -alias upload
  ```

- [ ] Copy `android/key.properties.example` → `android/key.properties` and fill in paths/passwords.
- [ ] Release builds **must** sign with `key.properties` (not debug keys). `key.properties` and `*.jks` / `*.keystore` are gitignored.
- [ ] Build the bundle:

  ```bash
  flutter build appbundle --release
  ```

  Output: `build/app/outputs/bundle/release/app-release.aab`

---

## 2. Target API level

- [ ] **API 36** — Flutter’s default `compileSdk` / `targetSdk` already track the current Play requirement. Re-check after Flutter SDK upgrades before each submission.

---

## 3. Testing tracks (personal account)

Google requires new personal accounts to run a closed test before production.

1. **Internal testing** — upload the first `.aab`, add yourself (and core team) as internal testers, smoke-test install/login/deep links.
2. **Closed testing** — promote the same or newer build to a closed track.
3. **12 testers opted-in for 14 consecutive days** — personal accounts must meet this before applying for production access.
4. After the closed-test gate, promote to **Production** (or Open testing if desired).

---

## 4. Store listing assets

Prepare in Play Console → Main store listing:

| Asset | Notes |
|-------|--------|
| App name | **FirstVue** |
| Short description | ≤ 80 chars |
| Full description | Features, communities, businesses, messaging |
| App icon | 512×512 PNG — `store-listing/play-icon-512.png` |
| Feature graphic | 1024×500 |
| Phone screenshots | At least 2 (recommend 6.7" and standard phone) |
| Tablet screenshots | If tablet layout is supported |
| Category | Social or Lifestyle (pick best fit) |

---

## 5. Privacy policy and support

- [ ] **Privacy policy URL** on your **custom domain** (e.g. `https://firstvue.app/privacy` or dedicated path). Play requires a publicly reachable HTTPS URL — not only in-app text.
- [x] **Support email** for store listing / privacy: `hkendale16@gmail.com` (change here if you prefer a different address).
- [ ] In-app legal copy: Profile → Legal (already linked in the Flutter app).
- [ ] Demo seed accounts (`fvdemo_*`) remain until **10 real users** sign up (auto-purge via `fv_maybe_purge_demo_pack`); auth UI hides demo credentials after purge. Manual purge: `APPLY_DEMO_PURGE.sql`.

---

## 6. Data safety form (FirstVue)

Declare what the app collects/processes. Align answers with the live app and Supabase backend.

| Category | FirstVue usage |
|----------|----------------|
| **Account info** | Email, username, display name, profile fields (signup / profile settings) |
| **User-generated content** | Posts, comments, reviews, business listings, community content |
| **Photos and videos** | Profile, business, and community media uploads |
| **Messages** | Direct messaging and community threads |
| **Location (approximate)** | Coarse location to sort nearby businesses (`ACCESS_COARSE_LOCATION`; fine location permission declared for future/nearby precision) |
| **Device or other IDs** | Only if analytics/FCM SDKs are added later — declare when integrated |
| **Payments** | **Not used yet** — Stripe checkout is not shipped in the mobile prototype; mark “No” for in-app purchases until enabled |
| **Ads** | **No ads** |

Also declare:

- [ ] Data is encrypted in transit (HTTPS).
- [ ] Users can request account deletion (see §7).
- [ ] Whether data is shared with third parties (e.g. Supabase hosting, future email provider).

---

## 7. Account deletion

Play requires an in-app path to request account deletion (or a documented web flow).

- [x] **In-app account deletion** — Settings → Privacy → Delete account (SQL `delete_my_account`; Edge Function optional).
- [x] Blocks deletion while the user still owns businesses / sole hubs / rentals (must remove first).
- [x] Privacy policy documents in-app deletion + contact `hkendale16@gmail.com`.
- [ ] Hosted privacy URL live on custom domain (`/privacy.html` shipped in `web/`).

---

## 8. App content declarations

- [ ] **Ads:** No.
- [ ] **In-app purchases / payments:** Not enabled in prototype (`FeatureFlags.paymentsEnabled` off when present).
- [ ] **News / UGC:** Moderation and reporting flows — describe in questionnaire if prompted.
- [ ] **Target audience:** 13+ (messaging under-13 parental controls disabled for prototype).
- [ ] **COVID / health / government** declarations: N/A unless content changes.

---

## 9. Deep links and Android App Links

- [ ] Intent filters already declare `https://firstvue.app` and `firstvue://` in `AndroidManifest.xml`.
- [ ] Host **Digital Asset Links** at:

  ```
  https://firstvue.app/.well-known/assetlinks.json
  ```

  Include the release signing certificate SHA-256 fingerprint and package name `com.FirstVue`.

  ```bash
  keytool -list -v -keystore ~/upload-keystore.jks -alias upload
  ```

- [ ] Verify with [Statement List Generator and Tester](https://developers.google.com/digital-asset-links/tools/generator) before relying on auto-verify.

---

## 10. Pre-submit smoke test

- [ ] Cold start, sign up, sign in (email + username login).
- [ ] Feed load, profile view, business deep link from `https://firstvue.app/?business=…`.
- [ ] Photo upload, messaging send/receive.
- [ ] Location permission prompt and nearby sort.
- [ ] Push notification permission (Android 13+).
- [ ] Sign out and reinstall from Play internal track.

---

## 11. Supabase / backend (release hygiene)

- [x] Apply prototype readiness SQL (`APPLY_PROTOTYPE_READINESS.sql`).
- [x] Apply Play prep SQL (`APPLY_PLAY_PREP.sql`) — account blockers + DEFINER grants.
- [x] Apply account self-delete SQL (`APPLY_ACCOUNT_SELF_DELETE.sql`).
- [ ] Enable **leaked password protection** in Supabase Auth dashboard (confirm in UI).
- [ ] Confirm production Supabase URL/anon key in release build config (no service-role key in the client).
- [ ] Optional: deploy Edge Function `delete-account` (SQL path already works without it).

---

## Quick reference

| Item | Value |
|------|--------|
| Package / application ID | `com.FirstVue` |
| Display name | FIRSTVUE |
| Deep link host | `firstvue.app` |
| Signing config | `android/key.properties` (from example template) |
| Closed test gate (personal) | 12 testers × 14 days |
