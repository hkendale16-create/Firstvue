# Store listing assets

Upload these on **Dashboard → Set up your store listing → Graphics** (not Internal testing).

| Play field | File | Spec |
|------------|------|------|
| **App icon** | `play-icon-512.png` | 512×512 PNG |
| **Feature graphic** | `feature-graphic-1024x500.png` | 1024×500 PNG |
| **Video** | skip (leave blank) | optional YouTube URL |
| **Phone screenshots** | `phone-screenshots/01-vue.png` … `04-profile.png` | 1080×1920, 9:16, 4 shots |
| **7-inch / 10-inch tablet** | skip | phone shots already satisfy the 2-screenshot minimum |

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
