defmodule Cache do
  @moduledoc """
  Functions for manipulating and maintaining the marshal decode caches
  """

  @doc """
  Add a symbol to the cache.

  # Examples

      iex> Cache.add_to_symbol_cache(:test, {%{}, %{}})
      {%{test: 0}, %{}}
  """
  def add_to_symbol_cache(symbol, {symbol_cache, object_cache}) do
    {add_to_cache(symbol, symbol_cache), object_cache}
  end

  @doc """
  Add an object to the cache.

  # Examples

      iex> Cache.add_to_object_cache(%{1 => 2}, {%{}, %{}})
      {%{}, %{%{1 => 2} => 0}}
  """
  def add_to_object_cache(object, {symbol_cache, object_cache}) do
    {symbol_cache, add_to_cache(object, object_cache)}
  end

  @doc """
  Replace an symbol stored in the cache. Used for updating a symbol with ivars.

  # Examples

      iex> Cache.replace_symbol_cache(:test, :test_update, {%{:test => 0}, %{}})
      {%{:test_update => 0}, %{}}
  """
  def replace_symbol_cache(old, new, {symbol_cache, object_cache}) do
    symbol_cache = replace_cache(old, new, symbol_cache)

    {symbol_cache, object_cache}
  end

  @doc """
  Replace an object stored in the cache. Used for replacing a placeholder with a real value.

  # Examples

      iex> Cache.replace_object_cache(<<0xFF>>, "test", {%{}, %{<<0>> => 0, <<0xFF>> => 1}})
      {%{}, %{<<0>> => 0, "test" => 1}}
  """
  def replace_object_cache(old, new, {symbol_cache, object_cache}) do
    object_cache = replace_cache(old, new, object_cache)

    {symbol_cache, object_cache}
  end

  defp replace_cache(old, new, cache) do
    ref = cache[old]

    cache
    |> Map.delete(old)
    |> Map.put(new, ref)
  end

  @doc """
  Replace the last object stored in the cache.

  # Examples

      iex> Cache.replace_last_object("test", {%{}, %{<<0>> => 0, <<0xFF>> => 1}})
      {%{}, %{<<0>> => 0, "test" => 1}}
  """
  def replace_last_object(new, {symbol_cache, object_cache}) do
    object_cache = replace_last(new, object_cache)

    {symbol_cache, object_cache}
  end


  defp replace_last(new, cache) do
    {key, val} =
      cache
      |> Enum.max_by(fn {_key, val} -> val end)

    cache
    |> Map.delete(key)
    |> Map.put(new, val)
  end

  # Add to cache if ref isn't already there
  defp add_to_cache(element, cache) do
    Map.put_new_lazy(cache, element, fn -> get_next_index(cache) end)
  end

  defp get_next_index(cache), do: do_get_next_index(Map.values(cache))

  defp do_get_next_index([]), do: 0
  defp do_get_next_index(indices), do: indices |> Enum.max() |> increment()

  defp increment(value), do: value + 1

  @doc """
  Retrieve a symbol from the cache for a symlink reference.

  # Examples

      iex> Cache.fetch_symbol(1, {%{apple: 0, banana: 1}, %{["test"] => 0, "test" => 1}})
      :banana
  """
  def fetch_symbol(index, {symbol_cache, _object_cache}) do
    fetch_from_cache(index, symbol_cache)
  end

  @doc """
  Retrieve an object from the cache for a type link.

  # Examples

      iex> Cache.fetch_object(1, {%{apple: 0, banana: 1}, %{["test"] => 0, "test" => 1}})
      "test"
  """
  def fetch_object(index, {_symbol_cache, object_cache}) do
    fetch_from_cache(index, object_cache)
  end

  defp fetch_from_cache(index, cache) do
    cache
    |> Enum.find(fn({_, i}) -> i == index end)
    |> elem(0)
  end
end
