defmodule Toolbox.FlowTest do
  use ExUnit.Case, async: true
  doctest Toolbox.Flow

  alias Toolbox.Flow

  describe "go_on/2 with terminal states" do
    test "propagates {:ok, value} tuples unchanged" do
      result = Flow.go_on({:ok, "success"}, fn _ -> raise "should not be called" end)
      assert result == {:ok, "success"}
    end

    test "propagates {:ok, value} with various value types" do
      assert Flow.go_on({:ok, 123}, fn _ -> :fail end) == {:ok, 123}
      assert Flow.go_on({:ok, []}, fn _ -> :fail end) == {:ok, []}
      assert Flow.go_on({:ok, %{key: "value"}}, fn _ -> :fail end) == {:ok, %{key: "value"}}
      assert Flow.go_on({:ok, nil}, fn _ -> :fail end) == {:ok, nil}
    end

    test "propagates {:error, reason} tuples unchanged" do
      result = Flow.go_on({:error, "failed"}, fn _ -> raise "should not be called" end)
      assert result == {:error, "failed"}
    end

    test "propagates {:error, reason} with various reason types" do
      assert Flow.go_on({:error, :not_found}, fn _ -> :fail end) == {:error, :not_found}
      assert Flow.go_on({:error, %{message: "error"}}, fn _ -> :fail end) == {:error, %{message: "error"}}
      assert Flow.go_on({:error, ["multiple", "errors"]}, fn _ -> :fail end) == {:error, ["multiple", "errors"]}
    end

    test "propagates :ok atom unchanged" do
      result = Flow.go_on(:ok, fn _ -> raise "should not be called" end)
      assert result == :ok
    end
  end

  describe "go_on/2 with non-terminal states" do
    test "transforms raw string values" do
      result = Flow.go_on("hello", fn x -> String.upcase(x) end)
      assert result == "HELLO"
    end

    test "transforms boolean values" do
      assert Flow.go_on(true, fn _ -> {:ok, "was true"} end) == {:ok, "was true"}
      assert Flow.go_on(false, fn _ -> {:error, "was false"} end) == {:error, "was false"}
    end

    test "transforms integer values" do
      result = Flow.go_on(5, fn x -> x * 2 end)
      assert result == 10
    end

    test "transforms list values" do
      result = Flow.go_on([1, 2, 3], fn list -> Enum.sum(list) end)
      assert result == 6
    end

    test "transforms map values" do
      result = Flow.go_on(%{count: 5}, fn map -> {:ok, map.count} end)
      assert result == {:ok, 5}
    end

    test "transforms tuple values that are not terminal states" do
      # Tuples with different atoms (not :ok or :error) should be transformed
      result = Flow.go_on({:pending, "data"}, fn {_, data} -> String.upcase(data) end)
      assert result == "DATA"
    end

    test "transforms nil values" do
      result = Flow.go_on(nil, fn _ -> {:error, "was nil"} end)
      assert result == {:error, "was nil"}
    end
  end

  describe "go_on/2 in pipelines" do
    test "chains multiple operations with mixed return types" do
      result =
        true
        |> Flow.go_on(fn true -> "success" end)
        |> Flow.go_on(fn str -> {str, 0} end)
        |> Flow.go_on(fn {_, 0} -> :ok end)

      assert result == :ok
    end

    test "short-circuits on first error in chain" do
      counter = :counters.new(1, [])

      result =
        "start"
        |> Flow.go_on(fn _ -> {:error, "failed at step 1"} end)
        |> Flow.go_on(fn _ ->
          :counters.add(counter, 1, 1)
          :should_not_run
        end)
        |> Flow.go_on(fn _ ->
          :counters.add(counter, 1, 1)
          :should_not_run
        end)

      assert result == {:error, "failed at step 1"}
      assert :counters.get(counter, 1) == 0
    end

    test "short-circuits on {:ok, value} in chain" do
      counter = :counters.new(1, [])

      result =
        "start"
        |> Flow.go_on(fn _ -> {:ok, "early success"} end)
        |> Flow.go_on(fn _ ->
          :counters.add(counter, 1, 1)
          :should_not_run
        end)

      assert result == {:ok, "early success"}
      assert :counters.get(counter, 1) == 0
    end

    test "short-circuits on :ok in chain" do
      counter = :counters.new(1, [])

      result =
        "start"
        |> Flow.go_on(fn _ -> :ok end)
        |> Flow.go_on(fn _ ->
          :counters.add(counter, 1, 1)
          :should_not_run
        end)

      assert result == :ok
      assert :counters.get(counter, 1) == 0
    end

    test "simulates database operation pipeline" do
      # Simulate: check server running -> execute query -> parse result
      check_server = fn -> true end
      execute_query = fn true -> {"result_data", 0}; false -> {"error", 1} end
      parse_result = fn {_, 0} -> {:ok, "parsed"}; {msg, _} -> {:error, msg} end

      result =
        check_server.()
        |> Flow.go_on(execute_query)
        |> Flow.go_on(parse_result)

      assert result == {:ok, "parsed"}
    end

    test "simulates database operation pipeline with server not running" do
      check_server = fn -> false end
      execute_query = fn true -> {"result_data", 0}; false -> {:error, "server not running"} end

      result =
        check_server.()
        |> Flow.go_on(execute_query)
        |> Flow.go_on(fn {:ok, _} -> :ok; {:error, _} = err -> err end)

      assert result == {:error, "server not running"}
    end
  end

  describe "go_on/2 with anonymous functions" do
    test "works with multi-clause anonymous functions" do
      result =
        "input"
        |> Flow.go_on(fn
          "input" -> 1
          _ -> 0
        end)
        |> Flow.go_on(fn
          1 -> {:ok, "matched"}
          _ -> {:error, "no match"}
        end)

      assert result == {:ok, "matched"}
    end

    test "captures variables in step function" do
      multiplier = 3

      result =
        5
        |> Flow.go_on(fn x -> x * multiplier end)
        |> Flow.go_on(fn x -> {:ok, x} end)

      assert result == {:ok, 15}
    end
  end

  describe "go_on/2 edge cases" do
    test "handles empty strings" do
      result = Flow.go_on("", fn x -> "empty: #{x}" end)
      assert result == "empty: "
    end

    test "handles empty lists" do
      result = Flow.go_on([], fn _ -> :empty end)
      assert result == :empty
    end

    test "handles empty maps" do
      result = Flow.go_on(%{}, fn _ -> :empty end)
      assert result == :empty
    end

    test "handles atoms other than :ok" do
      assert Flow.go_on(:pending, fn _ -> :transformed end) == :transformed
      assert Flow.go_on(:error, fn _ -> :transformed end) == :transformed
      assert Flow.go_on(:custom_atom, fn _ -> :transformed end) == :transformed
    end

    test "step function can return any value type" do
      # Step function returns another function
      result = Flow.go_on(1, fn _ -> fn -> :nested_fn end end)
      assert is_function(result)
      assert result.() == :nested_fn
    end
  end
end
