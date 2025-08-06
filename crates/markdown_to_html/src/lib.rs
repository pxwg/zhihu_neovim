use html5ever::driver::ParseOpts;
use html5ever::parse_document;
use html5ever::tendril::TendrilSink;
use markup5ever_rcdom::{Handle, NodeData, RcDom};
use mlua::{Lua, Result};
use pulldown_cmark::{html, CodeBlockKind, CowStr, Event, Options, Parser, Tag, TagEnd};
use std::io::Cursor;
use std::rc::Rc;

fn markdown_to_html(input: &str, options: Options) -> String {
  let parser = Parser::new_ext(input, options);

  let mut in_code_block = false;
  let mut current_image_url: Option<String> = None;
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
            Event::Start(Tag::Image { link_type: _, dest_url, title: _, .. }) => {
                // Store the image URL for when we encounter the alt text
                current_image_url = Some(dest_url.to_string());
                Event::Text("".into()) // Return empty text to consume this event
            }
            Event::Text(text) if current_image_url.is_some() => {
                // This is the alt text for the image
                let dest_url = current_image_url.take().unwrap();
                let caption = text.to_string();
                Event::Html(
                    format!(
                        "<img src=\"{}\" data-caption=\"{}\" data-size=\"normal\" data-watermark=\"watermark\" data-original-src=\"{}\" data-watermark-src=\"\" data-private-watermark-src=\"\" />",
                        dest_url, caption, dest_url
                    )
                    .into(),
                )
            }
            // Inline code blocks
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

  clean_html_structure(&html_output)

  // // HACK: Replace the newline after paragraph tags with a space to avoid unwanted line breaks in HTML output
  // html_output
  //     .replace("</p>\n", "</p>") // HACK: Replace newline after closing paragraph tag with nothing to avoid unwanted line breaks in HTML output
  //     .replace("\n</code>", "</code>") // HACK: Replace newline before closing code tag with nothing to avoid unwanted line breaks in HTML output
}

fn clean_html_structure(html: &str) -> String {
  use html5ever::serialize::{serialize, SerializeOpts};
  use markup5ever_rcdom::SerializableHandle;

  let parse_opts = ParseOpts::default();
  let dom = parse_document(RcDom::default(), parse_opts)
    .from_utf8()
    .read_from(&mut Cursor::new(html))
    .unwrap();

  // satisfying zhihu-flavored HTML spec
  clean_node(&dom.document);

  let mut bytes = vec![];
  serialize(
    &mut bytes,
    &SerializableHandle::from(dom.document.clone()),
    SerializeOpts::default(),
  )
  .unwrap();

  String::from_utf8(bytes).unwrap()
}

/// Zhihu has its own spec for HTML rendering, which requires some specific cleaning of the HTML structure.
/// The known issues include: `<\p>\n` and `<\pre>\n` would be rendered as `\n\n` instead of `\n`.
/// Using html5ever to parse the HTML and clean it up according to the spec. Which might be more
/// safer than using regex to replace the HTML structure.
fn clean_node(node: &Handle) {
  match &node.data {
    NodeData::Text { contents } => {
      if let Some(parent) = node.parent.take() {
        if let NodeData::Element { name, .. } = &parent.upgrade().unwrap().data {
          // remove: `<\p>\n` -> `<\p>`; `<\pre>\n` -> `<\pre>`; `\n<\code>` -> `<\code>`
          // to satisfy zhihu-flavored HTML spec
          if name.local.as_ref() == "p"
            || name.local.as_ref() == "pre"
            || name.local.as_ref() == "code"
          {
            let mut contents_mut = contents.borrow_mut();
            if contents_mut.starts_with('\n') {
              *contents_mut = contents_mut.trim_start_matches('\n').into();
            }
            if name.local.as_ref() == "code" && contents_mut.ends_with('\n') {
              *contents_mut = contents_mut.trim_end_matches('\n').into();
            }
          }
        }
      }
    }
    NodeData::Element { name, .. } => {
      if name.local.as_ref() == "pre" || name.local.as_ref() == "p" || name.local.as_ref() == "code"
      {
        if let Some(parent) = node.parent.take() {
          let parent = parent.upgrade().unwrap();
          let children = parent.children.borrow();
          let mut found = false;

          for sibling in children.iter() {
            if found {
              if let NodeData::Text { contents } = &sibling.data {
                let mut contents_mut = contents.borrow_mut();
                if contents_mut.starts_with('\n') {
                  *contents_mut = contents_mut.trim_start_matches('\n').into();
                }
              }
              break;
            }

            if Rc::ptr_eq(sibling, node) {
              found = true;
            }
          }
        }
      }
    }
    _ => {}
  }

  // Recursively clean child nodes
  for child in node.children.borrow().iter() {
    clean_node(child);
  }
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
