# App Store / TestFlight — FirstVue (Windows)

You **cannot** build an App Store `.ipa` on Windows (or Linux). Apple only lets **macOS + Xcode** compile iOS. From Windows, a cloud Mac does that for you.

Use **Codemagic** in the browser. This repo already has `codemagic.yaml`.

| Field | Value |
|-------|--------|
| Bundle ID | `com.FirstVue` |
| Display name | FIRSTVUE |
| Version | `1.0.8` |
| Build | `9` |
| Support email | `hkendale16@gmail.com` |
| Privacy | `https://firstvue.app/privacy.html` |
| Marketing URL | `https://firstvue.app` |

---

## Windows path (no Mac)

### A. Apple Developer (browser)

1. Enroll at [developer.apple.com](https://developer.apple.com) with `hkendale16@gmail.com` (paid Apple Developer Program).
2. [Identifiers](https://developer.apple.com/account/resources/identifiers/list) → **+** → App IDs → App  
   - Description: FirstVue  
   - Bundle ID: **Explicit** → `com.FirstVue`
3. [App Store Connect](https://appstoreconnect.apple.com) → **My Apps** → **+** → New App  
   - Platform: iOS  
   - Name: **FirstVue**  
   - Language: English (U.S.)  
   - Bundle ID: `com.FirstVue`  
   - SKU: `firstvue001`

### B. App Store Connect API key (lets Codemagic upload)

1. App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API**
2. **Generate API Key**
   - Name: `FirstVue`
   - Access: **App Manager**
3. Download the `.p8` file (Apple shows it **once**). Copy **Issuer ID** and **Key ID**.

### C. Codemagic (this is the Mac that builds the IPA)

1. Open [codemagic.io](https://codemagic.io) → sign in with **GitHub** → add `hkendale16-create/Firstvue`.
2. Teams → **Integrations** → **App Store Connect** → add the API key.  
   Name the integration **FirstVue** (must match `codemagic.yaml`).
3. Teams → **Code signing identities** → iOS → fetch/create certificates for `com.FirstVue` (App Store distribution). Codemagic can create the certs so you never need Keychain on a Mac.
4. Open the app, pick branch **`main`**, click **Check for configuration file**.
5. Switch the page from **Workflow Editor** to **codemagic.yaml**.
6. **Start new build** → workflow **iOS App Store 1.0.8** (this screen has no Shorebird field).
7. When it finishes, the `.ipa` is already uploaded to **TestFlight**.

If Codemagic says **Shorebird token is required**, cancel that Start dialog. You are on the Flutter **Workflow Editor**, not the yaml workflow. FirstVue does **not** use Shorebird. A Shorebird token will not help — that mode runs `shorebird release` and this repo has no `shorebird.yaml`.

**Fix (do this instead of pasting a token):**

1. [codemagic.io/apps](https://codemagic.io/apps) → **Firstvue**
2. Branch dropdown → `main`
3. **Check for configuration file** (docs: [scan for yaml](https://docs.codemagic.io/yaml-quick-start/building-a-flutter-app/))
4. Top of the page: **codemagic.yaml** (leave Workflow Editor)
5. Start **iOS App Store 1.0.8**

If you are stuck in Workflow Editor: scroll to **Publish updates to user devices using Shorebird** and set it to **disabled** (not Release, not Patch). Save. Then the token field goes away.

Do not create a Shorebird account for this TestFlight upload.

If Codemagic says **No matching profiles found for bundle identifier "com.FirstVue" and distribution type "app_store"**, the yaml workflow is running, but Codemagic has no **App Store** provisioning profile for `com.FirstVue`. Create the Apple files once (Windows browser, no Mac), then fetch them into Codemagic.

1. Create the App ID: [Identifiers](https://developer.apple.com/account/resources/identifiers/add/bundleId) → App → Explicit → `com.FirstVue` → Register. Skip if it already exists: [Identifiers list](https://developer.apple.com/account/resources/identifiers/list).
2. In Codemagic: [Teams → Code signing identities](https://codemagic.io/teams) → **iOS certificates** → **Generate certificate** → type **Apple Distribution** → API key **FirstVue** → Create. [Signing docs](https://docs.codemagic.io/yaml-code-signing/signing-ios/)
3. Create the profile: [Profiles → +](https://developer.apple.com/account/resources/profiles/add) → **App Store Connect** → **App Store** → App ID `com.FirstVue` → select the Distribution certificate from step 2 → name `FirstVue App Store` → Generate.
4. Back in Codemagic → **iOS provisioning profiles** → **Fetch profiles** → under **App Store profiles** select `com.FirstVue` → reference name `firstvue_app_store` → Download selected.
5. Confirm the profile row shows bundle `com.FirstVue`, type App Store, and a green check on the certificate.
6. Re-run workflow **iOS App Store 1.0.8**.

If **Build App Store IPA** fails with **Unable to get scheme file for Runner**, that filename bug is already on `main`. Start a **new** build of **`main`**. The IPA step must **not** fetch `mapbox-maps-ios.git`.

If the IPA **builds** but **Publishing failed** (`Failed to upload archive`, `401`, `NOT_AUTHORIZED`, or `Cannot determine the Apple ID from Bundle ID 'com.FirstVue'`), the `.ipa` is already on that Codemagic run (Artifacts → `FIRSTVUE.ipa`). Two separate problems:

**A. API key** — Apple rejected the token. Delete the Codemagic **FirstVue** integration and add it again (you cannot edit). App Manager `.p8` + matching Key ID + Issuer ID.

**B. Mapbox vs uploader** — Mapbox needs **Xcode 26**. Xcode 26’s `altool` then fails with `ITunesConnectionAuthenticationErrorDomain -26000`. The workflow compiles with Xcode 26 and uploads with **iTMSTransporter** (not altool). Build branch **`cursor/codemagic-asc-auth-4635`**. Do not retry a run whose publish log says `Running altool`.

1. Confirm the app exists: [App Store Connect → My Apps](https://appstoreconnect.apple.com/apps) → **FirstVue**, bundle **`com.FirstVue`**. Create it if missing.
2. Open [App Store Connect API keys](https://appstoreconnect.apple.com/access/integrations/api). If the old key is revoked or you are unsure, **Generate API Key**:
   - Name: `FirstVue`
   - Access: **App Manager** (Developer is not enough to upload)
3. Download the `.p8` (Apple shows it **once**). Copy **Issuer ID** (above the table) and this key’s **Key ID**.
4. In Codemagic do **not** use `codemagic.io/teams` (404). Open [codemagic.io/apps](https://codemagic.io/apps) → left nav **Personal account** → **Integrations** → **Developer Portal**.
5. Edit the key named exactly **`FirstVue`** (must match `codemagic.yaml`). Paste the new Issuer ID + Key ID and upload the new `.p8`. Save. Do not mix a Key ID from one key with a `.p8` from another.
6. Start a **new** workflow **iOS App Store 1.0.8** on **`main`**.

### D. Install on iPhone

1. App Store Connect → **TestFlight** → add `hkendale16@gmail.com` as an internal tester.
2. On iPhone, install **TestFlight**, accept the invite, install FirstVue.

### E. Store listing (still in the browser)

Fill name, screenshots, privacy, then **Submit for Review** when you are ready. Do **not** set Codemagic to submit to the App Store until the listing is complete.

**What’s New (paste):**
```
VUE photos and videos open in a full-screen reel.
Swipe, like, comment, share, and save without leaving the viewer.
Business Tools tabs and Settings / Home fixes.
```

---

## Listing (paste-ready)

**Name:** FirstVue  

**Subtitle (≤30 chars):** See first. Book first.

**Description:**
```
FirstVue helps you discover trusted local businesses, professionals, communities, and events.

SEE FIRST. BOOK FIRST.

• Explore nearby businesses and professionals
• Watch VUE moments and community posts
• Follow creators and entities you care about
• Message securely inside FirstVue
• Join groups and communities
• Find and RSVP to local events
• Switch between personal and business identities

FirstVue is for users 13 and older. Payments are not enabled in this trial build.
```

**Keywords:** beauty,local,business,community,messaging,events,professionals,booking  

**Support URL:** `https://firstvue.app`  
**Privacy Policy URL:** `https://firstvue.app/privacy.html`  
**Category:** Lifestyle (or Social Networking)  
**Age rating:** 13+  

**App Privacy:** collect email, name, user content, photos/videos, messages, coarse location — for app functionality / account. Not sold. See `docs/DATA_SAFETY.md`.

---

## Assets you still need

- 1024×1024 App Store icon (no alpha)
- iPhone screenshots (6.7" and/or 6.5") — at least 1 set

---

## If you later have a Mac

```bash
git clone https://github.com/hkendale16-create/Firstvue.git
cd Firstvue
git checkout main
./scripts/build-ios-ipa.sh
```

Then upload `build/ios/ipa/FirstVue-1.0.8+9.ipa` with **Transporter**.

Replace `TEAMID` in `web/.well-known/apple-app-site-association` with your Apple Team ID after you create the App ID.
