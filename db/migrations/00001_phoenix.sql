-- The schema the Phoenix app left, exactly as Ecto made it: the live
-- database has it already (IF NOT EXISTS leaves it be), and a new one starts
-- from it, so the next migration, which moves it onto gantry, runs the same
-- on both.
-- +goose Up
CREATE TABLE IF NOT EXISTS "users" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "email" TEXT NOT NULL COLLATE NOCASE, "hashed_password" TEXT, "confirmed_at" TEXT, "role" TEXT DEFAULT 'editor' NOT NULL, "must_change_password" INTEGER DEFAULT false NOT NULL, "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL);
CREATE UNIQUE INDEX IF NOT EXISTS "users_email_index" ON "users" ("email");
CREATE TABLE IF NOT EXISTS "users_tokens" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "user_id" INTEGER NOT NULL CONSTRAINT "users_tokens_user_id_fkey" REFERENCES "users"("id") ON DELETE CASCADE, "token" BLOB NOT NULL, "context" TEXT NOT NULL, "sent_to" TEXT, "authenticated_at" TEXT, "inserted_at" TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS "users_tokens_user_id_index" ON "users_tokens" ("user_id");
CREATE UNIQUE INDEX IF NOT EXISTS "users_tokens_context_token_index" ON "users_tokens" ("context", "token");
CREATE TABLE IF NOT EXISTS "site_settings" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "collective_name" TEXT DEFAULT 'ESTHER PICTURES' NOT NULL, "tagline" TEXT DEFAULT '' NOT NULL, "hero_heading" TEXT DEFAULT '' NOT NULL, "contact_heading" TEXT DEFAULT '' NOT NULL, "email" TEXT DEFAULT '' NOT NULL, "studio_locations" TEXT DEFAULT '' NOT NULL, "instagram_url" TEXT DEFAULT '' NOT NULL, "letterboxd_url" TEXT DEFAULT '' NOT NULL, "footer_text" TEXT DEFAULT '' NOT NULL, "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS "craft_services" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "position" INTEGER DEFAULT 0 NOT NULL, "title" TEXT NOT NULL, "description" TEXT DEFAULT '' NOT NULL, "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS "craft_services_position_index" ON "craft_services" ("position");
CREATE TABLE IF NOT EXISTS "clips" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "position" INTEGER DEFAULT 0 NOT NULL, "title" TEXT NOT NULL, "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "video_url" TEXT DEFAULT '' NOT NULL, "thumbnail_path" TEXT DEFAULT '' NOT NULL, "runtime" TEXT DEFAULT '' NOT NULL, "format" TEXT DEFAULT '' NOT NULL, "years" TEXT DEFAULT '' NOT NULL, "status" TEXT DEFAULT '' NOT NULL);
CREATE INDEX IF NOT EXISTS "clips_position_index" ON "clips" ("position");
CREATE TABLE IF NOT EXISTS "ensemble_members" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "position" INTEGER DEFAULT 0 NOT NULL, "name" TEXT NOT NULL, "role" TEXT DEFAULT '' NOT NULL, "since_year" TEXT DEFAULT '' NOT NULL, "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "bio" TEXT DEFAULT '' NOT NULL, "headshot_path" TEXT DEFAULT '' NOT NULL);
CREATE INDEX IF NOT EXISTS "ensemble_members_position_index" ON "ensemble_members" ("position");
CREATE TABLE IF NOT EXISTS "content_versions" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "item_type" TEXT NOT NULL, "item_id" INTEGER NOT NULL, "action" TEXT NOT NULL, "data" TEXT NOT NULL, "user_id" INTEGER CONSTRAINT "content_versions_user_id_fkey" REFERENCES "users"("id") ON DELETE SET NULL, "inserted_at" TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS "content_versions_item_type_item_id_index" ON "content_versions" ("item_type", "item_id");
CREATE INDEX IF NOT EXISTS "content_versions_inserted_at_index" ON "content_versions" ("inserted_at");

-- +goose Down
-- Irreversible: going back to Phoenix is restoring the database as it was
-- (Houston's snapshot before the deploy).
