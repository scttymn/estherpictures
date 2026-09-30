# Esther Pictures

The Esther Pictures website: a public homepage (design direction **1B · Frame
Index**) and a small admin where non-developers edit everything on it. Built
on [gantry](https://github.com/scttymn/gantry) (Go, templ, SQLite), deployed by
[Houston](https://github.com/scttymn/houston). It was a Phoenix app until
2026-09-30; its database and uploads carry over (see "From Phoenix").

## Running locally

```bash
gantry dev      # http://estherpictures.localhost (houston dev); code changes reload
gantry test     # go vet and the tests, in the test image
gantry console  # the database's console
```

gantry is mounted beside the app in development (`../gantry`, through a
`go.work` git ignores), so changes to both show at once; tests and deploys
build against the gantry version `go.mod` pins.

A new database starts with the launch copy (`db/seeds`).

## First run: the administrator

There is no open sign-up. Visit `/users/register`: the **first** account
becomes the administrator, and the page closes after it.

## Editors

An admin invites editors at **Users → Invite editor**. A seven-digit temporary
password is shown once, to send on; at their first sign-in the editor chooses
their own before anything else. **Reset password** gives a new temporary one
and signs them out everywhere. Nobody resets or removes their own account
there. The site sends no email, so there's no "forgot password" link: an
admin resets it.

Editors edit the site; the users and the history are for admins.

## Editing the site

Everything on the homepage is in `/admin`:

- **Site copy**: the nav's brand and tagline, the hero heading, the contact
  block, the social links, the footer. Multi-line fields keep their line
  breaks.
- **Craft**: the "what we do" grid, ordered by position.
- **Clips**: the hero's filmstrip, ordered by position. Clip 01's thumbnail is
  the hero's picture, and nothing plays until a visitor asks: **Play**, a tap
  on the reel, or a clip in the filmstrip plays it with sound, and a tap
  pauses it. (Clip 01's YouTube player loads, paused, a few seconds after the
  page has painted, so the first tap starts it at once, sound and all, on an
  iPhone too.) On phones and tablets the reel is the page's width, at 16:9. A clip is a YouTube
  or Vimeo link (or a video file's address), its slate stats, and a thumbnail
  (JPG, PNG, WebP or GIF, up to 5 MB): upload the still you want, as YouTube
  can't export a chosen frame.
- **Cast**: the roster, ordered by position. A member with a bio opens to show
  it, beside their headshot.

The `01–04`, `CLIP 0X` and `A1/A2` labels come from the order.

## History

Every edit and deletion is kept (the newest 20 per item) at **History**, with
what it changed. Any can be reverted, and a deleted item brought back, image
and all; a revert is recorded too, so it can be undone. A replaced image is
kept while a history entry names it, and deleted once none does (after
discarding entries, or clearing the history).

## Images

Thumbnails and headshots are gantry's `storage` (Active Storage's tables and
disk layout, under `DATA_DIR/storage`). Each is served at every width it comes
in, as AVIF and WebP, the copies made in the background by a child process
that keeps out of the server's way.

## From Phoenix

The first start on the Phoenix app's database (`db/migrations/00002_gantry.sql`)
moves it onto gantry: users keep their passwords (bcrypt), sessions don't
(everyone signs in once more), and every timestamp is rewritten as gantry
writes them. Then the uploads under `DATA_DIR/uploads` move into storage, and
the history's entries name them, and the `uploads/` folder goes. There's no
way back but restoring the volume as it was before the deploy.

`test/phoenix` is a database the Phoenix app made through its own code, with
its uploads: `TestFromPhoenix` moves it and checks the site, the sign-ins and
the history.

## Layout

```
app/home/             the public page, and its clip player
app/admin/            the admin's layout and sign-in, and a package per section
app/services/content  the content's history: versions, restoring, the image sweep
app/models/           the tables' queries (sqlc) and rules
assets/               site.css and site.js (the public page), admin.css, the fonts
db/migrations/        the schema's changes, run at start
```
