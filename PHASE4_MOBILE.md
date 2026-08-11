# FirstVue Phase 4 — Mobile App (iOS + Android)

Same Flutter repo builds native apps for the App Store and Google Play.

---

## What was added in code

| Area | Change |
|------|--------|
| Bundle ID | `app.firstvue.mobile` |
| Display name | **FIRSTVUE** |
| Deep links | `firstvue://` + `https://firstvue.app/?business={id}` |
| `DeepLinkService` | Opens business profiles from shared links |
| Splash | Dark launch background `#0B0D10` |
| Packages | `app_links`, `http` |

---

## Build commands

Add Flutter to PATH first (or use full path):

```powershell
$env:Path = "C:\Users\User1\develop\flutter\bin;" + $env:Path
Set-Location "C:\Users\User1\Documents\Codex\2026-08-10\now-inspect-the-existing-firstvue-repository-2\firstvue"
flutter pub get
```

### Android

```powershell
flutter build apk --release
flutter build appbundle --release
```

Output: `build/app/outputs/`

### iOS (requires Mac + Xcode)

```bash
flutter build ios --release
```

Open `ios/Runner.xcworkspace` in Xcode → Archive → Upload to App Store Connect.

---

## Before store submission

### 1. App icon

Replace default launcher icons:

- Android: `android/app/src/main/res/mipmap-*`
- iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset`

Optional tool:

```yaml
# dev_dependencies in pubspec.yaml
flutter_launcher_icons: ^0.14.3

flutter_launcher_icons:
  android: true
  ios: true
  image_path: assets/images/app_icon.png
  adaptive_icon_background: "#0B0D10"
  adaptive_icon_foreground: assets/images/app_icon.png
```

Add a 1024×1024 PNG at `assets/images/app_icon.png`, then run `dart run flutter_launcher_icons`.

### 2. Signing

**Android:** Create upload keystore, configure `android/key.properties` + release signing in `build.gradle.kts` (currently uses debug keys).

**iOS:** Apple Developer account → Certificates + Provisioning Profiles in Xcode.

### 3. Deep link domain

Update `android/app/src/main/AndroidManifest.xml` HTTPS host from `firstvue.app` to your **Netlify domain** when ready.

Add **Apple App Site Association** file on your web host for Universal Links.

### 4. Store listings

Prepare:

- App name: **FirstVue**
- Subtitle: SEE FIRST. BOOK FIRST.
- Screenshots (6.7" iPhone + Android phone)
- Privacy policy URL (already in app Profile → Legal)
- Support email

### 5. Permissions copy (already in Info.plist)

- Location — sort nearby businesses
- Photo library — business/rental media uploads

---

## Test deep links

**Android:**

```powershell
adb shell am start -a android.intent.action.VIEW -d "firstvue:///?business=YOUR_BUSINESS_UUID"
```

**iOS Simulator:**

```bash
xcrun simctl openurl booted "firstvue:///?business=YOUR_BUSINESS_UUID"
```

---

## Shared backend

Mobile uses the same Supabase project:

- `lib/config/supabase_config.dart` — anon key only (safe in app)
- Auth, discovery, messaging, media — identical to web
- AWS media/email — optional Edge Functions (Phases 3 / 3B)

---

## Deployment order (recommended)

1. Web live on Netlify
2. Run Supabase migrations (Phases 1–3B as needed)
3. Test mobile against production Supabase
4. Submit to TestFlight / Play Internal Testing
5. **Stripe** — add-on later (`PHASE2_PAYMENTS.md`)

---

## Push code

```powershell
Set-Location "C:\Users\User1\Documents\Codex\2026-08-10\now-inspect-the-existing-firstvue-repository-2\firstvue"; git add .; git commit -m "Phase 3B AWS media and Phase 4 mobile prep"; git push
```
