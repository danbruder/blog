defmodule Blog.ContentImporter do
  @moduledoc """
  One-time importer for the legacy Zola markdown content bundled under
  `priv/legacy_content`. This is a small purpose-built parser for the exact
  frontmatter shapes used by that content (title/slug/date/draft/category/
  tags, with or without a `taxonomies:` wrapper) — not a general YAML parser.
  """

  alias Blog.Content

  @doc """
  Seed the legacy content into the database. Idempotent: each post/page is
  keyed by its slug, so posts that already exist are skipped and only missing
  ones are inserted. Safe to run on every boot.
  """
  def seed do
    import_all()
  end

  def import_all do
    import_dir(posts_dir(), "post")
    import_dir(notes_dir(), "note")
    import_dir(pages_dir(), "page")
    :ok
  end

  defp posts_dir, do: Path.join(:code.priv_dir(:blog), "legacy_content/posts")
  defp notes_dir, do: Path.join(:code.priv_dir(:blog), "legacy_content/notes")
  defp pages_dir, do: Path.join(:code.priv_dir(:blog), "legacy_content/pages")

  defp import_dir(dir, kind) do
    dir
    |> Path.join("*.md")
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.each(fn path ->
      attrs = parse(File.read!(path), kind, Path.basename(path, ".md"))

      if Content.get_by_slug(attrs.slug) do
        # Already seeded on a previous boot; leave it (and any edits) alone.
        :ok
      else
        case Content.create_post(attrs) do
          {:ok, _post} ->
            :ok

          {:error, changeset} ->
            raise "failed to import #{path}: #{inspect(changeset.errors)}"
        end
      end
    end)
  end

  @doc false
  def parse(contents, kind, fallback_slug) do
    case Regex.run(~r/\A---\n(.*?)\n---\n?(.*)\z/s, contents) do
      [_, frontmatter, body] ->
        meta = parse_frontmatter(frontmatter)

        %{
          title: meta[:title] || fallback_slug,
          slug: normalize_slug(meta[:slug] || fallback_slug),
          body: String.trim(body),
          kind: kind,
          published: meta[:draft] != true,
          category: meta[:category],
          tags: meta[:tags],
          published_at: meta[:date]
        }

      nil ->
        %{
          title: fallback_slug,
          slug: normalize_slug(fallback_slug),
          body: String.trim(contents),
          kind: kind,
          published: true,
          category: nil,
          tags: nil,
          published_at: nil
        }
    end
  end

  defp parse_frontmatter(text) do
    text
    |> String.split("\n")
    |> Enum.reduce(%{pending: nil, acc: %{}}, &parse_line/2)
    |> Map.fetch!(:acc)
    |> finalize()
  end

  defp parse_line(line, state) do
    trimmed = String.trim(line)

    cond do
      trimmed == "" ->
        state

      trimmed == "taxonomies:" ->
        state

      String.starts_with?(trimmed, "- ") ->
        case state.pending do
          nil ->
            state

          key ->
            item = trimmed |> String.trim_leading("- ") |> unquote_value()
            list = Map.get(state.acc, key, [])
            %{state | acc: Map.put(state.acc, key, list ++ [item])}
        end

      String.contains?(trimmed, ":") ->
        [key, raw_value] = String.split(trimmed, ":", parts: 2)
        key = String.to_atom(String.trim(key))
        value = String.trim(raw_value)

        if value == "" and key in [:category, :tags] do
          %{state | pending: key, acc: Map.put_new(state.acc, key, [])}
        else
          %{state | pending: nil, acc: Map.put(state.acc, key, parse_value(key, value))}
        end

      true ->
        state
    end
  end

  defp parse_value(key, value) when key in [:category, :tags] do
    cond do
      String.starts_with?(value, "[") ->
        value
        |> String.trim_leading("[")
        |> String.trim_trailing("]")
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.map(&unquote_value/1)
        |> Enum.reject(&(&1 == ""))

      value == "" ->
        []

      true ->
        [unquote_value(value)]
    end
  end

  defp parse_value(:date, value) do
    case Date.from_iso8601(unquote_value(value)) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_value(:draft, value), do: unquote_value(value) == "true"
  defp parse_value(_key, value), do: unquote_value(value)

  # Legacy Zola slugs occasionally contain characters (e.g. underscores) that
  # the Post changeset rejects. Normalize them to the lowercase/hyphen form.
  defp normalize_slug(slug) do
    slug
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  defp unquote_value(v) do
    v
    |> String.trim()
    |> String.trim("\"")
    |> String.trim("'")
  end

  defp finalize(acc) do
    acc
    |> Map.update(:category, nil, fn
      list when is_list(list) -> list |> Enum.reject(&(&1 == "")) |> List.first()
      other -> other
    end)
    |> Map.update(:tags, nil, fn
      list when is_list(list) ->
        case list |> Enum.reject(&(&1 == "")) |> Enum.join(", ") do
          "" -> nil
          joined -> joined
        end

      other ->
        other
    end)
  end
end
