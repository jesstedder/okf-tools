from okf_links import extract_all, resolve_link


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
