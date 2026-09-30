-- The schema as the migrations leave it, for sqlc and for reading. It's
-- written from the migrations; don't edit it by hand.

CREATE TABLE "active_storage_attachments" (
  "id" integer PRIMARY KEY AUTOINCREMENT NOT NULL,
  "name" varchar NOT NULL,
  "record_type" varchar NOT NULL,
  "record_id" bigint NOT NULL,
  "blob_id" bigint NOT NULL REFERENCES "active_storage_blobs" ("id"),
  "created_at" datetime NOT NULL
);
CREATE TABLE "active_storage_blobs" (
  "id" integer PRIMARY KEY AUTOINCREMENT NOT NULL,
  "key" varchar NOT NULL,
  "filename" varchar NOT NULL,
  "content_type" varchar,
  "metadata" text,
  "service_name" varchar NOT NULL,
  "byte_size" bigint NOT NULL,
  "checksum" varchar,
  "created_at" datetime NOT NULL
);
CREATE TABLE "clips" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "position" INTEGER DEFAULT 0 NOT NULL, "title" TEXT NOT NULL, "created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "video_url" TEXT DEFAULT '' NOT NULL, "thumbnail_path" TEXT DEFAULT '' NOT NULL, "runtime" TEXT DEFAULT '' NOT NULL, "format" TEXT DEFAULT '' NOT NULL, "years" TEXT DEFAULT '' NOT NULL, "status" TEXT DEFAULT '' NOT NULL);
CREATE TABLE "content_versions" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "item_type" TEXT NOT NULL, "item_id" INTEGER NOT NULL, "action" TEXT NOT NULL, "data" TEXT NOT NULL, "user_id" INTEGER CONSTRAINT "content_versions_user_id_fkey" REFERENCES "users"("id") ON DELETE SET NULL, "created_at" TEXT NOT NULL);
CREATE TABLE "craft_services" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "position" INTEGER DEFAULT 0 NOT NULL, "title" TEXT NOT NULL, "description" TEXT DEFAULT '' NOT NULL, "created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL);
CREATE TABLE "ensemble_members" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "position" INTEGER DEFAULT 0 NOT NULL, "name" TEXT NOT NULL, "role" TEXT DEFAULT '' NOT NULL, "since_year" TEXT DEFAULT '' NOT NULL, "created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "bio" TEXT DEFAULT '' NOT NULL, "headshot_path" TEXT DEFAULT '' NOT NULL);
CREATE TABLE "sessions" (
  "id" integer PRIMARY KEY AUTOINCREMENT NOT NULL,
  "user_id" integer NOT NULL REFERENCES "users" ("id") ON DELETE CASCADE,
  "token_digest" text NOT NULL,
  "ip_address" text NOT NULL DEFAULT '',
  "user_agent" text NOT NULL DEFAULT '',
  "created_at" datetime NOT NULL,
  "last_seen_at" datetime NOT NULL
);
CREATE TABLE "site_settings" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "collective_name" TEXT DEFAULT 'ESTHER PICTURES' NOT NULL, "tagline" TEXT DEFAULT '' NOT NULL, "hero_heading" TEXT DEFAULT '' NOT NULL, "contact_heading" TEXT DEFAULT '' NOT NULL, "email" TEXT DEFAULT '' NOT NULL, "studio_locations" TEXT DEFAULT '' NOT NULL, "instagram_url" TEXT DEFAULT '' NOT NULL, "letterboxd_url" TEXT DEFAULT '' NOT NULL, "footer_text" TEXT DEFAULT '' NOT NULL, "created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL);
CREATE TABLE "users" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "email_address" TEXT NOT NULL COLLATE NOCASE, "password_digest" TEXT, "role" TEXT DEFAULT 'editor' NOT NULL, "must_change_password" INTEGER DEFAULT false NOT NULL, "created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL);
CREATE INDEX "index_active_storage_attachments_on_blob_id" ON "active_storage_attachments" ("blob_id");
CREATE UNIQUE INDEX "index_active_storage_attachments_uniqueness" ON "active_storage_attachments" ("record_type", "record_id", "name", "blob_id");
CREATE UNIQUE INDEX "index_active_storage_blobs_on_key" ON "active_storage_blobs" ("key");
CREATE INDEX "clips_position_index" ON "clips" ("position");
CREATE INDEX "content_versions_item_type_item_id_index" ON "content_versions" ("item_type", "item_id");
CREATE INDEX "index_content_versions_on_created_at" ON "content_versions" ("created_at");
CREATE INDEX "craft_services_position_index" ON "craft_services" ("position");
CREATE INDEX "ensemble_members_position_index" ON "ensemble_members" ("position");
CREATE UNIQUE INDEX "index_sessions_on_token_digest" ON "sessions" ("token_digest");
CREATE INDEX "index_sessions_on_user_id" ON "sessions" ("user_id");
CREATE UNIQUE INDEX "index_users_on_email_address" ON "users" ("email_address");
