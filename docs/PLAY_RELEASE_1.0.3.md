# FirstVue Play update — 1.0.3 (4)

Upload this release to **Google Play Console → Testing → Internal testing** (or Closed testing if you already promoted).

| Item | Value |
|------|--------|
| Package | `com.FirstVue` |
| versionName | `1.0.3` |
| versionCode | `4` (must be **greater than** live internal `3`) |
| AAB filename | `FirstVue-1.0.3+4-release.aab` |
| Signing | Same upload keystore as `1.0.2+3` (SHA-1 `49:D7:C2:…:A6:02`) |

## What’s new (paste into Play release notes)

```
• Smarter address search for businesses, pros, communities, groups & events
• Distance / travel time on business & professional profiles
• Richer Stories — photo, video, or text with overlays, captions & drafts
• Improved Newsfeed composer with drafts, links, location & edit after post
• Hashtag discovery — trending + Recent / Stories / Related
• Updated in-app tutorial (profiles + Light/Dark/System theme)
• Live map pins pulse with ripple effects
• Demo accounts auto-remove after 10 real signups
• Sounds & Haptics toggles in Settings
```

## Upload steps (Play Console)

1. Open [Play Console](https://play.google.com/console) → **FirstVue**.
2. **Testing → Internal testing → Create new release**.
3. Upload `FirstVue-1.0.3+4-release.aab`.
4. Paste the “What’s new” block above.
5. **Review release → Start rollout to Internal testing**.
6. Open the tester opt-in link on your Android device (same Google account as tester email `hkendale16@gmail.com`) and install/update.

## App icon (not on the testing page)

The AAB upload screen has **no** “Store presence” item. Leave **Test and release / Internal testing** and open the listing page:

**Easiest:** Dashboard → **Set up your app** → **Set up your store listing** (or **View tasks**). Scroll to **Graphics** → **App icon**.

**From the left menu:** click **FirstVue**, then **Grow users**. Expand it and open **Store listings** (newer name) or **Store presence → Main store listing**. Scroll to **Graphics**.

Upload `store-listing/play-icon-512.png` (512×512 gold **V**). Use a computer browser; the phone Play Console often hides that menu.

## Still required before Production

- Closed testing gate: **12 opted-in testers × 14 consecutive days** (personal account).
- Branded store assets (icon / feature graphic / screenshots) if not done.
- Live privacy URL: `https://firstvue.app/privacy.html`
- Android OAuth client with upload SHA-1 (if Google Sign-In on Android still pending).
- Google Web client secret synced into Supabase (if not already).
