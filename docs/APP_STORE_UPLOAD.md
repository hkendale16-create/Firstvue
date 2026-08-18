# App Store / TestFlight — FirstVue upload guide

This Linux cloud agent **cannot** produce an `.ipa` (Apple requires macOS + Xcode).
Use this checklist on a Mac, then upload with Transporter or Xcode.

## Identifiers (match Android / Play)

| Field | Value |
|-------|--------|
| Bundle ID | `com.FirstVue` |
| Display name | FIRSTVUE |
| Version | `1.0.3` (from `pubspec.yaml`) |
| Build | `3` |
| Support email | `hkendale16@gmail.com` |
| Privacy | `https://firstvue.app/privacy.html` |
| Marketing URL | `https://firstvue.app` |

Replace `TEAMID` in `web/.well-known/apple-app-site-association` with your Apple Team ID after you create the App ID.

---

## 1. App Store Connect (browser)

1. Open [App Store Connect](https://appstoreconnect.apple.com) → **My Apps** → **+** → **New App**
2. Platforms: **iOS**
3. Name: **FirstVue**
4. Primary language: English (U.S.)
5. Bundle ID: select **com.FirstVue** (create it first in [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list) if missing)
6. SKU: `firstvue001`
7. User Access: Full Access

### Create Bundle ID (if needed)

Developer portal → Identifiers → **+** → App IDs → App  
- Description: FirstVue  
- Bundle ID: **Explicit** → `com.FirstVue`  
- Capabilities: Associated Domains (if using Universal Links), Push later if needed  

---

## 2. Build on a Mac (produces the upload file)

```bash
git clone https://github.com/hkendale16-create/Firstvue.git
cd Firstvue
git checkout cursor/google-console-setup-2f4a   # or main after merge
flutter pub get
cd ios && pod install && cd ..
flutter build ipa --release \
  --dart-define=FIRSTVUE_OAUTH_GOOGLE=true \
  --dart-define=FIRSTVUE_GOOGLE_WEB_CLIENT_ID=232279155211-ilegqngbve9fr34o5ajjq7396c48n877.apps.googleusercontent.com
```

Output (typical):

`build/ios/ipa/*.ipa`

Or in Xcode:

1. Open `ios/Runner.xcworkspace`
2. Select **Any iOS Device (arm64)**
3. Signing & Capabilities → Team = your Apple Developer team (auto-manage signing)
4. **Product → Archive** → **Distribute App** → **App Store Connect** → Upload

---

## 3. TestFlight

After processing finishes in App Store Connect → **TestFlight**:
1. Add yourself (`hkendale16@gmail.com`) as internal tester
2. Install **TestFlight** on iPhone
3. Accept invite → install FirstVue

---

## 4. App Store listing (paste-ready)

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

## 5. Assets you still need locally

- 1024×1024 App Store icon (no alpha)
- iPhone screenshots (6.7" and/or 6.5") — at least 1 set
- Optional iPad screenshots if you check iPad support

---

## Cannot do from this agent

- Build/sign `.ipa`
- Upload to App Store Connect without Apple credentials + Mac CI

If you have a Mac, run section 2 and upload. If you want CI builds later, provide Team ID + distribution cert + provisioning profile as secrets.
