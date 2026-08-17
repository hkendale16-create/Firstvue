# Store listing assets

Upload these on **Dashboard → Set up your store listing → Graphics** (not Internal testing).

| Play field | File | Spec |
|------------|------|------|
| **App icon** | `play-icon-512.png` | 512×512 PNG |
| **Feature graphic** | `feature-graphic-1024x500.png` | 1024×500 PNG |
| **Video** | skip (leave blank) | optional YouTube URL |
| **Phone screenshots** | `phone-screenshots/01-vue.png` … `04-profile.png` | 1080×1920, 9:16 |
| **7-inch tablet** | `tablet-7inch/` (same 4 shots) | 1080×1920, 9:16 |
| **10-inch tablet** | `tablet-10inch/` (same 4 shots) | 1440×2560, 9:16 |

Upload **at least 2** in phone **or** tablet. To clear every Graphics checkbox, upload 2+ in each tablet section (VUE + Explore is enough).

Upload phone screenshots in this order:

1. `01-vue.png` — VUE grid  
2. `02-explore.png` — Explore  
3. `03-business.png` — Business profile  
4. `04-profile.png` — Profile  

Play applies its own rounded mask to the app icon. Do **not** upload the circular PNG as the listing icon.

Regenerate:

```bash
python3 scripts/generate_play_icon.py
python3 scripts/generate_store_listing_assets.py
```
