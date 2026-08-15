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


def test_parse_bocha_web_pages_keeps_broad_news_result_metadata():
    payload = {
        "data": {
            "webPages": {
                "value": [
                    {
                        "name": "某企业发布新一代世界模型产品",
                        "url": "https://news.example.com/product-launch",
                        "summary": "企业发布了面向开发者的新产品。",
                        "siteName": "示例科技媒体",
                        "datePublished": "2026-08-15T10:00:00Z",
                    },
                    {
                        "name": "高校研究团队公布具身智能新进展",
                        "url": "https://news.example.com/lab-progress",
                    },
                ]
            }
        }
    }

    items = SearchService()._parse_bocha_web_pages(payload, max_results=5)

    assert [item.title for item in items] == [
        "某企业发布新一代世界模型产品",
        "高校研究团队公布具身智能新进展",
    ]
    assert all(item.source.value == "web" for item in items)
    assert all(item.item_type.value == "article" for item in items)
    assert all("bocha_web" in item.tags for item in items)
    assert items[0].summary == "企业发布了面向开发者的新产品。"
    assert items[0].extra["publisher"] == "示例科技媒体"
