# FirstVue 1.0.8 (build 9) — App Store / TestFlight

From **Windows**, do not try to build an `.ipa` locally. Use Codemagic (cloud Mac):

1. Follow `docs/APP_STORE_UPLOAD.md` (Windows path).
2. Start Codemagic workflow **iOS App Store 1.0.8** on **`cursor/codemagic-asc-auth-4635`** until that branch is merged (it pins Xcode 16.4 so Apple’s uploader works).
3. If publishing fails with `Failed to upload archive` / `401`, the IPA already built. See `docs/APP_STORE_UPLOAD.md`.
4. Install from TestFlight on iPhone.

| Field | Value |
|-------|--------|
| Bundle ID | `com.FirstVue` |
| Display name | FIRSTVUE |
| version | `1.0.8` |
| build | `9` |
| Support email | `hkendale16@gmail.com` |
| Privacy | `https://firstvue.app/privacy.html` |

## What’s New (paste in App Store Connect)

```
VUE photos and videos open in a full-screen reel.
Swipe, like, comment, share, and save without leaving the viewer.
Business Tools tabs and Settings / Home fixes.
```
