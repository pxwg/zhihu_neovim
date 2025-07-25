import sys
import re
from bs4 import BeautifulSoup


def html_to_md(html_content: str) -> str:
    """
    Convert HTML content to Markdown with specific rules.
    Args:
        html_content (str): The HTML content to convert.
    Returns:
        str: The converted Markdown content.
    """
    soup = BeautifulSoup(html_content, "html.parser")
    footnotes = {}

    # Rule 1: Convert math images to $formula$ or $$formula$$
    for img in soup.find_all("img", class_="ztext-math"):
        alt = img.get("data-tex", "").strip()
        if alt.endswith("\\\\"):
            md_math = f"$$ {alt[:-2]} $$"
        else:
            md_math = f"$ {alt} $"
        img.replace_with(md_math)

    # Rule 2: Convert <pre> with lang attribute to ```language code blocks
    for pre in soup.find_all("pre"):
        lang = pre.get("lang", "")
        code = pre.text.strip()
        md_code_block = f"```{lang}\n{code}\n```"
        pre.replace_with(md_code_block)

    # Rule 3: Convert HTML tables to Markdown tables
    for table in soup.find_all("table"):
        rows = table.find_all("tr")
        if not rows:
            continue

        header_cells = rows[0].find_all(["th", "td"])
        headers = [cell.get_text(strip=True) for cell in header_cells]
        md_table = f"| {' | '.join(headers)} |\n"
        md_table += f"| {' | '.join(['-----'] * len(headers))} |\n"

        for row in rows[1:]:
            cells = row.find_all(["td", "th"])
            cell_texts = [cell.get_text(strip=True) for cell in cells]
            md_table += f"| {' | '.join(cell_texts)} |\n"

        table.replace_with(md_table)

    # Rule 4: Convert <figure> containing <img> and <figcaption> to Markdown images
    for figure in soup.find_all("figure"):
        img = figure.find("img")
        figcaption = figure.find("figcaption")
        if img:
            src = img.get("src", "")
            alt = figcaption.get_text(strip=True) if figcaption else ""
            md_image = f"![{alt}]({src})"
            figure.replace_with(md_image)

    # Rule 5: Ignore <br> tags inside heading tags
    for br in soup.find_all("br"):
        if br.parent and br.parent.name in ["h1", "h2", "h3", "h4", "h5", "h6"]:
            br.extract()

    # Rule 6: Convert <sup data-numero="...">[1]</sup> to footnotes
    for sup in soup.find_all("sup"):
        if sup.get("data-numero") and re.match(r"^\[\d+\]$", sup.get_text(strip=True)):
            numero = sup["data-numero"]
            text = sup.get("data-text", "")
            url = sup.get("data-url", "")
            footnotes[numero] = f"{text} {url}"
            sup.replace_with(f"[^{numero}]")

    # Rule 7: Escape `#` in plain text and link text
    for text_node in soup.find_all(string=True):
        if "#" in text_node:
            text_node.replace_with(text_node.replace("#", "\\#"))

    for link in soup.find_all("a"):
        text = link.get_text(strip=True).replace("#", "\\#")
        href = link.get("href", "")
        md_link = f"[{text}]({href})"
        link.replace_with(md_link)

    # Convert remaining HTML to Markdown
    markdown = soup.get_text()

    # Append footnotes at the end
    if footnotes:
        footnote_entries = "\n".join(
            [f"[^{num}]: {text}" for num, text in footnotes.items()]
        )
        markdown += f"\n\n{footnote_entries}"

    return markdown


def main():
    if len(sys.argv) != 2:
        print("Usage: python html_to_md_cli.py <htmlcontent>", file=sys.stderr)
        sys.exit(1)
    try:
        html_content = sys.argv[1]
        markdown_content = html_to_md(html_content)
        print(markdown_content)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
