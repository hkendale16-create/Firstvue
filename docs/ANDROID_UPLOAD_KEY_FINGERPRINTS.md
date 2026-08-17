# FirstVue Android upload key fingerprints

Generated for the Play upload keystore used to sign `FirstVue-1.0.1+2-release.aab`
(versionName `1.0.1`, versionCode `2`).

| Field | Value |
|-------|--------|
| Package | `app.firstvue.mobile` |
| Key alias | `upload` |
| SHA-1 | `49:D7:C2:C3:EB:9F:3F:DC:2A:50:FE:6C:81:E3:1C:AC:AB:D6:A6:02` |
| SHA-256 | `B7:54:00:BA:93:67:4F:E9:F4:74:C6:CF:B3:DA:44:3B:DD:7B:B7:DE:F5:23:B4:7A:6F:D3:1D:26:92:1D:B6:79` |

## Where to paste

1. **Google Cloud → Android OAuth client** — package `app.firstvue.mobile` + **SHA-1**
2. **`web/.well-known/assetlinks.json`** — **SHA-256** for App Links

The keystore binary and passwords are **not** in git. Download `upload-keystore.jks` + `key.properties` from the agent artifacts (`firstvue-play/`) and store them offline before the VM is deleted.
