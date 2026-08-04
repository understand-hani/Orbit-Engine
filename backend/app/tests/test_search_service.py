from app.services.search_service import SearchService


ARXIV_XML = """<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <id>http://arxiv.org/abs/2601.00001v1</id>
    <updated>2026-01-01T00:00:00Z</updated>
    <published>2026-01-01T00:00:00Z</published>
    <title>Mock World Model Paper</title>
    <summary> A mock summary. </summary>
    <author><name>Alice</name></author>
    <category term="cs.CV" />
    <link title="pdf" href="http://arxiv.org/pdf/2601.00001v1" />
  </entry>
</feed>
"""


def test_parse_arxiv_atom():
    items = SearchService()._parse_arxiv(ARXIV_XML)
    assert len(items) == 1
    assert items[0].item_type == "paper"
    assert items[0].title == "Mock World Model Paper"
    assert items[0].extra["pdf_url"].endswith("2601.00001v1")


def test_parse_github_repositories():
    payload = {
        "items": [
            {
                "id": 1,
                "full_name": "owner/repo",
                "html_url": "https://github.com/owner/repo",
                "description": "mock repo",
                "updated_at": "2026-01-01T00:00:00Z",
                "topics": ["world-model"],
                "stargazers_count": 100,
                "forks_count": 10,
                "language": "Python",
            }
        ]
    }
    items = SearchService()._parse_github_repositories(payload)
    assert len(items) == 1
    assert items[0].item_type == "repo"
    assert items[0].extra["stars"] == 100
