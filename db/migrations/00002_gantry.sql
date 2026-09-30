-- From Phoenix to gantry: users in gantry auth's shape (their bcrypt hashes
-- carry over, so passwords keep working), sessions in its table (Phoenix's
-- tokens go: everyone signs in once more), and created_at for inserted_at,
-- every timestamp written as gantry's driver writes them, so a column sorts
-- in time order whichever app wrote a row.
-- +goose Up
ALTER TABLE "users" RENAME COLUMN "email" TO "email_address";
ALTER TABLE "users" RENAME COLUMN "hashed_password" TO "password_digest";
ALTER TABLE "users" RENAME COLUMN "inserted_at" TO "created_at";
ALTER TABLE "users" DROP COLUMN "confirmed_at";
UPDATE "users" SET "email_address" = lower(trim("email_address"));
DROP INDEX "users_email_index";
CREATE UNIQUE INDEX "index_users_on_email_address" ON "users" ("email_address");

DROP TABLE "users_tokens";
CREATE TABLE "sessions" (
  "id" integer PRIMARY KEY AUTOINCREMENT NOT NULL,
  "user_id" integer NOT NULL REFERENCES "users" ("id") ON DELETE CASCADE,
  "token_digest" text NOT NULL,
  "ip_address" text NOT NULL DEFAULT '',
  "user_agent" text NOT NULL DEFAULT '',
  "created_at" datetime NOT NULL,
  "last_seen_at" datetime NOT NULL
);
CREATE UNIQUE INDEX "index_sessions_on_token_digest" ON "sessions" ("token_digest");
CREATE INDEX "index_sessions_on_user_id" ON "sessions" ("user_id");

ALTER TABLE "site_settings" RENAME COLUMN "inserted_at" TO "created_at";
ALTER TABLE "craft_services" RENAME COLUMN "inserted_at" TO "created_at";
ALTER TABLE "clips" RENAME COLUMN "inserted_at" TO "created_at";
ALTER TABLE "ensemble_members" RENAME COLUMN "inserted_at" TO "created_at";
ALTER TABLE "content_versions" RENAME COLUMN "inserted_at" TO "created_at";
DROP INDEX "content_versions_inserted_at_index";
CREATE INDEX "index_content_versions_on_created_at" ON "content_versions" ("created_at");

UPDATE "users" SET "created_at" = strftime('%Y-%m-%d %H:%M:%S+00:00', "created_at"), "updated_at" = strftime('%Y-%m-%d %H:%M:%S+00:00', "updated_at");
UPDATE "site_settings" SET "created_at" = strftime('%Y-%m-%d %H:%M:%S+00:00', "created_at"), "updated_at" = strftime('%Y-%m-%d %H:%M:%S+00:00', "updated_at");
UPDATE "craft_services" SET "created_at" = strftime('%Y-%m-%d %H:%M:%S+00:00', "created_at"), "updated_at" = strftime('%Y-%m-%d %H:%M:%S+00:00', "updated_at");
UPDATE "clips" SET "created_at" = strftime('%Y-%m-%d %H:%M:%S+00:00', "created_at"), "updated_at" = strftime('%Y-%m-%d %H:%M:%S+00:00', "updated_at");
UPDATE "ensemble_members" SET "created_at" = strftime('%Y-%m-%d %H:%M:%S+00:00', "created_at"), "updated_at" = strftime('%Y-%m-%d %H:%M:%S+00:00', "updated_at");
UPDATE "content_versions" SET "created_at" = strftime('%Y-%m-%d %H:%M:%S+00:00', "created_at");

-- Ecto's record of its migrations: gantry keeps its own (app_migrations).
DROP TABLE IF EXISTS "schema_migrations";

-- +goose Down
-- Irreversible: going back to Phoenix is restoring the database as it was
-- (Houston's snapshot before the deploy).
