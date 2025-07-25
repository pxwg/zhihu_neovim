import re
import json
import sys
import mistune
import html as html_core
from mistune.plugins.math import math
from bs4 import BeautifulSoup


def md_to_html(md_content: str) -> str:
    """
      Convert Markdown content to HTML with specific formatting for Zhihu platform.
    Args:
      md_content (str): The Markdown content to convert.
    Returns:
      str: The converted HTML content.
    """
    renderer = mistune.HTMLRenderer()
    markdown = mistune.Markdown(renderer, plugins=[math])
    html = markdown(md_content)
    soup = BeautifulSoup(html, "html.parser")

    for link in soup.find_all("a"):
        title = link.get("title", "")
        href = link.get("href", "")
        if title == "card":
            link["data-draft-node"] = "block"
            link["data-draft-type"] = "link-card"
        elif title.startswith("member_mention"):
            hash_value = str(title).replace("member_mention_", "")
            people_id = href.replace("https://www.zhihu.com/people/", "")
            link["class"] = "member_mention"
            link["href"] = f"/people/{people_id}"
            link["data-hash"] = hash_value

    for img in soup.find_all("img"):
        if img.get("alt") == "math":
            eq = str(img.get("src", "")).replace("tex=", "")
            img["eeimg"] = "1"
            img["src"] = f"//www.zhihu.com/equation?tex={eq}"
            img["alt"] = eq.replace("\n", " ")

    # Handle inline math ($xxx$) and block math ($$xxx$$)
    for span in soup.find_all("span", class_="math"):
        eq = re.sub(r"^\\\(|\\\)$", "", span.text)
        img_tag = soup.new_tag(
            "img", eeimg="1", src=f"//www.zhihu.com/equation?tex={eq}", alt=eq
        )
        span.replace_with(img_tag)

    for div in soup.find_all("div", class_="math"):
        eq = str(div.text).strip(r"$$").strip("\n") + "\\\\"
        img_tag = soup.new_tag(
            "img", eeimg="1", src=f"//www.zhihu.com/equation?tex={eq}", alt=eq
        )
        div.replace_with(img_tag)

    for pre in soup.find_all("pre"):
        lang = pre.get("lang", "")
        pre["lang"] = lang

    for table in soup.find_all("table"):
        table["data-draft-node"] = "block"
        table["data-draft-type"] = "table"
        table["data-size"] = "normal"

    for sup in soup.find_all("sup"):
        if sup.get("data-numero"):
            sup["data-draft-node"] = "inline"
            sup["data-draft-type"] = "reference"

    for heading in soup.find_all(["h1", "h2", "h3"]):
        heading["style"] = "display: inline;"
        if heading.name == "h1":
            heading.name = "h2"
        elif heading.name == "h2":
            heading.name = "h3"
        else:
            strong_tag = soup.new_tag("strong")
            strong_tag.string = heading.text.strip()
            heading.clear()
            heading.append(strong_tag)
            heading.name = "p"

    for blockquote in soup.find_all("blockquote"):
        if blockquote.get("data-callout-type") in ["ignore", "忽略", "注释"]:
            blockquote.clear()
            blockquote.name = "p"

    # HACK: HTML in Zhihu is a mess, we need to clean it up by: 1. Replacing all the newlines with <br> 2. Not use <p> tags 3. Not use <br> tags after <h1>, <h2>, <h3> tags and <blockquote> tags
    result = []

    for element in soup.contents:
        if isinstance(element, str):
            if element.strip():
                result.append(element.replace("\n", "<br>"))
        elif element.name in ["h1", "h2", "h3"]:
            result.append(str(element))
            # result.append("<br>") # Not adding <br> after headings
        elif element.name == "blockquote":
            result.append(f"<blockquote>{element.text.strip()}</blockquote>")
            for li in element.find_all("li", recursive=False):
                # For blockquote with lists, we want to preserve the list items but not the <br> tag
                list_content += f"<li>{li.text.strip()}</li>"
                result.append(f"<{element.name}>{list_content}</{element.name}>")
        elif element.name == "p":
            # For paragraphs, we want to preserve the content but not the p tags
            inner_content = "".join(str(child) for child in element.contents)
            result.append(inner_content)
            result.append("<br>")
        else:
            result.append(str(element))

    result_string = "".join(result).replace("\n", "<br>")
    return result_string


def convert_md_to_html(md_content: str) -> str:
    try:
        return md_to_html(md_content)
    except Exception as e:
        raise RuntimeError(f"Convertion Failed: {e}")


def test(md_filepath: str) -> str:
    """
    Test function to read a Markdown file and convert it to HTML.
    :param md_filepath: Path to the Markdown file.
    :return: Converted HTML content.
    """
    try:
        with open(md_filepath, "r", encoding="utf-8") as file:
            md_content = file.read()
        return md_to_html(md_content)
    except Exception as e:
        raise RuntimeError(f"Test Failed: {e}")


if __name__ == "__main__":
    try:
        input_data = json.loads(sys.stdin.read())
        md_content = input_data.get("markdown", {})
        content = "\n".join(md_content.get("content", [""]))
        title = md_content.get("title", "")

        if not content or not title:
            raise ValueError(
                "Invalid input: 'content' and 'title' fields are required in 'markdown'."
            )

        html_output = convert_md_to_html(content).replace("\n", "<br>")
        print(json.dumps({"content": html_output, "title": title}))
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)
