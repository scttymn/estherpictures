# Esther Pictures

The Esther Pictures website — a Phoenix app serving a public marketing homepage
(design direction **1B · Frame Index**) backed by a small admin where
non-developers edit all the site's content.

- **Framework:** Phoenix 1.8 (controllers + HEEx, no LiveView)
- **Database:** SQLite (single file, no server to run)
- **Public styling:** hand-written CSS at `priv/static/css/site.css` (no build step)
- **Admin styling:** Tailwind + daisyUI (Phoenix defaults)

## Running locally

```bash
mix setup            # installs deps, creates + migrates the DB, seeds content, builds assets
mix phx.server       # http://localhost:4000
```

`mix setup` runs the seeds, which populate the homepage with the launch copy.
Re-running `mix run priv/repo/seeds.exs` resets **content** to those defaults but
leaves user accounts untouched.

## First run: creating the administrator

The admin uses an **invite-based** flow — there is no open sign-up.

1. Visit `/users/register`. The **first** account you create becomes the
   **administrator**. After that, this page closes automatically.
2. You're logged in and dropped at `/admin`.

## Inviting editors

1. As an admin, go to **Users → Invite editor**.
2. Enter their email and role. A **temporary password is generated and shown to
   you once** — copy it and email it to the new editor yourself.
3. On their first login the editor is **forced to choose a new password** before
   they can reach anything else.

Admins can remove editors from the same screen. You can't delete your own account.

## Editing the site

Everything on the homepage is editable from `/admin` — no code, no redeploy:

- **Site copy** — nav brand/tagline, hero heading, reel slate details, contact
  block, social links, footer. Multi-line fields (hero & contact headings) keep
  their line breaks.
- **Craft** — the "what we do" grid. Order via the `position` field.
- **Clips** — the hero filmstrip. Order via `position`.
- **Ensemble** — the roster. Order via `position`.

The `01–04`, `CLIP 0X`, and `A1/A2` labels are derived automatically from order.

## The hero reel & clips

The hero is an **interactive clip player** driven by the **Clips** you manage in
the admin. On load, **clip 01 auto-plays, muted, looping**, and the left slate
shows that clip's stats. Visitors can **click any clip** in the filmstrip to make
it the active, looping clip (the slate updates to match), and there's a **sound**
toggle to unmute.

Each clip (admin → **Clips**) has:

- **Video URL** — a YouTube or Vimeo link. It's embedded chrome-less (no
  controls, no branding) and non-interactive, so it reads as a background reel.
- **Slate stats** — title, runtime, format, years, status (shown while active).
- **Thumbnail image** — an **uploaded** still (JPG/PNG/WebP/GIF, ≤5 MB). Because
  YouTube can't export a frame at a chosen timestamp, you upload the exact still
  you want.

Notes:
- Autoplay requires muting (a browser rule) — matching the design's muted reel.
  Clicking **sound** reloads the clip with audio (a fresh user gesture is
  required to unmute, so playback restarts).
- On load, YouTube briefly shows a title/spinner; Vimeo's background mode does
  not — prefer Vimeo for a perfectly clean start.
- Uploaded thumbnails live in `priv/static/uploads/` (git-ignored). **On deploy
  they must sit on a persistent volume** (see Deployment, TBD) or they'll be lost
  on redeploy. Local placeholder videos, if any, live in `priv/static/media/`
  (also git-ignored).

## Project layout

```
lib/esther_pictures/
  accounts/            # users, auth, invite + role logic
  content/             # site_setting, craft_service, clip, ensemble_member schemas
  content.ex           # editable-content context
lib/esther_pictures_web/
  controllers/
    page_controller.ex           # public homepage (uses the public root layout)
    page_html/home.html.heex     # the 1B Frame Index page
    admin/                       # dashboard, site copy, craft, clips, ensemble, users
priv/static/css/site.css         # public marketing styles
priv/repo/seeds.exs              # launch content
```

## Tests

```bash
mix test
```
