# FirstVue — Manual QA Checklist

Run after applying `supabase/apply_pending_migrations.sql` and deploying a fresh `build/web/`.

Use email aliases you control (for example `you+owner@yourdomain.com`). Do not register invented Gmail addresses.

## Accounts to create

| Role | Purpose |
|------|---------|
| Owner | Submit business, upload media, edit profile |
| Customer | Search, review, Vue feed engagement |
| Admin | Approve businesses, rentals, reviews, professionals |

Set admin: `profiles.account_type = 'admin'` in Supabase for the admin test user.

---

## 1. Authentication

- [ ] Sign up with new email + password
- [ ] Sign out and sign back in
- [ ] Profile screen shows account email
- [ ] Invalid credentials show a friendly error (not raw Supabase text)

## 2. Home & discovery

- [ ] Home loads FIRSTVUE header, AI search, 8 explore categories
- [ ] Mobile: 2-column category grid; desktop (≥900px): 4-column grid
- [ ] Each explore category navigates to the correct screen
- [ ] **Trending Near You** shows a live approved business (not "District Barber Co.")
- [ ] Trending empty state appears when no approved businesses exist
- [ ] **See all** opens Vue tab

## 3. Ask FirstVue AI search

- [ ] Homepage search opens AI results
- [ ] Prompt like "barber under $50 open today" returns ranked results
- [ ] Tapping a result opens verified business profile

## 4. Vue feed

- [ ] Vue tab loads feed cards (live Supabase media when published)
- [ ] **Spark** toggles gold active state; records engagement when signed in
- [ ] **Collection** toggles gold active state; records engagement when signed in
- [ ] **Route** copies a real URL (`https://your-domain/?business={id}`)
- [ ] Verified businesses show premium emblem
- [ ] VIEW BUSINESS opens profile

## 5. Business owner workflow

- [ ] Submit new business → status pending
- [ ] Admin approves business
- [ ] Owner uploads JPEG/PNG/WebP to business media
- [ ] Approved business appears in discovery + trending (after popularity data)
- [ ] Owner can delete their uploaded images

## 6. Customer reviews

- [ ] Signed-in customer submits 1–5 star review
- [ ] Review stays pending until admin approval
- [ ] Approved review appears on business profile
- [ ] Average rating and count update on profile

## 7. Rentals

- [ ] Signed-in user posts rental with image
- [ ] Admin approves rental
- [ ] Rental appears in Available Rentals discovery
- [ ] Inquiry sends to owner inbox

## 8. Professional profiles

- [ ] Create professional profile → pending
- [ ] Admin approves
- [ ] Approved professional appears in barber/stylist discovery
- [ ] Portfolio, availability, showcase sections render after migrations

## 9. Admin moderation

- [ ] Review approvals queue works
- [ ] Business submissions queue works
- [ ] Rental approvals queue works
- [ ] Professional approvals queue works

## 10. Deploy verification

- [ ] Production URL loads latest build (check EXPLORE has 8 categories + Vue tab)
- [ ] Share link from Vue feed opens business profile on production URL
- [ ] Supabase auth works on production domain (add URL to Supabase Auth redirect allow list)

---

## Pass criteria

- No mock business presented as verified without approval
- No raw database errors shown to users
- All three roles can complete their primary workflow end-to-end

## Issues log

| Date | Tester | Area | Issue | Severity |
|------|--------|------|-------|----------|
| | | | | |
