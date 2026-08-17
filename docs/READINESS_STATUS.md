# FirstVue readiness snapshot — 2026-08-17

## FIRSTVUE STATUS

**READY FOR INTERNAL TEST** (code/backend Critical blockers for trial addressed)

**Google Play / Cloud Console:** operator confirmed **approved**. Follow `docs/GOOGLE_CONSOLE_SETUP.md` to create the Play app, sync the Google Client Secret into Supabase, generate the upload keystore, and upload the first AAB.

Not yet **READY FOR CLOSED TEST** until you: build a signed AAB, host privacy URL, add branded store assets, and recruit 12 testers.

Not **READY FOR PRODUCTION** until closed-test gate (12×14 days on personal account) completes.

---

## CRITICAL — resolved in this branch / live SQL

| Item | Status |
|------|--------|
| Profile PII RLS | Live repaired earlier |
| Parental self-claim | Locked live |
| Scoped profile-media reads | Live |
| Hashtag sync + reactions | Live |
| Account deletion | Live via `delete_my_account` |
| Stripe checkout hidden | Default off |
| DEFINER client grants tightened | Live |

## HIGH — remaining for humans

| Item | Action |
|------|--------|
| Release signing keystore | Create locally; never commit |
| Signed `.aab` | `flutter build appbundle --release` on your machine |
| Branded 512 icon + feature graphic + screenshots | Design assets |
| Hosted privacy URL | Deploy web (`/privacy.html`) on `firstvue.app` |
| Adaptive icon art | Replace Flutter default mipmaps with brand art |
| Closed testing cohort | 12 opted-in testers × 14 days |

## MEDIUM / LOW

- Edge Function `delete-account` optional (SQL works)
- `assetlinks.json` after keystore SHA-256 known
- Demo accounts kept until you purge later

---

## SUPABASE STATUS

| Item | Value |
|------|--------|
| Project health | Healthy |
| Services used | Auth, Postgres/RLS, Storage, Realtime (partial), RPCs, Edge (checkout/webhook) |
| Plan recommendation | Keep current for internal/closed trial; upgrade before open production if video egress grows |
| Upgrade required now | **No** |

---

## GOOGLE PLAY STATUS

| Check | Result |
|-------|--------|
| Developer account access | **PASS** (approved) |
| Android API 36 | **PASS** |
| applicationId `app.firstvue.mobile` | **PASS** |
| Console setup guide | **PASS** (`docs/GOOGLE_CONSOLE_SETUP.md`) |
| Release signing | **FAIL** until keystore |
| AAB generated | **FAIL** here (no Android SDK in cloud agent); build locally |
| Privacy policy page in repo | **PASS** (`web/privacy.html`) |
| Privacy URL live on domain | **FAIL** until you deploy domain |
| Data Safety worksheet | **PASS** (`docs/DATA_SAFETY.md`) |
| Store listing draft | **PASS** (`docs/STORE_LISTING_DRAFT.md`) |
| Store assets | **MISSING** |
| Account deletion | **PASS** |
| Payments disabled | **PASS** |
| Google Client Secret in Supabase | **CHECK** (paste current secret from Cloud Console) |
| Closed testing ready | **FAIL** until AAB + assets + testers |

### Exact next step
1. Follow `docs/GOOGLE_CONSOLE_SETUP.md` Part A (create Play app) + Part B1 (sync Google Client Secret → Supabase).  
2. Deploy/publish web so `https://firstvue.app/privacy.html` loads.  
3. Create upload keystore + `android/key.properties`; run `scripts/print_android_signing_fingerprints.sh`.  
4. Replace launcher icon art.  
5. `flutter build appbundle --release`  
6. Upload to Play **Internal testing**, then promote to **Closed testing**.  
