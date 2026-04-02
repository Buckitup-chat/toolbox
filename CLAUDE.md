# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Toolbox is a utility library providing common patterns and helpers for Elixir projects in the BuckitUp monorepo. It contains three main modules:

- **Toolbox.OriginLog**: Macro for automatic log prefixing based on module names
- **Toolbox.Flow**: Railway-oriented programming helper (`go_on/2`) for clean pipelines with mixed return types
- **Toolbox.GenServerHelpers**: Response tuple builders for GenServer callbacks

## Commands

```bash
# Testing
mix test                     # Run all tests
mix test path/to/test.exs    # Single test file
mix test path/to/test.exs:42 # Specific line

# Code quality
mix format                   # Format code
mix compile --warnings-as-errors  # Strict compilation
```

## Architecture

### Toolbox.OriginLog

A macro module that injects a `log/2` function into using modules. The function automatically prefixes log messages with the module name in bracket format:

```elixir
defmodule Platform.Storage.Logic do
  use Toolbox.OriginLog

  def some_function do
    log("Processing data", :info)
    # Logs: [_Platform.Storage.Logic_] Processing data
  end
end
```

Key functions:
- `generate_prefix/1`: Converts module name to bracketed prefix
- `normalize_iolist/1`: Handles various iolist formats (binaries, charlists, nested lists)

### Toolbox.Flow

Implements railway-oriented programming with `go_on/2`. Enables sequential operations with heterogeneous return types and automatic error propagation.

**Terminal states (short-circuit):**
- `{:error, _}` - Propagates unchanged
- `{:ok, _}` - Propagates unchanged
- `:ok` - Propagates unchanged

**Non-terminal states (transform):**
- Any other value is passed through the step function

Example usage:
```elixir
true
|> Flow.go_on(fn true -> "success" end)
|> Flow.go_on(fn str -> {str, 0} end)
|> Flow.go_on(fn {_, 0} -> :ok end)
# => :ok
```

Used in production for database operation pipelines (e.g., `Platform.Tools.Postgres.Database`).

### Toolbox.GenServerHelpers

Simple response tuple builders for GenServer callbacks:
- `ok/1`, `noreply/1`, `reply/2`
- `ok_continue/2`, `noreply_continue/2`, `reply_continue/3`

## Tech Stack

- **Elixir 1.18** (no external dependencies)
- Standard library only (Logger, ExUnit)
