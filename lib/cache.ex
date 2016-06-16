defmodule Cache do
  @moduledoc """
  Functions for manipulating and maintaining the marshal decode caches
  """

  @doc """
  Add a symbol to the cache.
  """
  def add_to_symbol_cache(symbol, {symbol_cache, object_cache}) do
    {add_to_cache(symbol, symbol_cache), object_cache}
  end

  @doc """
  Add an object to the cache.
  """
  def add_to_object_cache(object, {symbol_cache, object_cache}) do
    {symbol_cache, add_to_cache(object, object_cache)}
  end

  @doc """
  Replace an object stored in the cache. Used for replacing a placeholder with a real value.
  """
  def replace_object_cache(old, new, {symbol_cache, object_cache}) do
    ref = object_cache[old]

    object_cache =
      object_cache
      |> Map.delete(old)
      |> Map.put(new, ref)

    {symbol_cache, object_cache}
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
  """
  def fetch_symbol(bitstring, index, {symbol_cache, _object_cache} = cache) do
    {atom, rest} = fetch_from_cache(bitstring, index, symbol_cache)
    {atom, rest, cache}
  end

  @doc """
  Retrieve an object from the cache for a type link.
  """
  def fetch_object(bitstring, index, {_symbol_cache, object_cache} = cache) do
    {atom, rest} = fetch_from_cache(bitstring, index, object_cache)
    {atom, rest, cache}
  end

  defp fetch_from_cache(bitstring, index, cache) do
    # Retrieve element
    {element, _} = Enum.find(cache, fn({_, i}) -> i == index end)
    {element, bitstring}
  end
end
