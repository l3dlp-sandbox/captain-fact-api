defmodule DB.Schema.Flag do
  use Ecto.Schema
  import Ecto.Changeset

  alias DB.Schema.{User, UserAction}


  schema "flags" do
    belongs_to :source_user, User # Source user
    belongs_to :action, UserAction
    field :reason, DB.Type.FlagReason
    timestamps()
  end

  @required_fields ~w(source_user_id action_id reason)a

  @doc"""
  Builds a changeset based on an `UserAction`
  """
  def changeset(struct, params) do
    cast(struct, params, [:action_id, :reason])
    |> validate_required(@required_fields)
  end
end
