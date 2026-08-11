# Deploy FirstVue to Netlify

## Why the first deploy failed

The old `netlify.toml` used `echo ...` as the build command. That only printed a message and never ran Flutter, so `build/web` was never created.

This is fixed. Netlify now runs `scripts/build-web.sh`, which installs Flutter and builds the site.

---

## Option A — Connect Git (recommended for updates)

1. Push this project to GitHub (or GitLab/Bitbucket).
2. In [Netlify](https://app.netlify.com): **Add new site → Import an existing project**.
3. Netlify reads `netlify.toml` automatically:
   - **Build command:** `bash scripts/build-web.sh`
   - **Publish directory:** `build/web`
4. Deploy. First build may take **8–15 minutes** (Flutter download + compile).
5. After deploy, add your Netlify URL in Supabase → **Authentication → URL Configuration**.

Every git push can trigger a new deploy automatically.

---

## Option B — Manual drag-and-drop (no Git build)

Use this if you build on your Windows machine and only upload files.

1. On your PC, run:
   ```powershell
   cd "C:\Users\User1\Documents\Codex\2026-08-10\now-inspect-the-existing-firstvue-repository-2\firstvue"
   .\scripts\build-web.ps1 -WebUrl "https://YOUR-SITE.netlify.app"
   ```
2. In Netlify: **Add new site → Deploy manually**.
3. Drag the folder:
   ```
   ...\firstvue\build\web
   ```
4. Do **not** connect the full repo to this manual site, or Netlify will try to run the build command again.

To update later: rebuild locally → drag `build\web` again → hard refresh (`Ctrl+Shift+R`).

---

## Supabase auth (required for sign-in on live site)

1. [Supabase Auth URL Configuration](https://supabase.com/dashboard/project/sdssshegqdwobjelxzkp/auth/url-configuration)
2. **Site URL:** `https://your-site.netlify.app`
3. **Redirect URLs:** `https://your-site.netlify.app/**`

---

## New database features (messaging + comments)

Run in Supabase SQL Editor if not done yet:

`supabase/migrations/20260811_messaging_and_comments.sql`
