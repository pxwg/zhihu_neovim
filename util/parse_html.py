import sys
import json
from bs4 import BeautifulSoup


def parse_html(html_content, article_id=""):
    soup = BeautifulSoup(html_content, "html.parser")
    content_ele = soup.select_one(".RichText.ztext")
    writer_info_ele = soup.select_one(".AuthorInfo-name .UserLink-link")
    question_title_ele = soup.select_one("title[data-rh='true']")

    if content_ele and writer_info_ele and question_title_ele:
        writer_name = writer_info_ele.get_text(strip=True) or "知乎用户"
        title = question_title_ele.get_text(strip=True) or f"知乎文章{article_id}"
        content = content_ele.get_text(strip=True)
        return {"title": title, "content": content, "writer_name": writer_name}
    else:
        return {"title": "", "content": "", "writer_name": ""}


def main():
    if len(sys.argv) != 2:
        print("Usage: python parse_html.py <html_file_path>", file=sys.stderr)
        sys.exit(1)
    try:
        html_file_path = sys.argv[1]
        with open(html_file_path, "r", encoding="utf-8") as f:
            html_content = f.read()
        result = parse_html(html_content)
        print(json.dumps(result, ensure_ascii=False))
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
