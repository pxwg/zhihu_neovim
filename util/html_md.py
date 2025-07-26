import sys
import re
from bs4 import BeautifulSoup


def html_to_md(html_file_path: str) -> str:
    """
    Convert HTML content from a file to Markdown with specific rules.
    Args:
        html_file_path (str): The path to the HTML file to convert.
    Returns:
        str: The converted Markdown content.
    """
    try:
        with open(html_file_path, "r", encoding="utf-8") as file:
            html_content = file.read()
    except FileNotFoundError:
        raise FileNotFoundError(f"File not found: {html_file_path}")

    soup = BeautifulSoup(html_content, "html.parser")
    footnotes = {}

    for code in soup.find_all("code"):
        # Skip code tags inside pre tags (they're handled separately)
        if code.parent and code.parent.name == "pre":
            continue

        # Convert inline code to `code`
        code_text = code.get_text()
        md_code = f"`{code_text}`"
        code.replace_with(md_code)

    # Convert math images to $formula$ or $$formula$$
    for img in soup.find_all("img", class_="ztext-math"):
        alt = img.get("data-tex", "").strip()
        if alt.endswith("\\\\"):
            # Display math (block)
            md_math = f"\n\n$$\n {alt[:-2]}\n$$\n\n"
        else:
            # Inline math (no extra spacing)
            md_math = f"$ {alt} $"
        img.replace_with(md_math)

    for span in soup.find_all("span", class_="ztext-math"):
        tex = span.get("data-tex", "").strip()
        if tex.endswith("\\\\"):
            # Display math (block)
            md_math = f"\n\n$$\n {tex[:-2]}\n$$\n\n"
        else:
            # Inline math (no extra spacing)
            md_math = f"$ {tex} $"
        span.replace_with(md_math)

    # Convert ordered and unordered lists to Markdown lists
    def convert_list_items(tag, prefix="* ", start=1):
        md_list = ""
        counter = start
        for li in tag.find_all("li", recursive=False):
            content = li.get_text(strip=True)
            if prefix.startswith("1. "):
                md_list += f"{counter}. {content}\n"
                counter += 1
            else:
                md_list += f"{prefix}{content}\n"
            # Handle nested lists
            for child in li.find_all(["ul", "ol"], recursive=False):
                if child.name == "ul":
                    nested_prefix = "  * "
                    md_list += convert_list_items(child, prefix=nested_prefix)
                elif child.name == "ol":
                    md_list += convert_list_items(child, prefix="  1. ", start=1)
        return md_list

    for ul in soup.find_all("ul"):
        md_ul = convert_list_items(ul, prefix="- ")
        ul.replace_with(md_ul)

    for ol in soup.find_all("ol"):
        md_ol = convert_list_items(ol, prefix="1. ", start=1)
        ol.replace_with(md_ol)

    # Convert <pre> with lang attribute to ```language code blocks
    for pre in soup.find_all("pre"):
        lang = pre.get("lang", "")
        code = pre.text.strip()
        md_code_block = f"\n\n```{lang}\n{code}\n```\n\n"
        pre.replace_with(md_code_block)

    # Convert HTML tables to Markdown tables
    for table in soup.find_all("table"):
        rows = table.find_all("tr")
        if not rows:
            continue

        header_cells = rows[0].find_all(["th", "td"])
        headers = [cell.get_text(strip=True) for cell in header_cells]
        md_table = f"\n\n| {' | '.join(headers)} |\n"
        md_table += f"| {' | '.join(['-----'] * len(headers))} |\n"

        for row in rows[1:]:
            cells = row.find_all(["td", "th"])
            cell_texts = [cell.get_text(strip=True) for cell in cells]
            md_table += f"| {' | '.join(cell_texts)} |\n"

        table.replace_with(md_table + "\n\n")

    # Convert <figure> containing <img> and <figcaption> to Markdown images
    for figure in soup.find_all("figure"):
        img = figure.find("img")
        figcaption = figure.find("figcaption")
        if img:
            src = img.get("src", "")
            alt = figcaption.get_text(strip=True) if figcaption else ""
            md_image = f"\n\n![{alt}]({src})\n\n"
            figure.replace_with(md_image)

    # Convert headings to Markdown with consistent spacing
    for heading in soup.find_all(["h1", "h2", "h3", "h4", "h5", "h6"]):
        level = int(heading.name[1])
        md_heading = f"\n\n{'#' * (level - 1)} {heading.get_text(strip=True)}\n\n"
        heading.replace_with(md_heading)

    # Convert <sup data-numero="...">[1]</sup> to footnotes
    for sup in soup.find_all("sup"):
        if sup.get("data-numero") and re.match(r"^$$\d+$$$", sup.get_text(strip=True)):
            numero = sup["data-numero"]
            text = sup.get("data-text", "")
            url = sup.get("data-url", "")
            footnotes[numero] = f"{text} {url}"
            sup.replace_with(f"[^{numero}]")

    # Ensure <pre><code> blocks are placed on separate lines
    for pre in soup.find_all("pre"):
        code = pre.find("code")
        if code:
            lang = code.get("class", ["language-text"])[0].replace("language-", "")
            code_content = (
                code.get_text()
            )  # Don't strip to preserve internal formatting
            md_code_block = f"\n\n```{lang}\n{code_content}\n```\n\n"
            pre.replace_with(md_code_block)

    # Convert <blockquote> to Markdown blockquote and ensure separation
    for blockquote in soup.find_all("blockquote"):
        lines = blockquote.get_text().strip().split("\n")
        md_blockquote = "\n\n"
        for line in lines:
            md_blockquote += f"> {line}\n"
        md_blockquote += "\n"
        blockquote.replace_with(md_blockquote)

    # Convert <br> tags to newline characters in text content
    for br in soup.find_all("br"):
        if br.parent and br.parent.name not in ["h1", "h2", "h3", "h4", "h5", "h6"]:
            br.replace_with("\n")

    # Convert links
    for link in soup.find_all("a"):
        text = link.get_text(strip=True).replace("#", "\\#")
        href = link.get("href", "")
        md_link = f"[{text}]({href})"
        link.replace_with(md_link)

    # Convert <p> tags to Markdown paragraphs with proper formatting
    for p in soup.find_all("p"):
        md_paragraph = "\n\n"  # Start with newlines for spacing
        for child in p.children:
            if child.name == "i":  # Convert <i> to Markdown italic
                md_paragraph += f"*{child.get_text(strip=True)}*"
            elif child.name == "b":  # Convert <b> to Markdown bold
                md_paragraph += f"**{child.get_text(strip=True)}**"
            elif child.name == "a":  # Convert <a> to Markdown links
                href = child.get("href", "")
                text = child.get_text(strip=True)
                md_paragraph += f"[{text}]({href})"
            elif child.name == "br":  # Convert <br> to newline within paragraph
                md_paragraph += "\n"
            else:  # Handle plain text
                md_paragraph += child if isinstance(child, str) else child.get_text()
        md_paragraph += "\n\n"  # End with newlines for spacing
        p.replace_with(md_paragraph)

    # Convert remaining HTML to Markdown
    markdown = soup.get_text()

    # Clean up excessive newlines (more than 2 consecutive newlines)
    markdown = re.sub(r"\n{3,}", "\n\n", markdown)

    # Ensure proper spacing for inline math formulas
    markdown = re.sub(r"\n\n\$(.*?)\$\n\n", r" $\1$ ", markdown)

    # Append footnotes at the end with proper spacing
    if footnotes:
        footnote_entries = "\n\n" + "\n".join(
            [f"[^{num}]: {text}" for num, text in footnotes.items()]
        )
        markdown += footnote_entries

    return markdown.strip()


def main():
    if len(sys.argv) != 2:
        print(
            "Usage: python html_md.py <html_file_path>",
            file=sys.stderr,
        )
        sys.exit(1)
    try:
        html_file_path = sys.argv[1]
        markdown_content = html_to_md(html_file_path)
        print(markdown_content)  # Output Markdown content to stdout
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
