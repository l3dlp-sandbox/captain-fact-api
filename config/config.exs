# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :captain_fact,
  ecto_repos: [CaptainFact.Repo],
  source_url_regex: ~r/[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&\/\/=]*)/

# Docker image generated (mainly used to realease)
config :mix_docker, image: "captain_fact_api"

# Configures the endpoint
config :captain_fact, CaptainFactWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: CaptainFactWeb.ErrorView, accepts: ~w(json), default_format: "json"],
  pubsub: [name: CaptainFact.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Configure ueberauth
config :ueberauth, Ueberauth,
  base_path: "/api/auth",
  providers: [
    identity: {Ueberauth.Strategy.Identity, [callback_methods: ["POST"]]},
    facebook: {Ueberauth.Strategy.Facebook, [profile_fields: "name,email,picture"]}
  ]

# Configure Guardian (authentication)
config :guardian, Guardian,
  issuer: "CaptainFact",
  ttl: {30, :days},
  serializer: CaptainFactWeb.GuardianSerializer,
  permissions: %{default: [:read, :write]}

# Configure ex_admin (Admin platform)
config :ex_admin,
#  theme: ExAdmin.Theme.ActiveAdmin,
  repo: CaptainFact.Repo,
  module: CaptainFactWeb,
  modules: [
    CaptainFactWeb.ExAdmin.Comment,
    CaptainFactWeb.ExAdmin.Dashboard,
    CaptainFactWeb.ExAdmin.Flag,
    CaptainFactWeb.ExAdmin.Source,
    CaptainFactWeb.ExAdmin.Speaker,
    CaptainFactWeb.ExAdmin.Statement,
    CaptainFactWeb.ExAdmin.User,
    CaptainFactWeb.ExAdmin.Video,
    CaptainFactWeb.ExAdmin.VideoDebateAction
  ]

# Configure file upload
config :arc,
  storage: Arc.Storage.Local

# Configure scheduler
config :quantum, :captain_fact,
  cron: [
    # Reset score limit counter at midnight
    "@daily": {CaptainFact.Accounts.UserState, :reset, []}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"

config :xain, :after_callback, {Phoenix.HTML, :raw}
