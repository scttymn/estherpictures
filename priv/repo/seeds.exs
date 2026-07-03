# Seeds the site with the copy from the "1B · Frame Index" design.
#
# Idempotent: running it again resets content to these defaults but leaves
# any existing user accounts untouched.
#
#     mix run priv/repo/seeds.exs

alias EstherPictures.Repo
alias EstherPictures.Content
alias EstherPictures.Content.{CraftService, Clip, EnsembleMember}

# --- Site settings (singleton) ---------------------------------------------
settings = Content.get_site_settings()

{:ok, _} =
  Content.update_site_settings(settings, %{
    collective_name: "ESTHER PICTURES",
    tagline: "AN INDEPENDENT FILM COLLECTIVE — NY / LA",
    hero_heading: "Films that trust\nthe audience.",
    contact_heading: "Let's make\nsomething.",
    email: "hello@estherpictures.com",
    studio_locations: "New York · Los Angeles",
    instagram_url: "#",
    letterboxd_url: "#",
    footer_text: "© 2026 ESTHER PICTURES — INDEPENDENT FILM COLLECTIVE"
  })

# --- Collections: wipe and reseed ------------------------------------------
Repo.delete_all(CraftService)
Repo.delete_all(Clip)
Repo.delete_all(EnsembleMember)

craft = [
  {1, "Writing",
   "Original screenplays and adaptations, developed in-house from first page to shooting draft."},
  {2, "Directing", "A tight bench of directors with a point of view, from short-form to feature."},
  {3, "Acting & Ensemble",
   "A resident ensemble and a casting network built over a decade of independent work."},
  {4, "Post & Craft", "Edit, color, sound, and score — the finishing that protects the cut."}
]

for {position, title, description} <- craft do
  {:ok, _} = Content.create_craft_service(%{position: position, title: title, description: description})
end

# Clip 01 is seeded with a sample video so the hero plays on first load; the
# rest start empty (add videos + upload thumbnails in the admin).
clips = [
  {1, "The Quiet Coast", "https://www.youtube.com/watch?v=bFcu0Rn1d7w", "04:12", "2.39 : 1 · DCP", "2023", "NOW PLAYING"},
  {2, "Nightshift", "", "03:48", "1.85 : 1", "2022", "SELECTED"},
  {3, "Salt", "", "02:31", "2.39 : 1", "2024", "SELECTED"},
  {4, "A Long Winter", "", "05:07", "1.66 : 1", "2021", "SELECTED"}
]

for {position, title, video_url, runtime, format, years, status} <- clips do
  {:ok, _} =
    Content.create_clip(%{
      position: position,
      title: title,
      video_url: video_url,
      runtime: runtime,
      format: format,
      years: years,
      status: status
    })
end

ensemble = [
  {1, "Mara Vance", "FOUNDER / WRITER-DIRECTOR", "2019"},
  {2, "Idris Bellê", "DIRECTOR / ACTOR", "2021"},
  {3, "Cleo Nakamura", "WRITER / EDITOR", "2022"}
]

for {position, name, role, since_year} <- ensemble do
  {:ok, _} =
    Content.create_ensemble_member(%{
      position: position,
      name: name,
      role: role,
      since_year: since_year
    })
end

IO.puts("Seeded site content (#{length(craft)} craft, #{length(clips)} clips, #{length(ensemble)} ensemble).")
