from okf_links import extract_all, resolve_link, rewrite_wikilinks


def test_extract_markdown_and_wikilinks():
    text = "See [a](concepts/a.md) and [[b|B label]] and [[c]]."
    links = extract_all(text)
    targets = {link.target: link.kind for link in links}
    assert targets["concepts/a.md"] == "markdown"
    assert targets["b"] == "wikilink"
    assert targets["c"] == "wikilink"


def test_external_links_ignored_for_resolution():
    text = "[Google](https://google.com)"
    links = extract_all(text)
    assert links[0].is_external() is True


def test_resolve_relative_markdown_link():
    existing = {"concepts/frigate-nvr", "entities/vaultwarden"}
    from okf_links import Link

    link = Link(raw="", target="../entities/vaultwarden.md", kind="markdown", label="V")
    assert resolve_link(link, "concepts/frigate-nvr", existing) == "entities/vaultwarden"


def test_resolve_wikilink_case_insensitive():
    existing = {"concepts/Frigate NVR"}
    from okf_links import Link

    link = Link(raw="", target="Frigate NVR", kind="wikilink", label="F")
    assert resolve_link(link, "index", existing) == "concepts/Frigate NVR"


def test_rewrite_wikilink_same_directory():
    existing = {"concepts/frigate-nvr", "concepts/bluefin"}
    text = "See [[concepts/bluefin|Bluefin]] for details."
    assert rewrite_wikilinks(text, "concepts/frigate-nvr", existing) == "See [Bluefin](bluefin.md) for details."


def test_rewrite_wikilink_cross_directory():
    existing = {"concepts/frigate-nvr", "entities/vaultwarden"}
    text = "Auth via [[entities/vaultwarden]]."
    assert rewrite_wikilinks(text, "concepts/frigate-nvr", existing) == "Auth via [vaultwarden](../entities/vaultwarden.md)."


def test_rewrite_unresolved_wikilink_unchanged():
    existing = {"concepts/frigate-nvr"}
    text = "See [[Missing Concept]]."
    assert rewrite_wikilinks(text, "concepts/frigate-nvr", existing) == "See [[Missing Concept]]."


def test_rewrite_markdown_link_unchanged():
    existing = {"concepts/bluefin"}
    text = "See [Bluefin](concepts/bluefin.md)."
    assert rewrite_wikilinks(text, "index", existing) == "See [Bluefin](concepts/bluefin.md)."
