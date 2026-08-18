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
4. Start build → workflow **iOS App Store 1.0.8**.
5. When it finishes, the `.ipa` is already uploaded to **TestFlight**.

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
git checkout cursor/store-release-1-0-8-4635
./scripts/build-ios-ipa.sh
```

Then upload `build/ios/ipa/FirstVue-1.0.8+9.ipa` with **Transporter**.

Replace `TEAMID` in `web/.well-known/apple-app-site-association` with your Apple Team ID after you create the App ID.
