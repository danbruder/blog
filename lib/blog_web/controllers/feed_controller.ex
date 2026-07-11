defmodule BlogWeb.FeedController do
  @moduledoc """
  Serves the RSS feed (at /rss.xml and /feed.xml) and the XML sitemap.
  Both are built as plain XML strings and sent directly, bypassing the
  HTML layout.
  """
  use BlogWeb, :controller

  alias Blog.Content

  def rss(conn, _params) do
    xml = build_rss(Content.list_published_posts())

    conn
    |> put_resp_content_type("application/rss+xml")
    |> send_resp(200, xml)
  end

  def sitemap(conn, _params) do
    xml = build_sitemap(Content.list_published_posts())

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, xml)
  end

  # /atom.xml historically 404'd; keep the URL alive by pointing it at the RSS feed.
  def atom(conn, _params) do
    conn
    |> put_status(:moved_permanently)
    |> redirect(to: ~p"/rss.xml")
  end

  defp base_url, do: BlogWeb.Endpoint.url()

  defp build_rss(posts) do
    items = Enum.map_join(posts, "\n", &rss_item/1)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/" xmlns:atom="http://www.w3.org/2005/Atom">
      <channel>
        <title>Dan Bruder</title>
        <link>#{base_url()}/</link>
        <atom:link href="#{base_url()}/rss.xml" rel="self" type="application/rss+xml" />
        <description>Notes on software, engineering management, and side projects.</description>
        <language>en</language>
    #{items}
      </channel>
    </rss>
    """
  end

  defp rss_item(post) do
    link = "#{base_url()}/blog/#{post.slug}"

    """
        <item>
          <title>#{escape(post.title)}</title>
          <link>#{link}</link>
          <guid isPermaLink="true">#{link}</guid>
    #{pub_date(post.published_at)}    <content:encoded><![CDATA[#{Content.render_body(post)}]]></content:encoded>
        </item>
    """
  end

  defp pub_date(nil), do: ""

  defp pub_date(%Date{} = date) do
    dt = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    "      <pubDate>#{Calendar.strftime(dt, "%a, %d %b %Y %H:%M:%S +0000")}</pubDate>\n"
  end

  defp build_sitemap(posts) do
    urls = ["#{base_url()}/" | Enum.map(posts, &"#{base_url()}/blog/#{&1.slug}")]
    body = Enum.map_join(urls, "\n", &"  <url><loc>#{&1}</loc></url>")

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{body}
    </urlset>
    """
  end

  defp escape(nil), do: ""

  defp escape(string) do
    string
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end
end
