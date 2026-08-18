# Google Console setup — FirstVue (post-approval)

You are approved. Use this as the click-path for **Google Play Console** (publish Android) and **Google Cloud Console** (OAuth / Google Sign-In). Values below match the repo.

| Item | Value |
|------|--------|
| Package / application ID | `com.FirstVue` |
| Display name | FIRSTVUE / FirstVue |
| Support email | `hkendale16@gmail.com` |
| Website | `https://firstvue.app` |
| Privacy policy | `https://firstvue.app/privacy.html` |
| Supabase Auth callback | `https://sdssshegqdwobjelxzkp.supabase.co/auth/v1/callback` |
| Web Google Client ID | `232279155211-ilegqngbve9fr34o5ajjq7396c48n877.apps.googleusercontent.com` |
| Web hosts | `https://firstvue.app`, `https://www.firstvue.app`, `https://firstvapp.netlify.app` |

Related worksheets (paste from these):

- Store listing copy → `docs/STORE_LISTING_DRAFT.md`
- Data safety answers → `docs/DATA_SAFETY.md`
- Full Play gate checklist → `docs/GOOGLE_PLAY_CHECKLIST.md`

---

## Part A — Google Play Console (create the app)

Open [Google Play Console](https://play.google.com/console).

### A1. Create the app

1. **All apps** → **Create app**
2. App name: **FirstVue**
3. Default language: English (United States)
4. App or game: **App**
5. Free or paid: **Free**
6. Accept declarations → **Create app**

### A2. Dashboard checklist (complete in any order)

Play shows a left-nav / dashboard list. Fill these with FirstVue answers:

| Play item | FirstVue answer |
|-----------|-----------------|
| **App access** | All or some features require sign-in (email or Google). Provide a demo tester account if you keep `fvdemo_*` seeds, or create a dedicated tester user. |
| **Ads** | **No** |
| **Content ratings** | Complete IARC questionnaire; target **13+** social / UGC |
| **Target audience** | **13 and older** (not primarily children) |
| **News app** | No (unless you later claim news) |
| **COVID-19 contact tracing / status** | No |
| **Data safety** | Use `docs/DATA_SAFETY.md` — Yes collect data; encrypted in transit; account deletion available |
| **Government apps** | No |
| **Financial features** | No (payments disabled in trial) |
| **Health** | No |

### A3. Store listing

Open **FirstVue** → **Dashboard** → **Set up your app** → **Set up your store listing**.

Or left menu: **Grow users** → **Store listings** (may still say **Store presence → Main store listing**).

Paste copy from `docs/STORE_LISTING_DRAFT.md`. Scroll to **Graphics** for the app icon — this is not on the Internal testing page.

- Short description ≤ 80 chars  
- Full description  
- App icon **512×512** PNG — use `store-listing/play-icon-512.png` (VUE-tab V)  
- Feature graphic **1024×500**  
- Phone screenshots (minimum 2)  
- Category: **Lifestyle** or **Social**  
- Contact email: `hkendale16@gmail.com`  
- Privacy policy URL: `https://firstvue.app/privacy.html` (must load over HTTPS)

### A4. Testing tracks (personal account)

Personal developer accounts must run closed testing before production:

1. Build a signed AAB locally (Part C).
2. **Testing → Internal testing** → create release → upload `app-release.aab` → add yourself as tester → install from the opt-in link.
3. Promote to **Closed testing** when internal smoke tests pass.
4. Recruit **12 opted-in testers for 14 consecutive days**, then apply for production.

Do **not** skip straight to Production on a new personal account.

### A5. App signing

On first upload, choose **Play App Signing** (Google-managed app signing key). Keep your **upload keystore** backed up offline — never commit it.

---

## Part B — Google Cloud Console (OAuth / Sign-In)

Open [Google Cloud Console](https://console.cloud.google.com/) → the project that owns Client ID  
`232279155211-ilegqngbve9fr34o5ajjq7396c48n877.apps.googleusercontent.com`.

Also useful: [Google Auth Platform → Clients](https://console.cloud.google.com/auth/clients).

### B1. Sync Client Secret into Supabase (required for OAuth redirect)

Web Google Sign-In primarily uses **ID tokens**, but the OAuth redirect fallback still needs a matching secret.

1. Auth Platform → **Clients** → open the **Web** client above  
2. Copy **Client ID** and **Client secret**  
3. Supabase → [Authentication → Providers → Google](https://supabase.com/dashboard/project/sdssshegqdwobjelxzkp/auth/providers)  
4. Enable Google → paste Client ID + Secret → **Save**

If Auth logs show `invalid_client`, the secret in Supabase is stale — re-copy from Google and save again.

### B2. Authorized origins and redirect

On the **Web** OAuth client:

**Authorized JavaScript origins**

- `https://firstvue.app`
- `https://www.firstvue.app`
- `https://firstvapp.netlify.app`
- `http://localhost:*` only if you develop locally (optional)

**Authorized redirect URIs**

- `https://sdssshegqdwobjelxzkp.supabase.co/auth/v1/callback`

### B3. Android OAuth client (native / Play builds)

Create an **Android** OAuth client (same Google Cloud project):

| Field | Value |
|-------|--------|
| Application type | Android |
| Name | FirstVue Android |
| Package name | `com.FirstVue` |
| SHA-1 | From your **upload** keystore (and debug keystore for local debug builds) |

Print fingerprints after you create the keystore (Part C):

```bash
./scripts/print_android_signing_fingerprints.sh ~/upload-keystore.jks upload
```

Add both **SHA-1** (Google Cloud Android client) and later **SHA-256** (Digital Asset Links).

### B4. OAuth consent screen

- User type: **External** (unless using a Workspace-only Internal app)  
- App name: FirstVue  
- Support email: `hkendale16@gmail.com`  
- App domain / privacy: `https://firstvue.app` / `https://firstvue.app/privacy.html`  
- Scopes: email, profile, openid (default Google Sign-In)  
- While publishing status is **Testing**, add every tester email under **Test users**

---

## Part C — Local release signing (your machine)

Cloud agents cannot hold your upload keystore. Run once on your PC:

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias upload
```

```bash
cp android/key.properties.example android/key.properties
# Edit storePassword, keyPassword, storeFile (absolute path)
```

```bash
./scripts/print_android_signing_fingerprints.sh ~/upload-keystore.jks upload
```

Then:

```bash
flutter pub get
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab` → upload in Play **Internal testing**.

After you have the upload SHA-256:

1. Copy `web/.well-known/assetlinks.json.example` → `assetlinks.json`  
2. Replace `REPLACE_WITH_UPLOAD_KEYSTORE_SHA256`  
3. Deploy so `https://firstvue.app/.well-known/assetlinks.json` is public  

---

## Part D — Order of operations (recommended)

1. **B1–B2** — Google Client Secret → Supabase (unblocks Google Sign-In fallback)  
2. **A1–A3** — Create Play app + listing fields you can fill without the AAB  
3. **C** — Keystore + fingerprints + AAB  
4. **B3** — Android OAuth client with SHA-1  
5. **A4** — Upload AAB to Internal testing → smoke test  
6. Closed testing cohort (12 × 14 days) before Production  

---

## Smoke test after Internal track install

- Cold start, sign up / sign in (email + Google)  
- Feed, profile, messaging  
- Photo upload  
- Location permission + nearby sort  
- Deep link / App Link once `assetlinks.json` is live  
- Account deletion path: Settings → Privacy → Delete account  

---

## Status log

| Milestone | Status |
|-----------|--------|
| Play / Cloud Console access | **Approved** (operator confirmed) |
| Upload keystore + signed AAB | **Built** — latest `FirstVue-1.0.3+4-release.aab` (same upload key as `1.0.2+3`) |
| Fingerprints documented | **Yes** — `docs/ANDROID_UPLOAD_KEY_FINGERPRINTS.md` |
| Play app created | **Yes** (operator) |
| Store listing + Data safety | Pending operator (worksheets ready in repo) |
| Google Client Secret synced to Supabase | Pending operator |
| Android OAuth client (package + SHA-1) | Pending — use SHA-1 from fingerprints doc |
| Internal testing release live | **Yes** — was versionCode `3`; upload **`4`** next (`docs/PLAY_RELEASE_1.0.3.md`) |
| Closed test gate (12 × 14) | Not started |
| Production | Blocked on closed-test gate |
