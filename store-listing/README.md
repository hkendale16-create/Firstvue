# Store listing assets

Upload these on **Dashboard → Set up your store listing → Graphics** (not Internal testing).

| Play field | File | Spec |
|------------|------|------|
| **App icon** | `play-icon-512.png` | 512×512 PNG |
| **Feature graphic** | `feature-graphic-1024x500.png` | 1024×500 PNG |
| **Video** | skip (leave blank) | optional YouTube URL |
| **Phone screenshots** | `phone-screenshots/` (4 unique light 9:16 shots) | 1080×1920 |
| **7-inch tablet** | `tablet-7inch/` (2 unique **dark 16:9** shots) | **1280×720** |
| **10-inch tablet** | `tablet-10inch/` (2 unique **dark 16:9** shots) | **1920×1080** |

Tablet shots are different screens from the phone set (Home, Feeds, Community, Professional) and use dark theme.

Regenerate:

```bash
python3 scripts/generate_play_icon.py
python3 scripts/generate_store_listing_assets.py
python3 scripts/generate_tablet_screenshots.py
```
