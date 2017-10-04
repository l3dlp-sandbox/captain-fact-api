defmodule CaptainFact.Accounts.UserPermissions do
  @moduledoc """
  Check and log user permissions. State is a map looking like this :
  """

  require Logger
  import Ecto.Query

  alias CaptainFact.Repo
  alias CaptainFact.Accounts.{User, UserState}
  defmodule PermissionsError do
    defexception message: "forbidden", plug_status: 403
  end

  @user_state_key :user_permissions
  @levels [-30, -5, 15, 30, 50, 100, 200, 500, 1000]
  @reverse_levels Enum.reverse(@levels)
  @nb_levels Enum.count(@levels)
  @lowest_acceptable_reputation List.first(@levels)
  @limitations %{
    #                        /!\ |️ New user          | Confirmed user
    # reputation            {-30 , -5 , 15 , 30 , 50 , 100 , 200 , 500 , 1000}
    #-------------------------------------------------------------------------
    create: %{
      comment:              { 3  ,  5 , 10 , 20 , 30 , 200 , 200 , 200 , 200 },
      statement:            { 0  ,  5 ,  5 , 15 , 30 ,  50 , 100 , 100 , 100 },
      speaker:              { 0  ,  3 ,  10, 15 , 20 ,  30 ,  50 , 100 , 100 },
    },
    add: %{
      video:                { 0  ,  1 ,  5 , 10 , 15 ,  30 ,  30 ,  30 ,  30 },
      speaker:              { 0  ,  5 ,  10, 15 , 20 ,  30 ,  50 , 100 , 100 },
    },
    update: %{
      comment:              { 3  , 10 , 15 , 30 , 30 , 100 , 100 , 100 , 100 },
      statement:            { 0  ,  5 ,  0 ,  3 ,  5 ,  50 , 100 , 100 , 100 },
      speaker:              { 0  ,  0 ,  3 ,  5 , 10 ,  30 ,  50 , 100 , 100 },
    },
    delete: %{

    },
    remove: %{
      statement:            { 0  ,  5 ,  0 ,  3 ,  5 ,  10 ,  10 ,  10 ,  10 },
      speaker:              { 0  ,  0 ,  3 ,  5 , 10 ,  30 ,  50 , 100 , 100 },
    },
    restore: %{
      statement:            { 0  ,  5 ,  0 ,  3 ,  5 ,  15 ,  15 ,  15 ,  15 },
      speaker:              { 0  ,  0 ,  0 ,  5 , 10 ,  30 ,  50 , 100 , 100 }
    },
    approve: %{
      history_action:       { 0  ,  0 ,  0 ,  0 ,  0 ,   0 ,   0 ,   0 ,   0 },
    },
    flag: %{
      history_action:       { 0  ,  1 ,  3 ,  5 ,  5 ,   5 ,   5 ,   5 ,   5 },
      comment:              { 0  ,  0 ,  1 ,  3 ,  3 ,   5 ,  10 ,  10 ,  10 },
    },
    vote_up: %{
      comment:              { 0  ,  5 , 15 , 30 , 45 , 300 , 500 , 500 , 500 },
    },
    vote_down: %{
      comment:              { 0  ,  0 ,  0 ,  5 , 10 ,  20 ,  40 ,  80 , 150 },
    },
    self_vote: %{
      comment:              { 3  ,  10, 15 , 30 , 50 , 250 , 250 , 250 , 250 },
    }
  }

  # --- API ---

  @doc """
  The safe way to ensure limitations and record actions as state is locked during `func` execution.
  Raises PermissionsError if user doesn't have the permission.

  lock! will do an optimistic lock by incrementing the counter for this action then execute func.
  Returning a tupe like {:error, _} or raiseing / raising in `func` will revert the action
  """
  def lock!(user = %User{}, action_type, entity, func) do
    limit = limitation(user, action_type, entity)

    if (limit == 0), do: raise %PermissionsError{message: "not_enough_reputation"}

    # Optimistic lock
    lock_status = UserState.get_and_update(user, @user_state_key, fn state ->
      state = state || %{}
      if Map.get(state, deprecated_action(action_type, entity), 0) >= limit,
        do: {:error, state},
        else: {:ok, do_record_action(state, action_type, entity)}
    end)
    if lock_status == :error, do: raise %PermissionsError{message: "limit_reached"}

    try do
      func.(user)
    catch
      e ->
        UserState.update(user, @user_state_key, 0, &do_revert_action(&1, action_type, entity))
        raise e
    rescue
      e ->
        UserState.update(user, @user_state_key, 0, &do_revert_action(&1, action_type, entity))
        reraise e, System.stacktrace
    else
      response = {:error, _} ->
        UserState.update(user, @user_state_key, 0, &do_revert_action(&1, action_type, entity))
        response
      response -> response
    end
  end
  def lock!(user_id, action_type, entity, func) when is_integer(user_id),
    do: lock!(do_load_user!(user_id), action_type, entity, func)
  def lock!(nil, _, _, _), do: raise %PermissionsError{message: "unauthorized"}

  def deprecated_action(action_type, entity) do
    Atom.to_string(action_type) <> Atom.to_string(entity) # TODO Just for UserState storage
  end

  @doc """
  Run Repo.transaction while locking permissions. Usefull when piping
  """
  def lock_transaction!(transaction = %Ecto.Multi{}, user, action_type, entity),
    do: lock!(user, action_type, entity, fn _ -> Repo.transaction(transaction) end)

  @doc """
  Check if user can execute action. Return {:ok, nb_available} if yes, {:error, reason} otherwise
  ## Examples
      iex> alias CaptainFact.Accounts.{User, UserPermissions}
      iex> user = %User{id: 1, reputation: 42}
      iex> UserPermissions.check(user, :create, :comment)
      {:ok, 20}
      iex> UserPermissions.check(%{user | reputation: -42}, :remove, :statement)
      {:error, "not_enough_reputation"}
      iex> for _ <- 0..50, do: UserPermissions.record_action(user, :create, :comment)
      iex> UserPermissions.check(user, :create, :comment)
      {:error, "limit_reached"}
  """
  def check(user = %User{}, action_type, entity) do
    limit = limitation(user, action_type, entity)
    if (limit == 0) do
      {:error, "not_enough_reputation"}
    else
      action_count = Map.get(UserState.get(user, @user_state_key, %{}), deprecated_action(action_type, entity), 0)
      if action_count >= limit,
      do: {:error, "limit_reached"},
      else: {:ok, limit - action_count}
    end
  end
  def check(nil, _, _), do: {:error, "unauthorized"}
  def check!(user = %User{}, action_type, entity) do
    case check(user, action_type, entity) do
      {:ok, _} -> :ok
      {:error, message} -> raise %PermissionsError{message: message}
    end
  end
  def check!(user_id, action_type, entity) when is_integer(user_id)  do
     check!(do_load_user!(user_id), action_type, entity)
  end
  def check!(nil, _, _), do: raise %PermissionsError{message: "unauthorized"}

  @doc """
  Doesn't verify user's limitation nor reputation, you need to check that by yourself
  """
  def record_action(user = %User{}, action_type, entity) do
    action = deprecated_action(action_type, entity)
    UserState.update(user, @user_state_key, %{action => 1}, &do_record_action(&1, action_type, entity))
  end
  def record_action(user_id, action_type, entity) when is_integer(user_id),
    do: record_action(%User{id: user_id}, action_type, entity)

  def user_nb_action_occurences(user = %User{}, action_type, entity) do
    UserState.get(user, @user_state_key, %{})
    |> Map.get(deprecated_action(action_type, entity), 0)
  end

  def limitation(user = %User{}, action_type, entity) do
    case level(user) do
      -1 -> 0 # Reputation under minimum user can't do anything
      level -> elem(get_in(@limitations, [action_type, entity]), level)
    end
  end

  def level(%User{reputation: reputation}) do
    if reputation < @lowest_acceptable_reputation,
      do: -1,
      else: (@nb_levels - 1) - Enum.find_index(@reverse_levels, &(reputation >= &1))
  end

  # Static getters
  def limitations(), do: @limitations
  def nb_levels(), do: @nb_levels

  # Methods

  defp do_record_action(user_actions, action_type, entity),
    do: Map.update(user_actions, deprecated_action(action_type, entity), 1, &(&1 + 1))
  defp do_revert_action(user_actions, action_type, entity),
    do: Map.update(user_actions, deprecated_action(action_type, entity), 0, &(&1 - 1))

  defp do_load_user!(nil), do: raise %PermissionsError{message: "unauthorized"}
  defp do_load_user!(user_id) do
    User
    |> where([u], u.id == ^user_id)
    |> select([:id, :reputation])
    |> Repo.one!()
  end
end
