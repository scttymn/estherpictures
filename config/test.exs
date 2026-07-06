import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :esther_pictures, EstherPictures.Repo,
  database: Path.expand("../esther_pictures_test.db", __DIR__),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :esther_pictures, EstherPicturesWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "wSqljBLFAGFtR3syn61s2pE+a6Jc1ec+/A9gneKhS1CifSJ0zlX2/rij6bbKPYop",
  server: false

# Keep test uploads (and upload garbage collection) away from real files
config :esther_pictures, EstherPictures.Uploads, root: Path.expand("../tmp/test_uploads", __DIR__)

# In test we don't send emails
config :esther_pictures, EstherPictures.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
