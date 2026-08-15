# Google Play Data Safety — FirstVue worksheet

Use this when filling Play Console → App content → Data safety.
Align answers with the live app. Do **not** claim data is unused if Supabase receives it.

Support email: `hkendale16@gmail.com`  
Privacy policy URL (after domain deploy): `https://firstvue.app/privacy.html`

---

## Overview answers

| Question | Recommended answer |
|----------|-------------------|
| Does your app collect or share user data? | **Yes** |
| Is all user data encrypted in transit? | **Yes** (HTTPS to Supabase / app hosts) |
| Do you provide a way for users to request deletion? | **Yes** — in-app Settings → Privacy → Delete account |
| Are you required to follow COPPA / target children? | **No** — app is 13+ |

---

## Data types collected

| Data type | Collected? | Shared? | Purpose | Optional? | Ephemeral? |
|-----------|------------|---------|---------|-----------|------------|
| Name / display name | Yes | No* | App functionality, account management | No (needed for social identity) | No |
| Email | Yes | No* | Account management, auth | No | No |
| User IDs | Yes | No* | App functionality | No | No |
| Photos | Yes | No* | App functionality (profiles, posts, VUE) | Yes | No |
| Videos | Yes | No* | App functionality (VUE / posts) | Yes | No |
| Other user-generated content | Yes | No* | Posts, comments, reviews, events, groups | Yes | No |
| Messages | Yes | No* | Messaging | Yes | No |
| Approximate location | Yes | No* | App functionality (nearby discovery) | Yes (permission) | No |
| Precise location | Declared permission may exist; only collect if actually used | No* | Nearby precision | Yes | No |
| Purchase history | **No** (payments disabled) | — | — | — | — |
| Device IDs / advertising ID | **No** unless FCM/analytics SDKs are added later | — | — | — | — |
| Crash logs / diagnostics | Only if a crash SDK is added | — | — | — | — |

\* “Shared” with third parties for Play means sold / used for advertising / transferred to other developers. Hosting with **Supabase as a service provider** processing data on your behalf is typically disclosed under service providers / “processed on our behalf,” not as selling. Confirm current Play wording when submitting.

---

## Purposes to select (as applicable)

- App functionality  
- Account management  
- Analytics (only if you add analytics SDK — currently engagement is first-party in Supabase)  
- Developer communications (account emails)  
- Fraud prevention / security / compliance  

Do **not** select advertising or personalization-for-ads unless you add ads.

---

## Security practices

- [x] Data encrypted in transit  
- [ ] Data encrypted at rest — Supabase/Postgres/Storage provide platform encryption; mark if Play asks and you rely on provider defaults  
- [x] Users can request deletion  

---

## Data deletion notes (accurate to implementation)

When a user deletes their account (and is not blocked by owned businesses/hubs/rentals):

- Personal profile PII is cleared / account Auth user is removed  
- Personal posts (non-entity) are removed  
- Messages are anonymized / marked deleted where applicable  
- Profile media rows are removed  
- Owned businesses / sole community hubs / rental listings must be removed first  

---

## Ads / payments

- Ads: **No**  
- In-app purchases / subscriptions: **Not enabled** in this trial (`FIRSTVUE_PAYMENTS` default false)  
