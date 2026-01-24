defmodule Toolbox.Flow do
  @moduledoc """
  Utility functions for platform operations.
  """

  @doc """
  Railway-oriented programming helper that continues processing with a function
  unless the data is already a terminal state.

  This function enables sequential operations with heterogeneous return types
  and automatic error propagation. It short-circuits on terminal states
  (`:ok`, `{:ok, _}`, `{:error, _}`) and transforms raw data through the
  provided function.

  ## Terminal States (short-circuit)
  - `{:error, _}` - Propagates error tuples unchanged
  - `{:ok, _}` - Propagates success tuples unchanged
  - `:ok` - Propagates ok atom unchanged

  ## Non-terminal States (transform)
  - Any other value is passed through `step_fn` for transformation

  ## Use Cases
  - Sequential operations where each step returns different types
  - Clean pipelines with mixed return types (booleans, tuples, raw values)
  - Alternative to deeply nested `case` or awkward `with` statements
  - Automatic short-circuiting without explicit pattern matching at each step

  See `Toolbox.FlowTest` for comprehensive examples and `Platform.Tools.Postgres.Database` for production usage.
  """
  def go_on(data, step_fn) do
    case data do
      {:error, _} -> data
      {:ok, _} -> data
      :ok -> data
      _ -> step_fn.(data)
    end
  end
end
