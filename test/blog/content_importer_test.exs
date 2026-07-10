defmodule Blog.ContentImporterTest do
  use ExUnit.Case, async: true

  alias Blog.ContentImporter

  test "parses a plain post with taxonomies wrapper and inline arrays" do
    contents = """
    ---
    date: 2022-09-03
    title: How I Make Software
    slug: how-i-make-software
    draft: true
    taxonomies:
        category: []
        tags: []
    ---

    Some body text.
    """

    attrs = ContentImporter.parse(contents, "post", "fallback")

    assert attrs.title == "How I Make Software"
    assert attrs.slug == "how-i-make-software"
    assert attrs.published == false
    assert attrs.published_at == ~D[2022-09-03]
    assert attrs.category == nil
    assert attrs.tags == nil
    assert attrs.body == "Some body text."
  end

  test "parses block-style category/tags lists nested under taxonomies" do
    contents = """
    ---
    date: 2020-11-28
    title: "How to return a warp filter from a function in rust"
    slug: how-to-return-a-warp-filter-from-a-function-in-rust
    draft: false
    taxonomies:
        category:
          - Backend
        tags:
          - rust
    ---

    Body here.
    """

    attrs = ContentImporter.parse(contents, "post", "fallback")

    assert attrs.category == "Backend"
    assert attrs.tags == "rust"
    assert attrs.published == true
  end

  test "parses bare (non-taxonomies-wrapped) category and multiple tags" do
    contents = """
    ---
    date: 2018-08-13
    title: Add a twitter share link to a gatsby blog
    slug: add-a-twitter-share-link-to-a-gatsby-blog
    category: Frontend
    tags:
      - gatsby
      - twitter
    ---

    Body here.
    """

    attrs = ContentImporter.parse(contents, "post", "fallback")

    assert attrs.category == "Frontend"
    assert attrs.tags == "gatsby, twitter"
  end

  test "falls back to filename when frontmatter is missing" do
    attrs = ContentImporter.parse("just some content", "page", "my-fallback-slug")

    assert attrs.slug == "my-fallback-slug"
    assert attrs.title == "my-fallback-slug"
    assert attrs.body == "just some content"
  end

  test "ignores unrelated multi-line keys like aliases" do
    contents = """
    ---
    date: 2024-08-02
    title: "Where is Info.plist in SwiftUI project?"
    slug: where-is-info-plist-in-swiftui-project
    aliases:
      [/blog/missing-info-plist-in-swiftui-project]
    taxonomies:
        category:
          - Mobile
        tags:
          - swift-ui
    ---

    Body.
    """

    attrs = ContentImporter.parse(contents, "post", "fallback")

    assert attrs.slug == "where-is-info-plist-in-swiftui-project"
    assert attrs.category == "Mobile"
    assert attrs.tags == "swift-ui"
  end
end
