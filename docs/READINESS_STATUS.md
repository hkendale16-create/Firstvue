# FirstVue readiness snapshot — 2026-08-15

## FIRSTVUE STATUS

**READY FOR INTERNAL TEST** (code/backend Critical blockers for trial addressed)

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
| Android API 36 | **PASS** |
| applicationId `app.firstvue.mobile` | **PASS** |
| Release signing | **FAIL** until keystore |
| AAB generated | **FAIL** here (no Android SDK in cloud agent); build locally |
| Privacy policy page in repo | **PASS** (`web/privacy.html`) |
| Privacy URL live on domain | **FAIL** until you deploy domain |
| Data Safety worksheet | **PASS** (`docs/DATA_SAFETY.md`) |
| Store assets | **MISSING** |
| Account deletion | **PASS** |
| Payments disabled | **PASS** |
| Closed testing ready | **FAIL** until AAB + assets + testers |

### Exact next step
1. Deploy/publish web so `https://firstvue.app/privacy.html` loads.  
2. Create upload keystore + `android/key.properties`.  
3. Replace launcher icon art.  
4. `flutter build appbundle --release`  
5. Upload to Play **Internal testing**, then promote to **Closed testing**.  
