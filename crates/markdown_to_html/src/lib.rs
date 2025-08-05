use mlua::{Lua, Result};
use pulldown_cmark::{html, CodeBlockKind, CowStr, Event, Options, Parser, Tag, TagEnd};

fn markdown_to_html(input: &str, options: Options) -> String {
    let parser = Parser::new_ext(input, options);

    let mut in_code_block = false;
    let parser = parser.map(|event| {
        match event {
            // Pure equation with only a single line
            Event::InlineMath(text) => {
                let eq = text.to_string().replace("\n", "");
                Event::Html(
                    format!(
                        "<img eeimg=\"1\" src=\"//www.zhihu.com/equation?tex={}\" alt=\"{}\"/>",
                        eq, eq
                    )
                    .into(),
                )
            }
            Event::DisplayMath(text) => {
                let eq = text.to_string().replace("\n", "");
                Event::Html(
                    format!(
                        "<img eeimg=\"1\" src=\"//www.zhihu.com/equation?tex={}\\\\\" alt=\"{}\\\\\"/>",
                        eq, eq
                    )
                    .into(),
                )
            }
            Event::Start(Tag::CodeBlock(kind)) => {
                in_code_block = true;
                let lang = match kind {
                    CodeBlockKind::Indented => "".to_string(),
                    CodeBlockKind::Fenced(info) => info.trim().to_string(),
                };
                Event::Html(CowStr::from(format!(
                    "<pre lang=\"{}\"><code>",
                    lang
                )))
            }
            Event::End(TagEnd::CodeBlock) => {
                in_code_block = false;
                Event::Html(CowStr::from("</code></pre>"))
            }
            // TODO: better solution
            // HACK: Single line HTML output is expected by zhihu, so we replace soft breaks with spaces (which always only affects for English characters, since the common converting tools (e.g. pandoc) does not wrap lines with non-English worlds.
            Event::SoftBreak => {
                if in_code_block {
                    Event::Text("\n".into())
                } else {
                    Event::Text(" ".into())
                }
            }
            // HACK: In zhihu, the HTML output is expected to be a single line without newlines, if not, it
            // would be rendered as a newline instead of a whitespace.
            // html_output.replace("\n", "")
            Event::Text(text) => {
                if in_code_block {
                    Event::Text(text)
                } else {
                // Replace newlines with spaces to avoid unwanted line breaks in HTML output
                let replaced_text = text.replace('\n', " ");
                    Event::Html(replaced_text.into())
                }
            }
            _ => event,
        }
    });

    let mut html_output = String::new();
    html::push_html(&mut html_output, parser);
    // TODO: introduce a better solution e.g. using a HTML parser to avoid unwanted line breaks in
    // HTML output
    // HACK: Replace the newline after paragraph tags with a space to avoid unwanted line breaks in HTML output
    html_output
        .replace("</p>\n", "</p>") // HACK: Replace newline after closing paragraph tag with nothing to avoid unwanted line breaks in HTML output
        .replace("\n</code>", "</code>") // HACK: Replace newline before closing code tag with nothing to avoid unwanted line breaks in HTML output
}

#[mlua::lua_module]
fn markdown_to_html_lib(lua: &Lua) -> Result<mlua::Table> {
    let exports = lua.create_table()?;
    let options = Options::ENABLE_STRIKETHROUGH
        | Options::ENABLE_TABLES
        | Options::ENABLE_TASKLISTS
        | Options::ENABLE_FOOTNOTES
        | Options::ENABLE_MATH;
    exports.set(
        "md_to_html",
        lua.create_function(move |_, markdown: String| Ok(markdown_to_html(&markdown, options)))?,
    )?;
    Ok(exports)
}
