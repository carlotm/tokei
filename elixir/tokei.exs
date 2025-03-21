defmodule Tokei do
  @exclude_dirs ~w(_build deps installer priv/templates)

  def run do
    find_files()
    |> Enum.map(fn path -> Task.async(fn -> parse_file(path) end) end)
    |> Enum.map(&Task.await/1)
    |> List.flatten()
    |> Enum.sort_by(fn({_, _, _, l}) -> l end, :asc)
    |> IO.inspect(limit: :infinity)
  end

  defp parse_file(path) do
    path
    |> File.read!()
    |> Code.string_to_quoted!()
    |> Macro.prewalk([], &parse_pre(&1, &2, path))
    |> elem(1)
  end

  defp parse_pre({:def, meta, [{name, _, _}, body]} = node, acc, path) do
    line_start = meta[:line]
    {_, line_end} = find_end(body, line_start)
    length = line_end - line_start
    {node, [{path, fun_name(name), line_start, length} | acc]}
  end

  defp parse_pre(node, acc, _), do: {node, acc}

  defp fun_name({name, _, _}), do: name
  defp fun_name(name), do: name

  defp find_end(ast, start) do
    Macro.prewalk(ast, start, fn
      ({:def, _, _} = node, acc) ->
        {node, acc}

      ({_, meta, _} = node, acc) ->
        last_line = max(acc, meta[:line] || acc)
        {node, last_line}

      (node, acc) -> {node, acc}
    end)
  end

  defp find_files do
    "**/*.ex"
    |> Path.wildcard()
    |> Enum.filter(&valid_path/1)
  end

  defp valid_path(path) do
    @exclude_dirs
    |> Enum.map(&String.starts_with?(path, &1))
    |> Enum.any?() == false
  end
end

Tokei.run()
