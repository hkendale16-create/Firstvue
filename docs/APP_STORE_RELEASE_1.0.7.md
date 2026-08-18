# FirstVue 1.0.7 (build 8) — App Store / TestFlight

This Linux agent **cannot** produce a signed `.ipa`. Apple requires **macOS + Xcode** (or a Mac CI runner) and your Apple Distribution certificate.

This folder is the upload kit. On a Mac, one command builds the file Transporter expects.

| Field | Value |
|-------|--------|
| Bundle ID | `com.FirstVue` |
| Display name | FIRSTVUE |
| version (CFBundleShortVersionString) | `1.0.7` |
| build (CFBundleVersion) | `8` |
| Support email | `hkendale16@gmail.com` |
| Privacy | `https://firstvue.app/privacy.html` |

## Build the IPA on a Mac

```bash
git clone https://github.com/hkendale16-create/Firstvue.git
cd Firstvue
git checkout cursor/store-release-1-0-7-4635
./scripts/build-ios-ipa.sh
```

Output:

`build/ios/ipa/FirstVue-1.0.7+8.ipa`

Open **Transporter** (Mac App Store) → sign in with `hkendale16@gmail.com` → drop that `.ipa` → Deliver.

Or Xcode: open `ios/Runner.xcworkspace` → Any iOS Device → Product → Archive → Distribute App → App Store Connect.

## What’s New (paste in App Store Connect)

```
Business Tools now uses Claim, Add, and Rental tabs.
Settings search, Home post photos, and city / profile save fixes.
```

## Listing (if the app record is new)

See `docs/APP_STORE_UPLOAD.md` for name, description, keywords, and privacy answers.
