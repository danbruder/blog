defmodule BlogWeb.SeaWorld do
  @moduledoc """
  Derives the archipelago for the Sea easter egg: one island per significant
  public route. Home (`/`) is the harbor at the origin; section index pages and
  every published post/note get an island. Positions are deterministic (a stable
  hash of the path) and clustered by section so the layout is the same for
  everyone and stable across reloads. Publishing a post automatically adds an
  island the next time the page loads.
  """

  alias Blog.Content

  # Section index islands and the order/angle each section's cluster sits at.
  @sections [
    {"harbor", "/", "Harbor"},
    {"writing", "/writing", "Writing"},
    {"notes", "/notes", "Notes"},
    {"podcasts", "/podcasts", "Podcasts"},
    {"projects", "/projects", "Projects"},
    {"games", "/games", "Games"}
  ]

  # Extra fixed islands that aren't posts and aren't section indexes.
  @extra [
    {"games", "/games/snake", "Snake"},
    {"games", "/games/sand", "Falling Sand"}
  ]

  @type island :: %{
          path: String.t(),
          title: String.t(),
          section: String.t(),
          x: float(),
          z: float(),
          color: String.t()
        }

  @spec islands() :: [island()]
  def islands do
    fixed =
      Enum.map(@sections, fn {section, path, title} -> {section, path, title, section} end) ++
        Enum.map(@extra, fn {section, path, title} -> {section, path, title, section} end)

    posts =
      Enum.map(Content.list_published_posts(), fn p ->
        {"writing", "/blog/#{p.slug}", p.title, color_key(p, "writing")}
      end)

    notes =
      Enum.map(Content.list_published_notes(), fn p ->
        {"notes", "/notes/#{p.slug}", p.title, color_key(p, "notes")}
      end)

    (fixed ++ posts ++ notes)
    |> Enum.map(fn {section, path, title, color} ->
      {x, z} = position(section, path)
      %{path: path, title: title, section: section, x: x, z: z, color: color}
    end)
  end

  # Colors are keyed off the post's category, falling back to its first tag,
  # then the section name — the client hashes this key into a themed color, so
  # posts about the same topic cluster visually.
  defp color_key(post, fallback) do
    cond do
      present?(post.category) -> post.category
      first_tag = present_tag(post.tags) -> first_tag
      true -> fallback
    end
  end

  defp present?(nil), do: false
  defp present?(s), do: String.trim(s) != ""

  defp present_tag(nil), do: nil

  defp present_tag(tags) do
    case tags |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == "")) do
      [first | _] -> first
      [] -> nil
    end
  end

  # Harbor sits dead center; everything else is placed in its section's angular
  # sector, pushed out to a radius derived from a stable hash of the path.
  defp position("harbor", "/"), do: {0.0, 0.0}

  defp position(section, path) do
    sector = section_angle(section)
    # Deterministic spread within the sector.
    h = :erlang.phash2(path)
    jitter = rem(h, 40) / 40 * 0.7 - 0.35
    angle = sector + jitter
    radius = 45 + rem(div(h, 40), 8) * 26 + rem(div(h, 320), 5) * 6
    {Float.round(radius * :math.cos(angle), 2), Float.round(radius * :math.sin(angle), 2)}
  end

  defp section_angle(section) do
    idx =
      @sections
      |> Enum.map(fn {s, _, _} -> s end)
      |> Enum.find_index(&(&1 == section)) || 0

    idx * (2 * :math.pi() / length(@sections))
  end
end
