# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config


# General application configuration
config :captain_fact,
  env: Mix.env,
  ecto_repos: [DB.Repo],
  cors_origins: [],
  oauth: [facebook: []]

# Configures the endpoint
config :captain_fact, CaptainFactWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: CaptainFactWeb.ErrorView, accepts: ~w(json), default_format: "json"],
  pubsub: [name: CaptainFact.PubSub, adapter: Phoenix.PubSub.PG2],
  server: true

# Configure scheduler
config :captain_fact, CaptainFact.Scheduler,
  global: true, # Run only one instance across cluster
  jobs: [
    # credo:disable-for-lines:10
    # Actions analysers
    {{:extended, "*/5 * * * * *"}, {CaptainFactJobs.Votes, :update, []}}, # Every 5 seconds
    {            "*/1 * * * *",    {CaptainFactJobs.Reputation, :update, []}}, # Every minute
    {            "@daily",         {CaptainFactJobs.Reputation, :reset_daily_limits, []}}, # Every day
    {            "*/1 * * * *",    {CaptainFactJobs.Flags, :update, []}}, # Every minute
    {            "*/3 * * * *",    {CaptainFactJobs.Achievements, :update, []}}, # Every 3 minutes
    # Various updaters
    {            "*/5 * * * *",   {CaptainFactJobs.Moderation, :update, []}}, # Every 5 minutes
  ]

# Configure mailer
config :captain_fact, CaptainFactMailer, adapter: Bamboo.MailgunAdapter

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Configure Guardian (authentication)
config :guardian, Guardian,
  issuer: "CaptainFact",
  ttl: {30, :days},
  serializer: CaptainFact.Accounts.GuardianSerializer,
  permissions: %{default: [:read, :write]}

config :weave,
  environment_prefix: "CF_",
  loaders: [Weave.Loaders.Environment]

# Import environment specific config
import_config "#{Mix.env}.exs"
